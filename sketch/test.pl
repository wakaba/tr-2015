use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use AnyEvent;
use Promise;
use Promised::Plackup;
use Promised::Docker::WebDriver;
use Web::UserAgent::Functions qw(http_post_data);
use JSON::PS;

my $root_path = path (__FILE__)->parent->parent;
my $plackup = Promised::Plackup->new;
$plackup->plackup ($root_path->child ('plackup'));
$plackup->set_option ('--app' => $root_path->child ('bin/server.psgi'));

sub wd_post ($$) {
  my ($url, $json) = @_;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post_data
        url => $url,
        content => perl2json_bytes ($json || {}),
        timeout => 100,
        anyevent => 1,
        cb => sub {
          my (undef, $res) = @_;
          if ($res->code == 200) {
            my $json = json_bytes2perl $res->content;
            if (defined $json and ref $json) {
              $ok->($json);
            } else {
              $ng->($res->code . "\n" . $res->content);
            }
          } elsif ($res->is_success) {
            $ok->({status => $res->code});
          } else {
            $ng->($res->code . "\n" . $res->content);
          }
        };
  });
} # wd_post

my $wd = Promised::Docker::WebDriver->chrome;

my $cv = AE::cv;

$wd->start->then (sub {
  $plackup->set_option ('--host' => $wd->get_docker_host_hostname_for_host);
  return $plackup->start;
})->then (sub {
  my $wd_url = $wd->get_url_prefix;
  my $host = $wd->get_docker_host_hostname_for_container . ':' . $plackup->get_port;

  return wd_post ("$wd_url/session", {
    desiredCapabilities => {
      browserName => 'firefox',
    },
  })->then (sub {
    my $json = $_[0];
    my $sid = $json->{sessionId};
    warn $host;
    return wd_post ("$wd_url/session/$sid/url", {
      url => qq<http://$host/>,
    })->then (sub {
      return wd_post ("$wd_url/session/$sid/execute", {
        script => q{ return document.documentElement.textContent },
        args => [],
      });
    })->then (sub {
      my $value = $_[0]->{value};
      warn $value;
    });
  });
})->catch (sub {
  warn "Error: $_[0]";
})->then (sub {
  return Promise->all ([
    $plackup->stop,
    $wd->stop,
  ]);
})->catch (sub {
  warn "Error2: $_[0]";
})->then (sub {
  $cv->send;
});

$cv->recv;
