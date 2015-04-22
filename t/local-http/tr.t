use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;
use JSON::PS qw(json_bytes2perl);

my $wait = web_server;

test {
  my $c = shift;
  return GET ($c, q</tr>)->then (sub {
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
  return GET ($c, q</tr/>)->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 302;
      my $host = $c->received_data->{host};
      is $res->header ('Location'), qq<http://$host/tr>;
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/tr/ GET';

test {
  my $c = shift;
  return GET ($c, q</tr.json>)->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 200;
      my $json = json_bytes2perl $res->content;
      ok not keys %{$json->{joined}->{data} or {}};
      ok not keys %{$json->{github}->{data} or {}};
      is $res->header ('Cache-Control'), 'private';
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 4, name => '/tr.json GET non user';

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  login ($c)->then (sub {
    my $user = $_[0];
    return GET ($c, q</tr.json>)->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        ok not keys %{$json->{joined}->{data} or {}};
        ok not keys %{$json->{github}->{data} or {}};
        is $res->header ('Cache-Control'), 'private';
      } $c;
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 4, name => '/tr.json GET with session';

# XXX /tr.json GET has data
# XXX /tr.ndjson
# XXX /tr.* POST

run_tests;
stop_servers;
