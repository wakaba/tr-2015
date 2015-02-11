package TR::Web;
use strict;
use warnings;
use Path::Tiny;
use Wanage::HTTP;
use TR::AppServer;
use TR::TextRepo;

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
    if (@$path == 4 and
        ($path->[3] eq '/' or $path->[3] =~ m{\A(?:/[0-9A-Za-z_.-]+)+\z}) and
        not "$path->[3]/" =~ m{/\.\.?/}) {
      # XXX {url} validation
      # XXX {branch}

      my $tr = TR::TextRepo->new_from_temp_path (Path::Tiny->tempdir);
      $tr->texts_dir (substr $path->[3], 1);
      return $tr->clone_by_url ($path->[1])->then (sub {
        return $tr->text_ids;
      })->then (sub {
        return $app->temma ('tr.texts.html.tm', {ids => $_[0]});
      })->catch (sub {
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
