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
        url => qq<http://$host/tr>,
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
} wait => $wait, n => 1, name => '/tr GET non user';

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_get
        url => qq<http://$host/tr/>,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 302;
      is $res->header ('Location'), qq<http://$host/tr>;
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/tr/ GET';

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_get
        url => qq<http://$host/tr.json>,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 200;
      my $json = json_bytes2perl $res->content;
      ok not $json->{joined};
      ok not $json->{github};
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 3, name => '/tr.json GET non user';

# XXX /tr.json GET with sk
# XXX /tr.ndjson
# XXX /tr.* POST

run_tests;
stop_servers;
