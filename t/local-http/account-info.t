use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;
use JSON::PS qw(json_bytes2perl);

my $wait = web_server;

test {
  my $c = shift;
  return GET ($c, q</account/info.json>)->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 200;
      my $json = json_bytes2perl $res->content;
      is $json->{account_id}, undef;
      is $json->{name}, undef;
      is $res->header ('Cache-Control'), 'private';
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 4, name => '/account/info.json GET non user';

test {
  my $c = shift;
  return GET ($c, q</account/info.json>, cookies => {
    sk => rand,
  })->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 200;
      my $json = json_bytes2perl $res->content;
      is $json->{account_id}, undef;
      is $json->{name}, undef;
      is $res->header ('Cache-Control'), 'private';
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 4, name => '/account/info.json GET bad session';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $user = $_[0];
    return GET ($c, q</account/info.json>, cookies => {
      sk => $user->{sk},
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        is $json->{account_id}, $user->{account_id};
        is $json->{name}, $user->{name};
        isnt $json->{account_id}, undef;
        isnt $json->{name}, undef;
        like $res->content, qr{"account_id"\s*:\s*"[0-9]+"};
        is $res->header ('Cache-Control'), 'private';
      } $c;
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 7, name => '/account/info.json GET with session';

run_tests;
stop_servers;
