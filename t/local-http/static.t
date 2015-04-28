use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

my $wait = web_server;

for my $test (
  [q</css/common.css>, q<text/css; charset=utf-8>],
  [q</js/core.js>, q<text/javascript; charset=utf-8>],
  [q</data/langs.json>, q<application/json; charset=utf-8>],
  [q</fonts/LigatureSymbols.ttf>, q<application/octet-stream>],
) {
  test {
    my $c = shift;
    return GET ($c, $test->[0])->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        is $res->header ('Content-Type'), $test->[1];
        ok $res->header ('Last-Modified');
      } $c;
      done $c;
      undef $c;
    });
  } wait => $wait, n => 3, name => [$test->[0]];
}

for my $test (
  [q</css/404.css>],
  [q</js/404.js>],
) {
  test {
    my $c = shift;
    return GET ($c, $test->[0])->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 404;
      } $c;
      done $c;
      undef $c;
    });
  } wait => $wait, n => 1, name => [$test->[0]];
}

run_tests;
stop_servers;
