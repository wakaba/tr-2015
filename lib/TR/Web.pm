package TR::Web;
use strict;
use warnings;
use Path::Tiny;
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

    # XXX {url} validation
    # XXX {branch}
    my $tr = TR::TextRepo->new_from_temp_path (Path::Tiny->tempdir);
    $tr->texts_dir (substr $path->[3], 1);

    if (@$path == 5 and $path->[4] eq '') {
      return $tr->clone_by_url ($path->[1])->then (sub {
        return $tr->text_ids;
      })->then (sub {
        # XXX
        my $texts = {};
        my @id = keys %{$_[0]};
        my @p;
        my @lang = qw(ja en); # XXX
        for my $id (@id) {
          push @p, $tr->read_file_by_text_id_and_suffix ($id, 'txt')->then (sub {
            $texts->{$id}->{common} = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
          }, sub {
            $texts->{$id}->{common} = TR::TextEntry->new_from_text_id_and_source_text ($id, '');
            die $_[0]; # XXX
          });
          for my $lang (@lang) {
            push @p, $tr->read_file_by_text_id_and_suffix ($id, $lang . '.txt')->then (sub {
              $texts->{$id}->{langs}->{$lang} = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
            }, sub {
              $texts->{$id}->{langs}->{$lang} = TR::TextEntry->new_from_text_id_and_source_text ($id, '');
              die $_[0]; # XXX
            });
          }
        }
        return Promise->all (\@p)->then (sub {
          return $app->temma ('tr.texts.html.tm', {texts => $texts, langs => \@lang});
        });
      })->catch (sub {
        $app->error_log ($_[0]);
        return $app->send_error (500);
      })->then (sub {
        return $tr->discard;
      });

    } elsif (@$path == 7 and $path->[4] eq 'i' and $path->[6] eq '') {
      # .../i/{text_id}/
      $app->requires_request_method ({POST => 1});
      # XXX CSRF

      # XXX access control

      my $id = $path->[5];
      # XXX validation

      # XXX
      my $auth = $app->http->request_auth;
      unless (defined $auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
        $app->http->set_response_auth ('basic', realm => $path->[1]);
        return $app->send_error (401);
      }
      my $url = $path->[1];
      $url =~ s{^https://}{https://$auth->{userid}:$auth->{password}\@}; # XXX percent-encode

      my $lang = $app->text_param ('lang') or $app->throw_error (400); # XXX lang validation
      return $tr->clone_by_url ($url)->then (sub {
        return $tr->read_file_by_text_id_and_suffix ($id, $lang . '.txt');
      })->then (sub {
        my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
        for (qw(body_o)) {
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

    } elsif (@$path == 5 and $path->[4] eq 'add') {
      $app->requires_request_method ({POST => 1});
      # XXX CSRF

      # XXX access control

      # XXX
      my $auth = $app->http->request_auth;
      unless (defined $auth->{auth_scheme} and $auth->{auth_scheme} eq 'basic') {
        $app->http->set_response_auth ('basic', realm => $path->[1]);
        return $app->send_error (401);
      }
      my $url = $path->[1];
      $url =~ s{^https://}{https://$auth->{userid}:$auth->{password}\@}; # XXX percent-encode

      return $tr->clone_by_url ($url)->then (sub {
        my $id = $tr->generate_text_id;
        return Promise->all ([
          Promise->resolve->then (sub {
            my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, '');
            my $msgid = $app->text_param ('msgid');
            if (defined $msgid) {
              # XXX check duplication
              $te->set (msgid => $msgid);
            }
            return $tr->write_file_by_text_id_and_suffix ($id, 'txt' => $te->as_source_text);
          }),
        ]);
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
    }
  }

  if (@$path == 2 and
      {js => 1, css => 1, data => 1, images => 1}->{$path->[0]} and
      $path->[1] =~ /\A[0-9A-Za-z_-]+\.(js|css|jpe?g|gif|png|json)\z/) {
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

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
