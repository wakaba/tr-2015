use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;
use Test::More;
use Test::X1;
use Promise;
use Web::UserAgent::Functions qw(http_post http_get);

my $wait = web_server;

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_get
        url => qq<http://$host/>,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
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
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_get
        url => qq<http://$host/404>,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
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
