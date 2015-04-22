use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

my $wait = web_server;

test {
  my $c = shift;
  return GET ($c, q</account/login>)->then (sub {
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
    return POST ($c, q</account/login>, params => {
      server => $server,
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
  return POST ($c, q</account/login>)->then (sub {
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
  return POST ($c, q</account/login>, params => {
    server => 'hge',
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
  return POST ($c, q</account/login>, params => {
    server => 'github',
  },
  header_fields => {Origin => q<http://hoge.test>})->then (sub {
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
  return POST ($c, q</account/login>,
    params => {
      server => 'github',
    },
    header_fields => {Referer => q<http://hoge.test/foo>},
  )->then (sub {
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
