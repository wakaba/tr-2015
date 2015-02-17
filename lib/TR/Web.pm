package TR::Web;
use strict;
use warnings;
use Path::Tiny;
use Wanage::URL;
use Promise;
use Wanage::HTTP;
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
        return $class->main ($app);
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

        my @param;
        for my $k (qw(text_id msgid tag lang)) {
          my $list = $app->text_param_list ($k);
          for (@$list) {
            push @param, (percent_encode_c $k) . '=' . (percent_encode_c $_);
          }
        }
        return $app->temma ('tr.texts.html.tm', {
          app => $app,
          tr => $tr,
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
      return $tr->prepare_mirror->then (sub {
        return $tr->clone_from_mirror;
      })->then (sub {
        return $tr->read_file_by_path ($tr->texts_path->child ('config.json'));
      })->then (sub {
        my $tr_config = TR::TextEntry->new_from_text_id_and_source_text (undef, $_[0] // '');
        my $langs = [grep { length } split /,/, $tr_config->get ('langs') // ''];
        $langs = ['en'] unless @$langs;
        my $specified_langs = $app->text_param_list ('lang');
        if (@$specified_langs) {
          my $avail_langs = {map { $_ => 1 } @$langs};
          @$specified_langs = grep { $avail_langs->{$_} } @$specified_langs;
          $langs = $specified_langs;
        }
        $tr->langs ($langs);
      })->then (sub {
        my $text_ids = $app->text_param_list ('text_id');
        if (@$text_ids) {
          return {map { $_ => 1 } grep { /\A[0-9a-f]{3,}\z/ } @$text_ids};
        } else {
          return $tr->text_ids;
        }
      })->then (sub {
        # XXX
        my $data = {};
        my $texts = {};
        my @id = keys %{$_[0]};
        my @p;
        my @lang = @{$tr->langs};
        my $tags = $app->text_param_list ('tag');
        my $msgid = $app->text_param ('msgid');
        undef $msgid if defined $msgid and not length $msgid;
        my $with_comments = $app->bare_param ('with_comments');
        for my $id (@id) {
          push @p, $tr->read_file_by_text_id_and_suffix ($id, 'dat')->then (sub {
            my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
            my $ok = 1;
            if (defined $msgid) {
              my $mid = $te->get ('msgid');
              return unless defined $mid;
              return unless $msgid eq $mid;
            }
            if (@$tags) {
              my $t = $te->enum ('tags');
              for (@$tags) {
                return unless $t->{$_};
              }
            }
            $data->{texts}->{$id} = $te->as_jsonalizable;
            my @q;
            for my $lang (@lang) {
              push @q, $tr->read_file_by_text_id_and_suffix ($id, $lang . '.txt')->then (sub {
                return unless defined $_[0];
                $data->{texts}->{$id}->{langs}->{$lang} = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0])->as_jsonalizable;
              });
            }
            if ($with_comments) {
              my $comments = $data->{texts}->{$id}->{comments} = [];
              push @q, $tr->read_file_by_text_id_and_suffix ($id, 'comments')->then (sub {
                for (grep { length } split /\x0D?\x0A\x0D?\x0A/, $_[0] // '') {
                  push @$comments, TR::TextEntry->new_from_text_id_and_source_text ($id, $_)->as_jsonalizable;
                }
              });
            }
            return Promise->all (\@q);
            # XXX limit
          });
        } # $id
        return Promise->all (\@p)->then (sub {
          return $app->send_json ($data);
        });
      })->catch (sub {
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
      } elsif (@$path == 7 and $path->[6] eq 'tags') {
        # .../i/{text_id}/tags
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
          return $tr->read_file_by_text_id_and_suffix ($id, 'dat');
        })->then (sub {
          my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
          my $enum = $te->enum ('tags');
          %$enum = ();
          $enum->{$_} = 1 for grep { length } @{$app->text_param_list ('tag')};
          return $tr->write_file_by_text_id_and_suffix ($id, 'dat' => $te->as_source_text);
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

      } elsif (@$path == 7 and $path->[6] eq 'args') {
        # .../i/{text_id}/args
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
          return $tr->read_file_by_text_id_and_suffix ($id, 'dat');
        })->then (sub {
          my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
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
          return $app->send_error (200); # XXX return JSON?
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
    }
  }

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

1;

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
