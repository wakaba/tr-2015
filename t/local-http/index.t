use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

my $wait = web_server;

test {
  my $c = shift;
  return GET ($c, q</>)->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 200;
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 1, name => '/ GET';

test {
  my $c = shift;
  return GET ($c, q</404>)->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 404;
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 1, name => '/404 GET';

run_tests;
stop_servers;
