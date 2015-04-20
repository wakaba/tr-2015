use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;
use Test::More;
use Test::X1;
use Promise;
use JSON::PS qw(json_bytes2perl);
use Web::UserAgent::Functions qw(http_post http_get);

my $wait = web_server;

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_get
        url => qq<http://$host/account/login>,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 405;
      ok not $res->header ('Set-Cookie');
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/account/login GET';

for my $server (qw(github hatena)) {
  test {
    my $c = shift;
    my $host = $c->received_data->{host};
    return Promise->new (sub {
      my ($ok, $ng) = @_;
      http_post
          url => qq<http://$host/account/login>,
          params => {
            server => $server,
          },
          anyevent => 1,
          max_redirect => 0,
          cb => sub {
            $ok->($_[1]);
          };
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 302;
        like $res->header ('Set-Cookie'), qr{^sk=\S+; domain=\Q@{[$c->received_data->{hostname}]}\E; path=/; expires=.+; httponly$};
        is $res->header ('Location'), qq<http://$server/auth>;
      } $c;
      done $c;
      undef $c;
    });
  } wait => $wait, n => 3, name => ['/account/login POST', $server];
}

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => qq<http://$host/account/login>,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 400;
      ok not $res->header ('Set-Cookie');
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/account/login POST no server';

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => qq<http://$host/account/login>,
        params => {
          server => 'hoge',
        },
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 400;
      ok not $res->header ('Set-Cookie');
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/account/login POST bad server';

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => qq<http://$host/account/login>,
        params => {
          server => 'github',
        },
        header_fields => {Origin => q<http://hoge.test>},
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 400;
      ok not $res->header ('Set-Cookie');
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/account/login POST bad Origin:';

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => qq<http://$host/account/login>,
        params => {
          server => 'github',
        },
        header_fields => {Referer => q<http://hoge.test/foo>},
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 400;
      ok not $res->header ('Set-Cookie');
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/account/login POST bad Referer: origin';

run_tests;
stop_servers;
