package TR::Web;
use strict;
use warnings;
use Path::Tiny;
use Wanage::URL;
use Encode;
use Promise;
use JSON::Functions::XS qw(json_bytes2perl perl2json_bytes);
use Wanage::HTTP;
use Web::URL::Canonicalize;
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
    delete $SIG{CHLD} if defined $SIG{CHLD} and not ref $SIG{CHLD};

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
    return $class->session ($app)->then (sub {
      my $account = $_[0];
      return ((defined $account->{account_id} ? $app->db->select ('repo_access', {
        account_id => Dongry::Type->serialize ('text', $account->{account_id}),
      }, fields => ['repo_url', 'data'])->then (sub {
        return $_[0]->all_as_rows;
      }) : Promise->resolve ([]))->then (sub {
        return $app->temma ('tr.html.tm', {
          app => $app,
          repo_access_rows => $_[0],
        });
      }));
    });
  }

  if ($path->[0] eq 'tr' and $path->[2] eq '' and @$path == 3) {
    # /tr/{url}/
    my $tr = $class->create_text_repo ($app, $path->[1], undef, undef);

    return $class->check_read ($app, $tr, access_token => 1, html => 1)->then (sub {
      return $tr->prepare_mirror ($_[0], $app);
    })->then (sub {
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

  if ($path->[0] eq 'tr' and @$path == 3 and $path->[2] eq 'acl') {
    # /tr/{url}/acl
    my $tr = $class->create_text_repo ($app, $path->[1], undef, undef);

    if ($app->http->request_method eq 'POST') {
      # XXX CSRF
      return $class->session ($app)->then (sub {
        my $account = $_[0];
        return $app->throw_error (403) if not defined $account->{account_id};

        my $op = $app->bare_param ('operation') // '';
        if ($op eq 'update_account_privilege') {
          my $account_id = $app->bare_param ('account_id')
              // return $app->throw_error (400, reason_phrase => 'Bad |account_id|');
          return $app->db->select ('repo_access', {
            repo_url => Dongry::Type->serialize ('text', $tr->url),
            account_id => Dongry::Type->serialize ('text', $account->{account_id}),
          }, fields => ['data'], limit => 1)->then (sub {
            my $row = $_[0]->first_as_row;
            return $app->throw_error (403, reason_phrase => 'Bad privilege')
                if not defined $row or not $row->get ('data')->{repo};
            my $permissions = {read => 1};
            for my $scope (@{$app->text_param_list ('scope')}) {
              if ({
                edit => 1, comment => 1, texts => 1, repo => 1,
              }->{$scope}) {
                $permissions->{$scope} = 1;
              } elsif ($scope =~ m{\Aedit/[0-9a-z-]+\z}) {
                $permissions->{$scope} = 1;
              }
            }
            return $app->db->insert ('repo_access', [{
              repo_url => Dongry::Type->serialize ('text', $tr->url),
              account_id => Dongry::Type->serialize ('text', $account_id),
              is_owner => 0,
              data => Dongry::Type->serialize ('json', $permissions),
              created => time,
              updated => time,
            }], duplicate => {
              data => $app->db->bare_sql_fragment ('VALUES(data)'),
              updated => $app->db->bare_sql_fragment ('VALUES(updated)'),
            });
          })->then (sub {
            return $app->send_error (204, reason_phrase => 'Saved');
          });
        } elsif ($op eq 'delete_account_privilege') {
          my $account_id = $app->bare_param ('account_id')
              // return $app->throw_error (400, reason_phrase => 'Bad |account_id|');
          return $app->db->select ('repo_access', {
            repo_url => Dongry::Type->serialize ('text', $tr->url),
            account_id => Dongry::Type->serialize ('text', $account->{account_id}),
          }, fields => ['data'], limit => 1)->then (sub {
            my $row = $_[0]->first_as_row;
            return $app->throw_error (403, reason_phrase => 'Bad privilege')
                if not defined $row or not $row->get ('data')->{repo};
          })->then (sub {
            return $app->db->delete ('repo_access', {
              repo_url => Dongry::Type->serialize ('text', $tr->url),
              account_id => Dongry::Type->serialize ('text', $account_id),
            });
          })->then (sub {
            return $app->send_error (204, reason_phrase => 'Deleted');
          });
        } elsif ($op eq 'get_ownership') {
          return do {
            my $repo_type = $tr->repo_type;
            if ($repo_type eq 'github') {
              $app->account_server (q</token>, {
                sk => $app->http->request_cookies->{sk},
                sk_context => $app->config->{account_sk_context},
                server => 'github',
              })->then (sub {
                my $json = $_[0];
                my $token = $json->{access_token};
                return Promise->new (sub {
                  my ($ok, $ng) = @_;
                  $tr->url =~ m{^https://github.com/([^/]+/[^/]+)} or die;
                  http_get
                      url => qq<https://api.github.com/repos/$1>,
                      header_fields => (defined $token ? {Authorization => 'token ' . $token} : undef),
                      timeout => 100,
                      anyevent => 1,
                      cb => sub {
                        my (undef, $res) = @_;
                        if ($res->code == 200) {
                          $ok->(json_bytes2perl $res->content);
                        } else {
                          $ng->([$res->code, $res->status_line]);
                        }
                      };
                });
              })->then (sub {
                my $json = $_[0];
                return {is_owner => !!$json->{permissions}->{push},
                        is_public => not $json->{private}};
              });
            } elsif ($repo_type eq 'ssh') {
              $app->account_server (q</token>, {
                sk => $app->http->request_cookies->{sk},
                sk_context => $app->config->{account_sk_context},
                server => 'ssh',
              })->then (sub {
                my $json = $_[0];
                my $token = $json->{access_token};
                die [403, "Bad SSH key"] unless defined $token and ref $token eq 'ARRAY';

                return $tr->prepare_mirror ({access_token => $token,
                                             requires_token_for_pull => 1},
                                            $app);
              })->then (sub {
                return {is_owner => 1, is_public => 0};
              });
            } elsif ($repo_type eq 'file') {
              Promise->resolve ({is_owner => 1, is_public => 1});
            } else { # $repo_type
              Promise->reject ("Can't get ownership of a repository with type |$repo_type|");
            }
          }->then (sub {
            my $rights = $_[0];
            my $time = time;
            return $app->db->insert ('repo_access', [{
              repo_url => Dongry::Type->serialize ('text', $tr->url),
              account_id => Dongry::Type->serialize ('text', $account->{account_id}),
              is_owner => $rights->{is_owner},
              data => ($rights->{is_owner} ? '{"read":1,"edit":1,"texts":1,"comment":1,"repo":1}' : '{"read":1}'),
              created => $time,
              updated => $time,
            }], duplicate => {
              is_owner => $app->db->bare_sql_fragment ('VALUES(is_owner)'),
              updated => $app->db->bare_sql_fragment ('VALUES(updated)'),
            })->then (sub {
              return $app->db->execute ('UPDATE `repo_access` SET is_owner = 0 AND updated = ? WHERE repo_url = ? AND account_id != ?', {
                repo_url => Dongry::Type->serialize ('text', $tr->url),
                account_id => Dongry::Type->serialize ('text', $account->{account_id}),
                updated => $time,
              }) if $rights->{is_owner};
            })->then (sub {
              return $app->db->insert ('repo', [{
                repo_url => Dongry::Type->serialize ('text', $tr->url),
                is_public => $rights->{is_public},
                created => time,
                updated => time,
              }], duplicate => {
                is_public => $app->db->bare_sql_fragment ('VALUES(is_public)'),
                updated => $app->db->bare_sql_fragment ('VALUES(updated)'),
              }); # XXXupdate-index
            })->then (sub {
              return $app->send_json ($rights);
            });
          }, sub {
            # XXX better error reporting
            die $_[0] unless ref $_[0] eq 'ARRAY';
            my ($status, $status_line) = @{$_[0]};
            if ($status == 404) {
              return $app->send_error (403, reason_phrase => "Can't access to the remote repository");
            } else {
              die $status_line;
            }
          });
        } else {
          return $app->send_error (400, reason_phrase => 'Bad |operation|');
        }
      })->catch (sub {
        unless (UNIVERSAL::isa ($_[0], 'Warabe::App::Done')) {
          $app->error_log ($_[0]);
          return $app->send_error (500);
        }
      })->then (sub {
        return $tr->discard;
      });
    } else { # GET
      return $class->session ($app)->then (sub {
        my $account = $_[0];
        return $app->throw_error (403) if not defined $account->{account_id}; # XXX custom 403
        return $app->db->select ('repo_access', {
          repo_url => Dongry::Type->serialize ('text', $tr->url),
          account_id => Dongry::Type->serialize ('text', $account->{account_id}),
        }, fields => ['data'], limit => 1);
      })->then (sub {
        my $row = $_[0]->first_as_row;
        return $app->throw_error (403, reason_phrase => 'Bad privilege')
            if not defined $row or not $row->get ('data')->{repo}; # XXX custom 403
        return $app->temma ('tr.acl.html.tm', {
          app => $app,
          tr => $tr,
        });
      });
    }
  } elsif ($path->[0] eq 'tr' and @$path == 3 and $path->[2] eq 'acl.json') {
    # /tr/{url}/acl.json
    my $tr = $class->create_text_repo ($app, $path->[1], undef, undef);

    return $class->session ($app)->then (sub {
      my $account = $_[0];
      return $app->throw_error (403) if not defined $account->{account_id}; # XXX custom 403
      return $app->db->select ('repo_access', {
        repo_url => Dongry::Type->serialize ('text', $tr->url),
        account_id => Dongry::Type->serialize ('text', $account->{account_id}),
      }, fields => ['data'], limit => 1);
    })->then (sub {
      my $row = $_[0]->first_as_row;
      return $app->throw_error (403, reason_phrase => 'Bad privilege')
          if not defined $row or not $row->get ('data')->{repo}; # XXX custom 403

      my $json = {};
      return $app->db->select ('repo_access', {
        repo_url => Dongry::Type->serialize ('text', $tr->url),
      }, fields => ['account_id', 'is_owner', 'data'])->then (sub {
        my $accounts = $json->{accounts} = {map { $_->get ('account_id') => {
          account_id => ''.$_->get ('account_id'),
          scopes => $_->get ('data'),
          is_owner => $_->get ('is_owner'),
        } } @{$_[0]->all_as_rows}};

        return Promise->all ([
          $app->account_server (q</profiles>, {
            account_id => [keys %$accounts],
          }),
          $app->db->select ('repo', {
            repo_url => Dongry::Type->serialize ('text', $tr->url),
          }, fields => ['is_public']),
        ]);
      })->then (sub {
        my $j = $_[0]->[0];
        for my $account_id (keys %{$j->{accounts}}) {
          $json->{accounts}->{$account_id}->{name} = $j->{accounts}->{$account_id}->{name};
          # XXX icon
        }
        my $repo_data = $_[0]->[1]->first;
        if (defined $repo_data) {
          $json->{is_public} = 1 if $repo_data->{is_public};
        } else {
          $json->{is_public} = 1;
        }
        return $app->send_json ($json);
      });
    });
  }

  if ($path->[0] eq 'tr' and $path->[3] eq '' and @$path == 4) {
    # /tr/{url}/{branch}/
    my $tr = $class->create_text_repo ($app, $path->[1], $path->[2], undef);

    return $class->check_read ($app, $tr, access_token => 1, html => 1)->then (sub {
      return $tr->prepare_mirror ($_[0], $app);
    })->then (sub {
      return $tr->get_commit_logs ([$tr->branch]);
    })->then (sub {
      my $parsed = $_[0]; # XXX if branch not found
      my $tree = $parsed->{commits}->[0]->{tree};
      return $tr->get_ls_tree ($tree, recursive => 1);
    })->then (sub {
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
    })->catch (sub {
      $app->error_log ($_[0]);
      return $app->send_error (500);
    })->then (sub {
      return $tr->discard;
    });
  } # /tr/{url}/{branch}

  if ($path->[0] eq 'tr' and @$path >= 4) {
    # /tr/{url}/{branch}/{path}
    my $tr = $class->create_text_repo
        ($app, $path->[1], $path->[2], $path->[3]);

    if (@$path == 5 and $path->[4] eq '') {
      # .../
      return $class->check_read ($app, $tr, html => 1)->then (sub {
        require TR::Query;
        my $q = TR::Query->parse_query (
          query => $app->text_param ('q'),
          text_ids => $app->text_param_list ('text_id'),
          msgids => $app->text_param_list ('msgid'),
          tag_ors => $app->text_param_list ('tag_or'),
          tags => $app->text_param_list ('tag'),
          tag_minuses => $app->text_param_list ('tag_minus'),
        );
        return $app->temma ('tr.texts.html.tm', {
          app => $app,
          tr => $tr,
          query => $q,
        });
      });

    } elsif (@$path == 5 and $path->[4] =~ /\Adata\.(json|ndjson)\z/) {
      # .../data.json
      # .../data.ndjson

      $app->start_json_stream if $1 eq 'ndjson';
      $app->send_progress_json_chunk ('Checking the repository permission...');
      my $q;
      my $scopes;
      return $class->check_read (
        $app, $tr,
        access_token => 1, scopes => 1,
      )->then (sub {
        $scopes = $_[0]->{scopes};
        return $tr->prepare_mirror ($_[0], $app);
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
        $app->send_progress_json_chunk ('Reading the text set...');
        return $tr->get_data_as_jsonalizable
            ($q,
             $app->text_param_list ('lang')->grep (sub { length }),
             with_comments => $app->bare_param ('with_comments'));
      })->then (sub {
        my $json = $_[0];
        $app->send_progress_json_chunk ('Formatting the text set...');
        $json->{scopes} = $scopes;
        $json->{query} = $q->as_jsonalizable;
        $app->send_last_json_chunk (200, 'OK', $json);
      })->catch (sub {
        $app->error_log ($_[0]);
        return $app->send_error (500); # XXX
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 5 and $path->[4] eq 'XXXupdate-index') {
      # .../XXXupdate-index
      # XXX request method
      my $tr_config;
      return $class->check_read ($app, $tr, access_token => 1)->then (sub {
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        return $tr->get_tr_config;
      })->then (sub {
        $tr_config = $_[0];
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
      return $class->check_read ($app, $tr, access_token => 1)->then (sub {
        return $tr->prepare_mirror ($_[0], $app);
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
      return $class->check_read ($app, $tr, html => 1)->then (sub {
        # XXX $app->text_param_list ('lang');
        # XXX $app->text_param_list ('tag')
        return $app->temma ('tr.texts.import.html.tm', {
          app => $app,
          tr => $tr,
          # XXX scopes
        });
      });
    } elsif (@$path == 5 and $path->[4] =~ /\Aimport\.(json|ndjson)\z/) {
      # .../import.json
      # .../import.ndjson

      $app->start_json_stream if $1 eq 'ndjson';
      $app->send_progress_json_chunk ('Checking the repository permission...');
      return $class->get_push_token ($app, $tr, 'repo')->then (sub { # XXX scope
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        $app->send_progress_json_chunk ('Clonging the repository...');
        return $tr->clone_from_mirror (push => 1);
      })->then (sub {
        my $from = $app->bare_param ('from') // '';
        if ($from eq 'file') {
          my $lang = $app->text_param ('lang') // return $app->send_error (400); # XXX lang validation # XXX auto
          my $format = $app->text_param ('format') // '';
          $app->send_progress_json_chunk ('Importing the file...');
          return $tr->import_file (
            [map {
              my $v = $_;
              +{get => sub { path ($v->as_f)->slurp }, # XXX
                lang => $lang,
                format => $format};
            } @{$app->http->request_uploads->{file} || []}],
            arg_format => $app->text_param ('arg_format') // '',
            tags => $app->text_param_list ('tag')->grep (sub { length }),
          );
        } elsif ($from eq 'repo') {
          $app->send_progress_json_chunk ('Importing...');
          return $tr->import_auto (
            format => $app->text_param ('format') // '',
            arg_format => $app->text_param ('arg_format') // '',
            tags => $app->text_param_list ('tag')->grep (sub { length }),
          );
        } else {
          return $app->throw_error (400, reason_phrase => 'Bad |from|');
        }
      })->then (sub {
        my $msg = $app->text_param ('commit_message') // '';
        $msg = 'Added a message' unless length $msg; # XXX
        return $tr->commit ($msg);
      })->then (sub {
        $app->send_progress_json_chunk ('Pushing the repository...');
        return $tr->push; # XXX failure
      })->then (sub {
        return $app->send_last_json_chunk (200, 'Done', {});
      }, sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path >= 7 and $path->[4] eq 'i') {
      if (@$path == 7 and $path->[6] =~ /\Atext\.(json|ndjson)\z/) {
        # .../i/{text_id}/text.json
        # .../i/{text_id}/text.ndjson
        my $type = $1;
        $app->requires_request_method ({POST => 1});
        # XXX CSRF

        my $id = $path->[5]; # XXX validation
        my $lang = $app->text_param ('lang') or $app->throw_error (400); # XXX lang validation

        $app->start_json_stream if $type eq 'ndjson';
        $app->send_progress_json_chunk ('Checking the repository permission...', [1,5]);
        return $class->get_push_token ($app, $tr, 'edit/' . $lang)->then (sub {
          return $tr->prepare_mirror ($_[0], $app);
        })->then (sub {
          $app->send_progress_json_chunk ('Cloning the repository...', [2,5]);
          return $tr->clone_from_mirror (push => 1, no_checkout => 1);
        })->then (sub {
          $app->send_progress_json_chunk ('Applying the change...', [3,5]);
          my $path = $tr->text_id_and_suffix_to_relative_path ($id, $lang . '.txt');
          return $tr->mirror_repo->show_blob_by_path ($tr->branch, $path);
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
          $msg = 'Added a message' unless length $msg; # XXX
          return $tr->commit ($msg);
        })->then (sub {
          $app->send_progress_json_chunk ('Pushing the repository...',[4,5]);
          return $tr->push; # XXX failure
        })->then (sub {
          return $app->send_last_json_chunk (200, 'Saved', {});
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

        my $id = $path->[5]; # XXX validation

        my $te;
        return $class->get_push_token ($app, $tr, 'texts')->then (sub {
          return $tr->prepare_mirror ($_[0], $app);
        })->then (sub {
          return $tr->clone_from_mirror (push => 1);
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
          $msg = 'Added a message' unless length $msg; # XXX
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

        my $id = $path->[5]; # XXX validation

        return $class->get_push_token ($app, $tr, 'comment')->then (sub {
          return $tr->prepare_mirror ($_[0], $app);
        })->then (sub {
          return $tr->clone_from_mirror (push => 1);
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
          $msg = 'Added a comment' unless length $msg; # XXX
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

        my $id = $path->[5]; # XXX validation

        my $lang = $app->text_param ('lang') or return $app->send_error (400); # XXX validation
        return $class->check_read ($app, $tr, access_token => 1)->then (sub {
          return $tr->prepare_mirror ($_[0], $app);
        })->then (sub {
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

      my $data = {texts => {}};
      return $class->get_push_token ($app, $tr, 'texts')->then (sub {
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        return $tr->clone_from_mirror (push => 1);
      })->then (sub {
        my $id = $tr->generate_text_id;
        my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, '');
        my $msgid = $app->text_param ('msgid');
        if (defined $msgid and length $msgid) {
          # XXX check duplication
          $te->set (msgid => $msgid);
        }
        my $desc = $app->text_param ('desc');
        $te->set (desc => $desc) if defined $desc and length $desc;
        for (@{$app->text_param_list ('tag')}) {
          $te->enum ('tags')->{$_} = 1;
        }
        $data->{texts}->{$id} = $te->as_jsonalizable;
        return $tr->write_file_by_text_id_and_suffix ($id, 'dat' => $te->as_source_text);
      })->then (sub {
        my $msg = $app->text_param ('commit_message') // '';
        $msg = 'Added a message' unless length $msg; # XXX
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
      if ($app->http->request_method eq 'POST') {
        # XXX CSRF

        my $lang_keys = $app->text_param_list ('lang_key');
        my $lang_ids = $app->text_param_list ('lang_id');
        my $lang_labels = $app->text_param_list ('lang_label');
        my $lang_label_shorts = $app->text_param_list ('lang_label_short');

        return $class->get_push_token ($app, $tr, 'repo')->then (sub {
          return $tr->prepare_mirror ($_[0], $app);
        })->then (sub {
          return $tr->clone_from_mirror (push => 1);
        })->then (sub {
          return $tr->read_file_by_path ($tr->texts_path->child ('config.json'));
        })->then (sub {
          my $tr_config = TR::TextEntry->new_from_text_id_and_source_text (undef, $_[0] // '');

          my %found;
          my @lang_key;
          for (0..$#$lang_keys) {
            my $lang_key = $lang_keys->[$_];
            next if $found{$lang_key}++;
            push @lang_key, $lang_key;
            $tr_config->set_or_delete ("lang.id.$lang_key" => $lang_ids->[$_]);
            $tr_config->set_or_delete ("lang.label.$lang_key" => $lang_labels->[$_]);
            $tr_config->set_or_delete ("lang.label_short.$lang_key" => $lang_label_shorts->[$_]);
          }
          $tr_config->set (langs => join ',', @lang_key);

          return $tr->write_file_by_path ($tr->texts_path->child ('config.json'), $tr_config->as_source_text);
        })->then (sub {
          my $msg = $app->text_param ('commit_message') // '';
          $msg = 'Added a message' unless length $msg; # XXX
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
      } else { # GET
        return $class->check_read ($app, $tr, html => 1)->then (sub {
          return $app->temma ('tr.texts.langs.html.tm', {
            app => $app,
            tr => $tr,
            # XXX scopes
          });
        });
      }
    } elsif (@$path == 5 and $path->[4] eq 'langs.json') {
      # .../langs.json
      return $class->check_read ($app, $tr, access_token => 1)->then (sub {
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        return $tr->get_tr_config;
      })->then (sub {
        my $tr_config = $_[0];
        my $lang_keys = [grep { length } split /,/, $tr_config->get ('langs') // ''];
        $lang_keys = ['en'] unless @$lang_keys;
        my $langs = {map {
          my $id = $tr_config->get ("lang.id.$_") // $_;
          my $label_raw = $tr_config->get ("lang.label.$_");
          my $label = $label_raw // $_; # XXX system's default
          my $label_short_raw = $tr_config->get ("lang.label_short.$_");
          my $label_short = $label_short_raw // $label; # XXX system's default
          $_ => +{
            key => $_,
            id => $id,
            label_raw => $label_raw,
            label => $label,
            label_short_raw => $label_short_raw,
            label_short => $label_short,
          };
        } @$lang_keys};
        return $app->send_json ({
          langs => $langs,
          avail_lang_keys => $lang_keys,
        });
      })->catch (sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 5 and $path->[4] eq 'LICENSE') {
      # .../LICENSE
      # XXX access token
      return $app->send_plain_text ('XXX');

    } elsif (@$path == 5 and $path->[4] eq 'license') {
      # .../license
      return $class->check_read ($app, $tr, html => 1)->then (sub {
        return $app->temma ('tr.texts.license.html.tm', {
          app => $app,
          tr => $tr,
          # XXX scopes
        });
      });
    } elsif (@$path == 5 and $path->[4] =~ /\Alicense\.(json|ndjson)\z/) {
      # .../license.json
      # .../license.ndjson
      my $type = $1;
      $app->requires_request_method ({POST => 1});
      # XXX CSRF
      $app->start_json_stream if $type eq 'ndjson';
      return $class->get_push_token ($app, $tr, 'repo')->then (sub {
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        return $tr->clone_from_mirror (push => 1);
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
        $msg = 'Added a message' unless length $msg; # XXX
        return $tr->commit ($msg);
      })->then (sub {
        return $tr->push; # XXX failure
      })->then (sub {
        return $app->send_last_json_chunk (200, 'Saved', {});
      }, sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 5 and ($path->[4] eq 'comments' or $path->[4] eq 'comments.json')) {
      # .../comments # XXX HTML view
      # .../comments.json
      return $class->check_read ($app, $tr, access_token => 1)->then (sub {
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        return $tr->get_recent_comments (limit => 50);
      })->then (sub {
        return $app->send_json ($_[0]);
      })->catch (sub {
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
    unless ($server eq 'github' or $server eq 'hatena') {
      return $app->send_error (400, reason_phrase => 'Bad |server|');
    }
    my $server_scope = {github => 'repo'}->{$server};

    return $app->account_server (q</session>, {
      sk => $app->http->request_cookies->{sk},
      sk_context => $app->config->{account_sk_context},
    })->then (sub {
      my $json = $_[0];
      $app->http->set_response_cookie
          (sk => $json->{sk},
           expires => $json->{sk_expires},
           httponly => 1,
           secure => 0, # XXX
           domain => undef, # XXX
           path => q</>) if $json->{set_sk};
      return $app->account_server (q</login>, {
        sk => $json->{sk},
        sk_context => $app->config->{account_sk_context},
        server => $server,
        server_scope => $server_scope,
        callback_url => $app->http->url->resolve_string ('/account/cb')->stringify,
      });
    })->then (sub {
      my $json = $_[0];
      return $app->send_redirect ($json->{authorization_url});
    });
  } elsif (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'cb') {
    # /account/cb
    return $app->account_server (q</cb>, {
      sk => $app->http->request_cookies->{sk},
      sk_context => $app->config->{account_sk_context},
      oauth_token => $app->http->query_params->{oauth_token},
      oauth_verifier => $app->http->query_params->{oauth_verifier},
      code => $app->http->query_params->{code},
      state => $app->http->query_params->{state},
    })->then (sub {
      return $app->send_redirect ('/');
    });
  } elsif (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'info.json') {
    # /account/info.json
    return $class->session ($app)->then (sub {
      my $account = $_[0];
      return $app->send_json ({name => $account->{name}, # or undef
                               account_id => ''.$account->{account_id}}); # or undef
      # XXX icon
    });
    # XXX report remote API error
  } elsif (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'sshkey.json') {
    # /account/sshkey.json
    if ($app->http->request_method eq 'POST') {
      # XXX CSRF
      my $comment = $app->config->get ('ssh_key.comment');
      $comment =~ s/\{time\}/time/ge;
      return $app->account_server (q</keygen>, {
        sk => $app->http->request_cookies->{sk},
        sk_context => $app->config->{account_sk_context},
        server => 'ssh',
        comment => $comment,
      })->then (sub {
        return $app->send_json ({});
      });
      # XXX error handling
    } else { # GET
      return $app->account_server (q</token>, {
        sk => $app->http->request_cookies->{sk},
        sk_context => $app->config->{account_sk_context},
        server => 'ssh',
      })->then (sub {
        my $json = $_[0];
        if (defined $json->{access_token} and
            ref $json->{access_token} eq 'ARRAY') {
          return $app->send_json ({public_key => $json->{access_token}->[0]});
        } else {
          return $app->send_json ({});
        }
      });
    }
  } # /account

  if (@$path == 2 and
      $path->[0] eq 'users' and
      $path->[1] eq 'search.json') {
    # /users/search.json
    $app->requires_request_method ({POST => 1});
    # XXX requires session?

    return $app->account_server (q</search>, {
      q => $app->text_param ('q'),
    })->then (sub {
      my $json = $_[0];
      return $app->send_json ($json);
    });
  } # /users/search.json


  if (@$path == 3 and
      $path->[0] eq 'remote' and
      $path->[1] eq 'github' and
      $path->[2] eq 'repos.json') {
    # /remote/github/repos.json

    # XXX requires POST
    # XXX Cache-Control

    return $class->session ($app)->then (sub {
      my $account = $_[0];
      return [] unless defined $account->{account_id};
      require TR::MongoLab; # XXX replace by MySQL
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
        return $app->account_server (q</token>, {
          sk => $app->http->request_cookies->{sk},
          sk_context => $app->config->{account_sk_context},
          server => 'github',
        })->then (sub {
          my $json = $_[0];
          my $token = $json->{access_token} // return [];
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

sub create_text_repo ($$$) {
  my ($class, $app, $url, $branch, $path) = @_;

  my $tr = TR::TextRepo->new_from_mirror_and_temp_path
      ($app->mirror_path, Path::Tiny->tempdir);
  $tr->config ($app->config);

  return $app->throw_error (404, reason_phrase => 'Bad repository URL')
      if $url =~ /[?#]/;
  $url =~ s{^([^/:\@]+\@[^/:]+):}{ssh://$1/};
  $url =~ s{^/}{file:///};
  $url = (url_to_canon_url $url, 'about:blank') // '';
  $url =~ s{\.git/?\z}{};
  if ($url =~ m{^file:}) {
    $url =~ s{/+\z}{};
  }

  # XXX max URL length
  # XXX
  if ($url =~ m{\A(?:https?://|git://|ssh://git\@)github\.com/([^/]+/[^/]+)\z}) {
    $url = qq{https://github.com/$1};
    $tr->repo_type ('github');
  } elsif ($url =~ m{\Assh://git\@melon/(/git/pub/.+)\z}) {
    $url = qq{git\@melon:$1};
    $tr->repo_type ('ssh');
  } elsif ($url =~ m{\Afile://\Q@{[path (__FILE__)->parent->parent->parent->child ('local/pub')]}\E/}) {
    $tr->repo_type ('file');
  } else {
    return $app->throw_error (404, reason_phrase => "Bad repository URL");
  }

  $tr->url ($url);

  if (defined $branch) {
    return $app->throw_error (404, reason_phrase => 'Bad repository branch')
        unless length $branch;
    $tr->branch ($branch);
  }

  if (defined $path) {
    if (($path eq '/' or $path =~ m{\A(?:/[0-9A-Za-z_.-]+)+\z}) and
        not "$path/" =~ m{/\.\.?/}) {
      #
    } else {
      return $app->throw_error (404, reason_phrase => 'Bad text set path');
    }
    $tr->texts_dir (substr $path, 1);
  }

  return $tr;
} # create_text_repo

sub session ($$) {
  my ($class, $app) = @_;
  return $app->account_server (q</info>, {
    sk => $app->http->request_cookies->{sk},
    sk_context => $app->config->{account_sk_context},
  });
} # session

sub check_read ($$$;%) {
  my ($class, $app, $tr, %args) = @_;
  my $scopes;
  my $is_public;
  my $account = {};
  return $app->db->select ('repo', {
    repo_url => Dongry::Type->serialize ('text', $tr->url),
  }, fields => ['is_public'])->then (sub {
    my $repo = $_[0]->first;
    if (defined $repo) {
      if ($repo->{is_public}) {
        $is_public = 1;
        if ($args{scopes}) {
          return $class->session ($app)->then (sub {
            my $acc = $_[0];
            if (defined $acc->{account_id}) {
              return $app->db->select ('repo_access', {
                account_id => Dongry::Type->serialize ('text', $acc->{account_id}),
                repo_url => Dongry::Type->serialize ('text', $tr->url),
              }, fields => ['data'])->then (sub {
                my $row = $_[0]->first_as_row;
                if (defined $row) {
                  $scopes = $row->get ('data');
                  return $scopes->{read};
                } else {
                  $scopes = {read => 1};
                  return 1;
                }
              });
            } else {
              $scopes = {read => 1};
              return 1;
            }
          });
        } else {
          return 1;
        }
      } else { # private repo
        return $class->session ($app)->then (sub {
          my $acc = $_[0];
          return 0 if not defined $acc->{account_id};
          return $app->db->select ('repo_access', {
            account_id => Dongry::Type->serialize ('text', $acc->{account_id}),
            repo_url => Dongry::Type->serialize ('text', $tr->url),
          }, fields => ['data'])->then (sub {
            my $row = $_[0]->first_as_row;
            $account->{requires_token_for_pull} = 1;
            $scopes = $row->get ('data') if defined $row;
            return (defined $scopes and $scopes->{read});
          });
        });
      }
    } else { # no |repo| row
      return 0 unless $tr->url =~ m{^(?:https?|git):};
      return $tr->prepare_mirror ({}, $app)->then (sub {
        $scopes = {read => 1};
        $is_public = 1;
        return 1;
      }, sub {
        # XXX if error, ...
        return 0;
      });
    }
  })->then (sub {
    if ($_[0]) { # can be read
      if ($args{access_token}) {
        if ($is_public) {
          $account->{scopes} = $scopes if $args{scopes};
          return $account;
        }
        return $app->db->select ('repo_access', {
          repo_url => Dongry::Type->serialize ('text', $tr->url),
          is_owner => 1,
        }, fields => ['account_id'], limit => 1)->then (sub {
          my $owner = $_[0]->first;
          return $app->throw_error (403, reason_phrase => 'The repository has no owner') unless defined $owner;
          my $server;
          my $repo_type = $tr->repo_type;
          if ($repo_type eq 'github') {
            $server = 'github';
          } elsif ($repo_type eq 'ssh') {
            $server = 'ssh';
          } elsif ($repo_type eq 'file') {
            return {access_token => ''};
          } else {
            die "Can't pull repository of type |$repo_type|";
          }
          return $app->account_server (q</token>, {
            account_id => $owner->{account_id},
            server => $server,
          });
        })->then (sub {
          my $json = $_[0];
          my $token = $json->{access_token};
          return $app->throw_error (403, reason_phrase => 'The repository owner has no access token')
              unless defined $token;
          $account->{scopes} = $scopes if $args{scopes};
          $account->{access_token} = $token;
          return $account;
        });
      } else {
        return;
      }
    } else { # cannot be read
      return $app->throw_error (404, reason_phrase => 'Repository not found or not accessible') unless $args{html};
      $app->http->set_status (404, reason_phrase => 'Repository not found or not accessible');
      return $app->temma ('tr.repo_not_found.html.tm', {
        app => $app,
        tr => $tr,
      })->then (sub { return $app->throw });
    }
  });
} # check_read

sub get_push_token ($$$$) {
  my ($class, $app, $tr, $scope) = @_;
  my $account_id;
  my $name;
  return $class->session ($app)->then (sub {
    my $session = $_[0];
    $name = $session->{name};
    return $app->throw_error (403, reason_phrase => 'Need to login')
        unless defined ($account_id = $session->{account_id});
  })->then (sub {
    return $app->db->select ('repo_access', {
      repo_url => Dongry::Type->serialize ('text', $tr->url),
      account_id => Dongry::Type->serialize ('text', $account_id),
    }, fields => ['data'], limit => 1);
  })->then (sub {
    my $row = $_[0]->first_as_row;
    my $ok = 0;
    if (defined $row) {
      my $scopes = $row->get ('data');
      if ($scopes->{$scope}) {
        $ok = 1;
      } elsif ($scope =~ m{^edit/} and $scopes->{edit}) {
        $ok = 1;
      }
    }
    return $app->throw_error (403, reason_phrase => "Permission for the |$scope| scope is required by this operation")
        unless $ok;
  })->then (sub {
    return $app->db->select ('repo_access', {
      repo_url => Dongry::Type->serialize ('text', $tr->url),
      is_owner => 1,
    }, fields => ['account_id'], limit => 1);
  })->then (sub {
    my $owner = $_[0]->first;
    return $app->throw_error (403, reason_phrase => 'The repository has no owner') unless defined $owner;
    my $server;
    my $repo_type = $tr->repo_type;
    if ($repo_type eq 'github') {
      $server = 'github';
    } elsif ($repo_type eq 'ssh') {
      $server = 'ssh';
    } elsif ($repo_type eq 'file') {
      return {access_token => ''};
    } else {
      die "Can't pull repository of type |$repo_type|";
    }
    return $app->account_server (q</token>, {
      account_id => $owner->{account_id},
      server => $server,
    });
  })->then (sub {
    my $json = $_[0];
    my $token = {access_token => $json->{access_token},
                 name => $name, account_id => $account_id};
    return $app->throw_error (403, reason_phrase => 'The repository owner has no GitHub access token')
        unless defined $token->{access_token};

    return $app->db->select ('repo', {
      repo_url => Dongry::Type->serialize ('text', $tr->url),
    }, fields => ['is_public'])->then (sub {
      my $repo = $_[0]->first;
      if (defined $repo) {
        $token->{requires_token_for_pull} = 1 unless $repo->{is_public};
      }
    })->then (sub { return $token });
    # XXX name/email for git author
  });
} # get_push_token

1;

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
