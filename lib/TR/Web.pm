package TR::Web;
use strict;
use warnings;
use Path::Tiny;
use Wanage::URL;
use Encode;
use Promise;
use JSON::PS;
use Wanage::HTTP;
use Web::UserAgent::Functions qw(http_get http_post);
use TR::AppServer;
use TR::TextRepo;
use TR::TextEntry;

sub psgi_app ($$) {
  my ($class, $config) = @_;
  return sub {
    ## This is necessary so that different forked siblings have
    ## different seeds.
    srand;

    ## XXX Parallel::Prefork (?)
    delete $SIG{CHLD};
    delete $SIG{CLD};

    my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
    my $app = TR::AppServer->new_from_http_and_config ($http, $config);

    # XXX accesslog
    warn sprintf "Access: [%s] %s %s\n",
        scalar gmtime, $app->http->request_method, $app->http->url->stringify;

    return $app->execute_by_promise (sub {
      #XXX
      #my $origin = $app->http->url->ascii_origin;
      #if ($origin eq $app->config->{web_origin}) {
      # XXX HSTS

      return Promise->resolve ($class->main ($app))->then (sub {
        return $app->shutdown;
      }, sub {
        my $error = $_[0];
        return $app->shutdown->then (sub { die $error });
      });

      #} else {
      #  return $app->send_error (400, reason_phrase => 'Bad |Host:|');
      #}
    });
  };
} # psgi_app

sub main ($$) {
  my ($class, $app) = @_;
  my $path = $app->path_segments;

  if (@$path == 1 and $path->[0] eq '') {
    # /
    return $app->temma ('index.html.tm');
  }

  if (@$path == 1 and $path->[0] eq 'tr') {
    # /tr
    return $app->temma ('tr.html.tm', {
      app => $app,
    });
  }

  if ($path->[0] eq 'tr' and $path->[2] eq '' and @$path == 3) {
    # /tr/{url}/

    my $tr = TR::TextRepo->new_from_mirror_and_temp_path ($app->mirror_path, Path::Tiny->tempdir);
    $tr->url ($path->[1]); # XXX validation & normalization

    return $tr->prepare_mirror->then (sub {
      return $tr->get_branches;
    })->then (sub {
      my $parsed1 = $_[0];
      return $tr->get_commit_logs ([map { $_->{commit} } values %{$parsed1->{branches}}])->then (sub {
        my $parsed2 = $_[0];
        my $sha_to_commit = {};
        $sha_to_commit->{$_->{commit}} = $_ for @{$parsed2->{commits}};
        for (values %{$parsed1->{branches}}) {
          $_->{commit_log} = $sha_to_commit->{$_->{commit}};
        }
        return $app->temma ('tr.repo.html.tm', {
          app => $app,
          tr => $tr,
          branches => $parsed1->{branches},
        });
      });
    })->catch (sub {
      $app->error_log ($_[0]);
      return $app->send_error (500);
    })->then (sub {
      return $tr->discard;
    });
  }

  if ($path->[0] eq 'tr' and $path->[3] eq '' and @$path == 4) {
    # /tr/{url}/{branch}/

    my $tr = TR::TextRepo->new_from_mirror_and_temp_path ($app->mirror_path, Path::Tiny->tempdir);
    $tr->url ($path->[1]); # XXX validation & normalization
    $tr->branch ($path->[2]); # XXX validation

    return $tr->prepare_mirror->then (sub {
      return $tr->get_commit_logs ([$tr->branch]);
    })->then (sub {
      my $parsed = $_[0]; # XXX if branch not found
      my $tree = $parsed->{commits}->[0]->{tree};
      return $tr->get_ls_tree ($tree, recursive => 1)->then (sub {
        my $parsed = $_[0];

        my $text_sets = {};
        for (values %{$parsed->{items}}) {
          next unless $_->{file} =~ m{/texts/config.json\z};
          next unless $_->{type} eq 'blob';
          # XXX next if symlink
          my $path = '/' . $_->{file};
          $path =~ s{/texts/config.json\z}{};
          $text_sets->{$path}->{path} = $path;
          $text_sets->{$path}->{texts_path} = (substr $path, 1) . '/texts';
          # XXX text set label, desc, ...
        }

        my $has_root = (($parsed->{items}->{'texts/config.json'} || {})->{type} // '') eq 'blob'; # XXX and is not symlink
        if ($has_root or not keys %$text_sets) {
          $text_sets->{'/'}->{path} = '/';
          $text_sets->{'/'}->{texts_path} = 'texts';
        }

        return $tr->get_last_commit_logs_by_paths ([map { $_->{texts_path} } values %$text_sets])->then (sub {
          my $parsed = $_[0];
          for (values %$text_sets) {
            $_->{commit_log} = $parsed->{$_->{texts_path}};
          }
          return $app->temma ('tr.branch.html.tm', {
            app => $app,
            tr => $tr,
            text_sets => $text_sets,
          });
        });
      });
    })->catch (sub {
      $app->error_log ($_[0]);
      return $app->send_error (500);
    })->then (sub {
      return $tr->discard;
    });
  }

  if ($path->[0] eq 'tr' and @$path >= 4) {
    # /tr/{url}/{branch}/{path}
    if (($path->[3] eq '/' or $path->[3] =~ m{\A(?:/[0-9A-Za-z_.-]+)+\z}) and
        not "$path->[3]/" =~ m{/\.\.?/}) {
      #
    } else {
      return $app->send_error (404);
    }

    my $tr = TR::TextRepo->new_from_mirror_and_temp_path ($app->mirror_path, Path::Tiny->tempdir);
    $tr->url ($path->[1]); # XXX validation & normalization
    $tr->branch ($path->[2]); # XXX validation
    $tr->texts_dir (substr $path->[3], 1);

    if (@$path == 5 and $path->[4] eq '') {
      # .../
      return $tr->prepare_mirror->then (sub {
        return $tr->clone_from_mirror;
      })->then (sub { # XXX branch
        return $tr->read_file_by_path ($tr->texts_path->child ('config.json'));
      })->then (sub {
        my $tr_config = TR::TextEntry->new_from_text_id_and_source_text (undef, $_[0] // '');
        my $langs = [grep { length } split /,/, $tr_config->get ('langs') // ''];
        $langs = ['en'] unless @$langs;
        my $all_langs = $langs;
        my $specified_langs = $app->text_param_list ('lang');
        if (@$specified_langs) {
          my $avail_langs = {map { $_ => 1 } @$langs};
          @$specified_langs = grep { $avail_langs->{$_} } @$specified_langs;
          $langs = $specified_langs;
        }
        $tr->langs ($langs);
        $tr->avail_langs ($all_langs);

        require TR::Query;
        my $q = TR::Query->parse_query (
          query => $app->text_param ('q'),
          text_ids => $app->text_param_list ('text_id'),
          msgids => $app->text_param_list ('msgid'),
          tag_ors => $app->text_param_list ('tag_or'),
          tags => $app->text_param_list ('tag'),
          tag_minuses => $app->text_param_list ('tag_minus'),
        );

        my @param;
        for my $k (qw(lang)) {
          my $list = $app->text_param_list ($k);
          for (@$list) {
            push @param, (percent_encode_c $k) . '=' . (percent_encode_c $_);
          }
        }

        return $app->temma ('tr.texts.html.tm', {
          app => $app,
          tr => $tr,
          tr_config => $tr_config,
          query => $q,
          data_params => (join '&', @param),
        });
      })->catch (sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 5 and $path->[4] eq 'data.json') {
      # .../data.json
      my $q;
      return $tr->prepare_mirror->then (sub {
        return $tr->clone_from_mirror;
      })->then (sub {
        require TR::Query;
        $q = TR::Query->parse_query (
          query => $app->text_param ('q'),
          text_ids => $app->text_param_list ('text_id'),
          msgids => $app->text_param_list ('msgid'),
          tag_ors => $app->text_param_list ('tag_or'),
          tags => $app->text_param_list ('tag'),
          tag_minuses => $app->text_param_list ('tag_minus'),
        );
        return $tr->get_data_as_jsonalizable
            ($q,
             $app->text_param_list ('lang')->grep (sub { length }),
             with_comments => $app->bare_param ('with_comments'));
      })->then (sub {
        my $json = $_[0];
        $json->{permission} = { # XXX
          read => 1,
          write => 1,
        };
        $json->{query} = $q->as_jsonalizable;
        return $app->send_json ($json);
      })->catch (sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 5 and $path->[4] eq 'XXXupdate-index') {
      # .../XXXupdate-index
      # XXX request method
      # XXX branch
      my $tr_config;
      return $tr->prepare_mirror->then (sub {
        return $tr->clone_from_mirror;
      })->then (sub {
        return $tr->read_file_by_path ($tr->texts_path->child ('config.json'));
      })->then (sub {
        $tr_config = TR::TextEntry->new_from_text_id_and_source_text (undef, $_[0] // '');

        require TR::Query;
        return $tr->get_data_as_jsonalizable (TR::Query->parse_query, []);
      })->then (sub {
        my $json = $_[0];
        $json->{repo_url} = $tr->url;
        $json->{repo_path} = '/' . ($tr->texts_dir // '');
        $json->{repo_license} = $tr_config->get ('license');
        require TR::Search;
        my $s = TR::Search->new_from_config ($app->config);
        return $s->put_data ($json)->then (sub {
          return $app->send_error (200);
        });
      })->catch (sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 5 and $path->[4] eq 'export') {
      # .../export
      return $tr->prepare_mirror->then (sub {
        return $tr->clone_from_mirror;
      })->then (sub {
        my $format = $app->text_param ('format') // '';
        my $arg_format = $app->text_param ('arg_format') // '';
        if ($format eq 'po') { # XXX and pot
          my $lang = $app->text_param ('lang') or return $app->send_error (400); # XXX lang validation
          $arg_format ||= 'printf'; #$arg_format normalization
          $arg_format = 'printf' if $arg_format eq 'auto';
          require TR::Query;
          my $q = TR::Query->parse_query (
            query => $app->text_param ('q'),
            text_ids => $app->text_param_list ('text_id'),
            msgids => $app->text_param_list ('msgid'),
            tag_ors => $app->text_param_list ('tag_or'),
            tags => $app->text_param_list ('tag'),
            tag_minuses => $app->text_param_list ('tag_minus'),
          );
          return $tr->get_data_as_jsonalizable
              ($q, [$lang])->then (sub {
            my $json = $_[0];
            require Popopo::Entry;
            require Popopo::EntrySet;
            my $es = Popopo::EntrySet->new;
            my $header = $es->get_or_create_header;
            # XXX $header
            for my $text_id (keys %{$json->{texts} or {}}) {
              my $text = $json->{texts}->{$text_id};
              my $msgid = $text->{msgid};
              next unless defined $msgid; # XXX fallback option?
              my $str = $text->{langs}->{$lang}->{body_0} // '';
              my $args = {};
              my $i = 0;
              for my $arg_name (@{$text->{args} or []}) {
                $i++;
                $args->{$arg_name} = {index => $i, name => $arg_name};
              }
              # XXX $app->text_param ('preserve_html')
              # XXX $app->text_param ('no_fallback')
              my @str;
              for (split /(\{[^{}]+\})/, $str, -1) {
                if (/\A\{([^{}]+)\}\z/) {
                  my $arg = $args->{$1};
                  if ($arg) {
                    if ($arg_format eq 'braced') {
                      push @str, '{' . $arg->{name} . '}';
                    } elsif ($arg_format eq 'printf') {
                      push @str, '%'.$arg->{index}.'$s'; # XXX
                    } elsif ($arg_format eq 'percentn') {
                      push @str, '%' . $arg->{index};
                    }
                  } else {
                    push @str, $_;
                  }
                } else {
                  if ($arg_format eq 'printf' or $arg_format eq 'percentn') {
                    s/%/%%/g;
                  }
                  push @str, $_;
                }
              }
              $str = join '', @str;
              my $e = Popopo::Entry->new
                  (msgid => $msgid,
                   msgstrs => [$str]);
              # XXX more props
              $es->add_entry ($e);
            }
            $app->http->set_response_header ('Content-Type' => 'text/x-po; charset=utf-8');
            $app->http->set_response_disposition (filename => "$lang.po");
            $app->http->send_response_body_as_text ($es->stringify);
            $app->http->close_response_body;
          });
        } else {
          return $app->send_error (400, reason_phrase => 'Unknown format');
        }
      })->catch (sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });
    } elsif (@$path == 5 and $path->[4] eq 'import') {
      # .../import

      # XXX
      my $auth = $app->http->request_auth;
      unless (defined $auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
        $app->http->set_response_auth ('basic', realm => $path->[1]);
        return $app->send_error (401);
      }

      return $tr->prepare_mirror->then (sub {
        return $tr->clone_from_mirror;
      })->then (sub {
        return $tr->make_pushable ($auth->{userid}, $auth->{password});
      })->then (sub {
        my $format = $app->text_param ('format') // '';
        my $arg_format = $app->text_param ('arg_format') // '';
        my $files = $app->http->request_uploads->{file} || [];
        my $tags = $app->text_param_list ('tag')->grep (sub { length });
        my @q;
        for my $file (@$files) {
          # XXX format=auto
          if ($format eq 'po') { # XXX and pot
            my $lang = $app->text_param ('lang') or return $app->send_error (400); # XXX lang validation # XXX auto
            $arg_format ||= 'printf'; #$arg_format normalization
            $arg_format = 'printf' if $arg_format eq 'auto'; # XXX
            
            require Popopo::Parser;
            my $parser = Popopo::Parser->new;
            # XXX onerror
            my $es = $parser->parse_string (path ($file->as_f)->slurp_utf8); # XXX blocking XXX charset
            # XXX lang and ohter metadata from header

            my $msgid_to_e = {};
            for my $e (@{$es->entries}) {
              $msgid_to_e->{$e->msgid} = $e; # XXX warn duplicates
            }

            push @q, $tr->text_ids->then (sub {
              my @id = keys %{$_[0]};
              my @p;
              for my $id (@id) {
                push @p, $tr->read_file_by_text_id_and_suffix ($id, 'dat')->then (sub {
                  my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
                  my $mid = $te->get ('msgid');
                  return unless defined $mid and my $e = delete $msgid_to_e->{$mid};
                  $te->enum ('tags')->{$_} = 1 for @$tags;

                  push @p, $tr->read_file_by_text_id_and_suffix ($id, $lang . '.txt')->then (sub {
                    my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
                    $te->set (body_0 => $e->msgstr);
                    $te->set (last_modified => time);
                    # XXX and other fields
                    # XXX args
                    return $tr->write_file_by_text_id_and_suffix ($id, $lang . '.txt' => $te->as_source_text);
                  });

                  return $tr->write_file_by_text_id_and_suffix ($id, 'dat' => $te->as_source_text);
                });
              } # $id
            })->then (sub {
              my @p;
              for my $msgid (keys %$msgid_to_e) {
                my $e = $msgid_to_e->{$msgid};
                my $id = $tr->generate_text_id;
                {
                  my $te = TR::TextEntry->new_from_text_id_and_source_text
                      ($id, '');
                  $te->set (msgid => $msgid);
                  $te->enum ('tags')->{$_} = 1 for @$tags;
                  # XXX comment, ...
                  push @p, $tr->write_file_by_text_id_and_suffix
                      ($id, 'dat' => $te->as_source_text);
                }
                {
                  my $te = TR::TextEntry->new_from_text_id_and_source_text
                      ($id, '');
                  $te->set (body_0 => $e->msgstr);
                  $te->set (last_modified => time);
                  # XXX and other fields
                  # XXX args
                  push @p, $tr->write_file_by_text_id_and_suffix
                      ($id, $lang.'.txt' => $te->as_source_text);
                }
              }
              return Promise->all (\@p);
            });
          } else {
            # XXX
            return $app->send_error (400, reason_phrase => 'Unknown format');
          }
        } # $file
        return Promise->all (\@q);
      })->then (sub {
        my $msg = $app->text_param ('commit_message') // '';
        $msg = 'Added a message' unless length $msg;
        return $tr->commit ($msg);
      })->then (sub {
        return $tr->push; # XXX failure
      })->then (sub {
        return $app->send_error (200); # XXX return JSON?
      }, sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path >= 7 and $path->[4] eq 'i') {
      if (@$path == 7 and $path->[6] eq '') { # XXX URL
        # .../i/{text_id}/
        $app->requires_request_method ({POST => 1});
        # XXX CSRF

        # XXX access control

        my $id = $path->[5]; # XXX validation

        # XXX
        my $auth = $app->http->request_auth;
        unless (defined $auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
          $app->http->set_response_auth ('basic', realm => $path->[1]);
          return $app->send_error (401);
        }
        my $lang = $app->text_param ('lang') or $app->throw_error (400); # XXX lang validation
        return $tr->prepare_mirror->then (sub {
          return $tr->clone_from_mirror;
        })->then (sub {
          return $tr->make_pushable ($auth->{userid}, $auth->{password});
        })->then (sub {
          return $tr->read_file_by_text_id_and_suffix ($id, $lang . '.txt');
        })->then (sub {
          my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
          for (qw(body_0 body_1 body_2 body_3 body_4 forms)) {
            my $v = $app->text_param ($_);
            $te->set ($_ => $v) if defined $v;
          }
          $te->set (last_modified => time);
          return $tr->write_file_by_text_id_and_suffix ($id, $lang . '.txt' => $te->as_source_text);
        })->then (sub {
          my $msg = $app->text_param ('commit_message') // '';
          $msg = 'Added a message' unless length $msg;
          return $tr->commit ($msg);
        })->then (sub {
          return $tr->push; # XXX failure
        })->then (sub {
          return $app->send_error (200); # XXX return JSON?
        }, sub {
          $app->error_log ($_[0]);
          return $app->send_error (500);
        })->then (sub {
          return $tr->discard;
        });

      } elsif (@$path == 7 and $path->[6] eq 'meta') {
        # .../i/{text_id}/meta
        $app->requires_request_method ({POST => 1});
        # XXX CSRF

        # XXX access control

        my $id = $path->[5]; # XXX validation

        # XXX
        my $auth = $app->http->request_auth;
        unless (defined $auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
          $app->http->set_response_auth ('basic', realm => $path->[1]);
          return $app->send_error (401);
        }
        my $te;
        return $tr->prepare_mirror->then (sub {
          return $tr->clone_from_mirror;
        })->then (sub {
          return $tr->make_pushable ($auth->{userid}, $auth->{password});
        })->then (sub {
          return $tr->read_file_by_text_id_and_suffix ($id, 'dat');
        })->then (sub {
          $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');

          $te->set (msgid => $app->text_param ('msgid'));
          $te->set (desc => $app->text_param ('desc'));

          my $enum = $te->enum ('tags');
          %$enum = ();
          $enum->{$_} = 1 for grep { length } @{$app->text_param_list ('tag')};

          my $args = $te->list ('args');
          $te->set ('args.desc.' . $_ => undef) for @$args;
          @$args = ();
          my $names = $app->text_param_list ('arg_name');
          my $descs = $app->text_param_list ('arg_desc');
          my %found;
          for (0..$#$names) {
            next if $found{$names->[$_]}++;
            next unless length $names->[$_];
            push @$args, $names->[$_];
            $te->set ('args.desc.'.$names->[$_] => $descs->[$_]);
          }

          return $tr->write_file_by_text_id_and_suffix ($id, 'dat' => $te->as_source_text);
        })->then (sub {
          my $msg = $app->text_param ('commit_message') // '';
          $msg = 'Added a message' unless length $msg;
          return $tr->commit ($msg);
        })->then (sub {
          return $tr->push; # XXX failure
        })->then (sub {
          return $app->send_json ($te->as_jsonalizable);
        }, sub {
          $app->error_log ($_[0]);
          return $app->send_error (500);
        })->then (sub {
          return $tr->discard;
        });

      } elsif (@$path == 7 and $path->[6] eq 'comments') {
        # .../i/{text_id}/comments
        $app->requires_request_method ({POST => 1});
        # XXX CSRF

        # XXX access control

        my $id = $path->[5]; # XXX validation

        # XXX
        my $auth = $app->http->request_auth;
        unless (defined $auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
          $app->http->set_response_auth ('basic', realm => $path->[1]);
          return $app->send_error (401);
        }
        return $tr->prepare_mirror->then (sub {
          return $tr->clone_from_mirror;
        })->then (sub {
          return $tr->make_pushable ($auth->{userid}, $auth->{password});
        })->then (sub {
          my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, '');
          $te->set (id => $tr->generate_section_id);
          $te->set (body => $app->text_param ('body') // ''); # XXX validation
          # XXX author
          $te->set (last_modified => time);
          return $tr->append_section_to_file_by_text_id_and_suffix
              ($id, 'comments' => $te->as_source_text);
        })->then (sub {
          my $msg = $app->text_param ('commit_message') // '';
          $msg = 'Added a comment' unless length $msg;
          return $tr->commit ($msg);
        })->then (sub {
          return $tr->push; # XXX failure
        })->then (sub {
          return $app->send_error (200); # XXX return JSON?
        }, sub {
          $app->error_log ($_[0]);
          return $app->send_error (500);
        })->then (sub {
          return $tr->discard;
        });

      } elsif (@$path == 7 and $path->[6] eq 'history.json') {
        # .../i/{text_id}/history.json

        # XXX access control

        my $id = $path->[5]; # XXX validation

        my $lang = $app->text_param ('lang') or return $app->send_error (400); # XXX validation
        return $tr->prepare_mirror->then (sub {
          return $tr->git_log_for_text_id_and_lang
              ($id, $lang, with_file_text => 1);
        })->then (sub {
          my $parsed = $_[0];
          my @json;
          for (@{$parsed->{commits}}) {
            my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, decode 'utf-8', $_->{blob_data});
            push @json, {lang_text => $te->as_jsonalizable,
                         commit => {commit => $_->{commit},
                                    author => $_->{author},
                                    committer => $_->{committer}}};
          }
          return {history => \@json};
        })->then (sub {
          return $app->send_json ($_[0]);
        }, sub {
          $app->error_log ($_[0]);
          return $app->send_error (500);
        })->then (sub {
          return $tr->discard;
        });
      }

    } elsif (@$path == 5 and $path->[4] eq 'add') {
      # .../add

      $app->requires_request_method ({POST => 1});
      # XXX CSRF

      # XXX access control

      # XXX
      my $auth = $app->http->request_auth;
      unless (defined $auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
        $app->http->set_response_auth ('basic', realm => $path->[1]);
        return $app->send_error (401);
      }

      my $data = {texts => {}};
      return $tr->prepare_mirror->then (sub {
        return $tr->clone_from_mirror;
      })->then (sub {
        return $tr->make_pushable ($auth->{userid}, $auth->{password});
      })->then (sub {
        my $id = $tr->generate_text_id;
        my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, '');
        my $msgid = $app->text_param ('msgid');
        if (defined $msgid and length $msgid) {
          # XXX check duplication
          $te->set (msgid => $msgid);
        }
        for (@{$app->text_param_list ('tag')}) {
          $te->enum ('tags')->{$_} = 1;
        }
        $data->{texts}->{$id} = $te->as_jsonalizable;
        return $tr->write_file_by_text_id_and_suffix ($id, 'dat' => $te->as_source_text);
      })->then (sub {
        my $msg = $app->text_param ('commit_message') // '';
        $msg = 'Added a message' unless length $msg;
        return $tr->commit ($msg);
      })->then (sub {
        return $tr->push; # XXX failure
      })->then (sub {
        return $app->send_json ($data);
      }, sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 5 and $path->[4] eq 'langs') {
      # .../langs

      $app->requires_request_method ({POST => 1});
      # XXX CSRF

      # XXX access control

      # XXX
      my $auth = $app->http->request_auth;
      unless (defined $auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
        $app->http->set_response_auth ('basic', realm => $path->[1]);
        return $app->send_error (401);
      }

      my %found; # XXX lang validation & normalization
      my $langs = [grep { length and not $found{$_}++ } @{$app->text_param_list ('lang')}];
      unless (@$langs) {
        return $app->send_error (400, reason_phrase => 'Bad |lang|');
      }

      return $tr->prepare_mirror->then (sub {
        return $tr->clone_from_mirror;
      })->then (sub {
        return $tr->make_pushable ($auth->{userid}, $auth->{password});
      })->then (sub {
        return $tr->read_file_by_path ($tr->texts_path->child ('config.json'));
      })->then (sub {
        my $tr_config = TR::TextEntry->new_from_text_id_and_source_text (undef, $_[0] // '');
        $tr_config->set (langs => join ',', @$langs);
        return $tr->write_file_by_path ($tr->texts_path->child ('config.json'), $tr_config->as_source_text);
      })->then (sub {
        my $msg = $app->text_param ('commit_message') // '';
        $msg = 'Added a message' unless length $msg;
        return $tr->commit ($msg);
      })->then (sub {
        return $tr->push; # XXX failure
      })->then (sub {
        return $app->send_json ({});
      }, sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 5 and $path->[4] eq 'acl') {
      # .../acl
      $app->requires_request_method ({POST => 1});
      # XXX CSRF
      return $class->session ($app)->then (sub {
        my $account = $_[0];
        return $app->throw_error (403) if not defined $account->{account_id};

        require TR::MongoLab;
        my $mongo = TR::MongoLab->new_from_api_key ($app->config->{mongolab_api_key});

        my $key = percent_encode_c $tr->url;
        $key =~ s/\./%2E/g;

        return $mongo->update_doc_by_query ('repo', 'acl', $key, {'$set' => {
          owner_account_id => $account->{account_id},
        }}, {
hoge => 1,
          owner_account_id => {'$exists' => 0},
        })->then (sub {
          return $mongo->get_docs_by_query ('repo', 'acl', {
            _id => $key,
          })->then (sub {
            my $doc = $_[0]->[0];
            if (defined $doc->{owner_account_id} and
                $doc->{owner_account_id} == $account->{account_id}) {
              return $app->send_json ({});
            } else {
              return $app->send_error (403);
            }
          });
        });
      })->catch (sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 5 and $path->[4] eq 'LICENSE') {
      # .../LICENSE
      return $app->send_plain_text ('XXX');

    } elsif (@$path == 5 and $path->[4] eq 'license') {
      # .../license

      $app->requires_request_method ({POST => 1});
      # XXX CSRF

      # XXX access control

      # XXX
      my $auth = $app->http->request_auth;
      unless (defined $auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
        $app->http->set_response_auth ('basic', realm => $path->[1]);
        return $app->send_error (401);
      }

      return $tr->prepare_mirror->then (sub {
        return $tr->clone_from_mirror;
      })->then (sub {
        return $tr->make_pushable ($auth->{userid}, $auth->{password});
      })->then (sub {
        return $tr->read_file_by_path ($tr->texts_path->child ('config.json'));
      })->then (sub {
        my $tr_config = TR::TextEntry->new_from_text_id_and_source_text (undef, $_[0] // '');
        my $license = {license => $app->text_param ('license'),
                       license_holders => $app->text_param ('license_holders'),
                       additional_license_terms => $app->text_param ('additional_license_terms')};
        $tr_config->set (license => $license->{license});
        $tr_config->set (license_holders => $license->{license_holders});
        $tr_config->set (additional_license_terms => $license->{additional_license_terms});
        return $tr->write_file_by_path ($tr->texts_path->child ('config.json'), $tr_config->as_source_text)->then (sub {
          return $tr->write_license_file (%$license);
        });
      })->then (sub {
        my $msg = $app->text_param ('commit_message') // '';
        $msg = 'Added a message' unless length $msg;
        return $tr->commit ($msg);
      })->then (sub {
        return $tr->push; # XXX failure
      })->then (sub {
        return $app->send_json ({});
      }, sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });
    }
  }

  if (@$path == 1 and $path->[0] eq 'search.json') {
    # /search.json
    require TR::Search;
    my $s = TR::Search->new_from_config ($app->config);
    return $s->search ($app->text_param ('q') // '')->then (sub {
      return $app->send_json ($_[0]);
      # XXX paging
    });
  }

  # XXX Cache-Control
  if (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'login') {
    # /account/login
    $app->requires_request_method ({POST => 1});
    $app->requires_same_origin_or_referer_origin;

    my $server = $app->bare_param ('server') // '';
    unless ($server eq 'github') {
      return $app->send_error (400, reason_phrase => 'Bad |server|');
    }

    my $prefix = $app->config->{account_url_prefix};
    my $api_token = $app->config->{account_token};
    return Promise->new (sub {
      my ($ok, $ng) = @_;
      http_post
          url => qq<$prefix/session>,
          header_fields => {Authorization => 'Bearer ' . $api_token},
          params => {
            sk => $app->http->request_cookies->{sk},
            sk_context => $app->config->{account_sk_context},
          },
          anyevent => 1,
          cb => sub {
            my (undef, $res) = @_;
            if ($res->code == 200) {
              $ok->(json_bytes2perl $res->content);
            } else {
              $ng->($res->status_line);
            }
          };
    })->then (sub {
      my $json = $_[0];
      $app->http->set_response_cookie
          (sk => $json->{sk},
           expires => $json->{sk_expires},
           httponly => 1,
           secure => 0, # XXX
           domain => undef, # XXX
           path => q</>) if $json->{set_sk};
      return Promise->new (sub {
        my ($ok, $ng) = @_;
        http_post
            url => qq<$prefix/login>,
            header_fields => {Authorization => 'Bearer ' . $api_token},
            params => {
              sk => $json->{sk},
              sk_context => $app->config->{account_sk_context},
              server => $server,
              callback_url => $app->http->url->resolve_string ('/account/cb')->stringify,
            },
            anyevent => 1,
            cb => sub {
              my (undef, $res) = @_;
              if ($res->code == 200) {
                $ok->(json_bytes2perl $res->content);
              } else {
                $ng->($res->status_line);
              }
            };
      });
    })->then (sub {
      my $json = $_[0];
      return $app->send_redirect ($json->{authorization_url});
    });
  } elsif (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'cb') {
    # /account/cb
    my $prefix = $app->config->{account_url_prefix};
    my $api_token = $app->config->{account_token};
    return Promise->new (sub {
      my ($ok, $ng) = @_;
      http_post
          url => qq<$prefix/cb>,
          header_fields => {Authorization => 'Bearer ' . $api_token},
          params => {
            sk => $app->http->request_cookies->{sk},
            sk_context => $app->config->{account_sk_context},
            oauth_token => $app->http->query_params->{oauth_token},
            oauth_verifier => $app->http->query_params->{oauth_verifier},
            code => $app->http->query_params->{code},
            state => $app->http->query_params->{state},
          },
          anyevent => 1,
          cb => sub {
            my (undef, $res) = @_;
            if ($res->code == 200) {
              $ok->(json_bytes2perl $res->content);
            } else {
              $ng->($res->status_line);
            }
          };
    })->then (sub {
      return $app->send_redirect ('/');
    });
  } elsif (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'info.json') {
    # /account/info.json
    return $class->session ($app)->then (sub {
      my $account = $_[0];
      return $app->send_json ({name => $account->{name}, # or undef
                               account_id => $account->{account_id}}); # or undef
      # XXX icon
    });
    # XXX report remote API error
  } # /account

  if (@$path == 3 and
      $path->[0] eq 'remote' and
      $path->[1] eq 'github' and
      $path->[2] eq 'repos.json') {
    # /remote/github/repos.json

    # XXX Cache-Control

    return $class->session ($app)->then (sub {
      my $account = $_[0];
      return [] unless defined $account->{account_id};
      require TR::MongoLab;
      my $mongo = TR::MongoLab->new_from_api_key ($app->config->{mongolab_api_key});
      return (((not $app->bare_param ('update')) ? do {
        $mongo->get_docs_by_query ('user', 'github-repos', {_id => $account->{account_id}})->then (sub {
          my $data = $_[0];
          return $data->[0]->{repos} if defined $data->[0]->{repos};
          return undef;
        });
      } : Promise->resolve (undef))->then (sub {
        my $json = $_[0];
        return $json if defined $json;

        return Promise->new (sub {
          my ($ok, $ng) = @_;
          my $prefix = $app->config->{account_url_prefix};
          my $api_token = $app->config->{account_token};
          http_post
              url => qq<$prefix/token>,
              header_fields => {Authorization => 'Bearer ' . $api_token},
              params => {
                sk => $app->http->request_cookies->{sk},
                sk_context => $app->config->{account_sk_context},
                server => 'github',
              },
              anyevent => 1,
              cb => sub {
                my (undef, $res) = @_;
                if ($res->code == 200) {
                  $ok->(json_bytes2perl $res->content);
                } else {
                  $ng->($res->status_line);
                }
              };
        })->then (sub {
          my $json = $_[0];
          my $token = $json->{access_token} // return {};
          return Promise->new (sub {
            my ($ok, $ng) = @_;
            # XXX paging support
            http_get
                url => q<https://api.github.com/user/repos?per_page=100>,
                header_fields => {Authorization => 'token ' . $token,
                                  Accept => 'application/vnd.github.moondragon+json'},
                timeout => 100,
                anyevent => 1,
                cb => sub {
                  my (undef, $res) = @_;
                  if ($res->code == 200) {
                    $ok->(json_bytes2perl $res->content);
                  } else {
                    $ng->($res->status_line);
                  }
                };
          });
        })->then (sub {
          my $json = $_[0];
          $json = {map { do { my $v = (percent_encode_c $_->{url}); $v =~ s/\./%2E/g; $v } => $_ } map { +{
            label => $_->{full_name},
            url => qq{https://github.com/$_->{full_name}},
            default_branch => $_->{default_branch},
            private => !!$_->{private},
            read => !!$_->{permissions}->{pull},
            write => !!$_->{permissions}->{push},
            updated => $_->{updated_at}, # XXX conversion
            desc => $_->{description},
          } } @$json};
          return $mongo->set_doc ('user', 'github-repos', {
            _id => $account->{account_id},
            repos => $json,
          })->then (sub { return $json });
        });
      }));
    })->then (sub {
      my $json = $_[0];
      return $app->send_json ({repos => $json});
    });
  } # /remote/github/repos.json

  if (@$path == 2 and
      {js => 1, css => 1, data => 1, images => 1, fonts => 1}->{$path->[0]} and
      $path->[1] =~ /\A[0-9A-Za-z_-]+\.(js|css|jpe?g|gif|png|json|ttf|otf|woff)\z/) {
    # /js/* /css/* /images/* /data/*
    return $app->send_file ("$path->[0]/$path->[1]", {
      js => 'text/javascript; charset=utf-8',
      css => 'text/css; charset=utf-8',
      jpeg => 'image/jpeg',
      jpg => 'image/jpeg',
      gif => 'image/gif',
      png => 'image/png',
      json => 'application/json',
    }->{$1});
  }

  return $app->send_error (404);
} # main

sub session ($$) {
  my ($class, $app) = @_;
  my $prefix = $app->config->{account_url_prefix};
  my $api_token = $app->config->{account_token};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => qq<$prefix/info>,
        header_fields => {Authorization => 'Bearer ' . $api_token},
        params => {
          sk => $app->http->request_cookies->{sk},
          sk_context => $app->config->{account_sk_context},
        },
        anyevent => 1,
        cb => sub {
          my (undef, $res) = @_;
          if ($res->code == 200) {
            $ok->(json_bytes2perl $res->content);
          } else {
            $ng->($res->status_line);
          }
        };
  });
} # session

1;

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
