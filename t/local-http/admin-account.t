use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;
use JSON::PS;

my $wait = web_server;

test {
  my $c = shift;
  return GET ($c, q</admin/account>)->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 401;
      like $res->header ('WWW-Authenticate'), qr{Basic realm=};
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/admin/account GET no auth';

test {
  my $c = shift;
  return GET ($c, q</admin/account>,
    basic_auth => ['foo', 'bar'],
  )->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 401;
      like $res->header ('WWW-Authenticate'), qr{Basic realm=};
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/admin/account GET bad auth';

test {
  my $c = shift;
  return GET ($c, q</admin/account>,
    basic_auth => ['admin', $c->received_data->{admin_token}],
  )->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 200;
      like $res->header ('Content-Type'), qr{text/html};
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/admin/account GET with auth';

test {
  my $c = shift;
  return POST ($c, q</admin/account>)->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 401;
      like $res->header ('WWW-Authenticate'), qr{Basic realm=};
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/admin/account POST no auth';

test {
  my $c = shift;
  return POST ($c, q</admin/account>,
    basic_auth => ['foo', 'bar'],
  )->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 401;
      like $res->header ('WWW-Authenticate'), qr{Basic realm=};
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 2, name => '/admin/account POST bad auth';

test {
  my $c = shift;
  return POST ($c, q</admin/account>,
    basic_auth => ['admin', $c->received_data->{admin_token}],
  )->then (sub {
    my $res = $_[0];
    test {
      is $res->code, 403;
    } $c;
    done $c;
    undef $c;
  });
} wait => $wait, n => 1, name => '/admin/account POST no user';

test {
  my $c = shift;
  return login ($c)->then (sub {
    my $account = $_[0];
    return POST ($c, q</admin/account>,
      basic_auth => ['admin', $c->received_data->{admin_token}],
      account => $account,
    )->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 302;
        my $host = $c->received_data->{host};
        is $res->header ('Location'),
            qq{http://$host/tr/about:siteadmin/acl};
      } $c;
    })->then (sub {
      return GET ($c, q</tr/about:siteadmin/acl.json>, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        ok $json->{accounts}->{$account->{account_id}}->{scopes}->{repo};
      } $c;
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 4, name => '/admin/account POST with user';

test {
  my $c = shift;
  return login ($c)->then (sub {
    my $account = $_[0];
    return POST ($c, q</admin/account>,
      basic_auth => ['admin', $c->received_data->{admin_token}],
      account => $account,
    )->then (sub {
      return POST ($c, q</admin/account>,
        basic_auth => ['admin', $c->received_data->{admin_token}],
        account => $account,
      );
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 302;
        my $host = $c->received_data->{host};
        is $res->header ('Location'),
            qq{http://$host/tr/about:siteadmin/acl};
      } $c;
    })->then (sub {
      return GET ($c, q</tr/about:siteadmin/acl.json>, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        ok $json->{accounts}->{$account->{account_id}}->{scopes}->{repo};
      } $c;
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 4, name => '/admin/account POST existing user';

run_tests;
stop_servers;
