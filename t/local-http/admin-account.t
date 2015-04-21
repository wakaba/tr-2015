use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;
use Test::More;
use Test::X1;
use Promise;
use Web::UserAgent::Functions qw(http_post http_get);
use JSON::PS;

my $wait = web_server;

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_get
        url => qq<http://$host/admin/account>,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
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
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_get
        url => qq<http://$host/admin/account>,
        basic_auth => ['foo', 'bar'],
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
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
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_get
        url => qq<http://$host/admin/account>,
        basic_auth => ['admin', $c->received_data->{admin_token}],
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
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
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => qq<http://$host/admin/account>,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
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
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => qq<http://$host/admin/account>,
        basic_auth => ['foo', 'bar'],
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
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
  my $host = $c->received_data->{host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => qq<http://$host/admin/account>,
        basic_auth => ['admin', $c->received_data->{admin_token}],
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
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
  my $host = $c->received_data->{host};
  return login ($c)->then (sub {
    my $account = $_[0];
    return Promise->new (sub {
      my ($ok, $ng) = @_;
      http_post
          url => qq<http://$host/admin/account>,
          basic_auth => ['admin', $c->received_data->{admin_token}],
          cookies => {sk => $account->{sk}},
          anyevent => 1,
          max_redirect => 0,
          cb => sub {
            $ok->($_[1]);
          };
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 302;
        is $res->header ('Location'),
            qq{http://$host/tr/about:siteadmin/acl};
      } $c;
    })->then (sub {
      return Promise->new (sub {
        my ($ok, $ng) = @_;
        http_get
            url => qq<http://$host/tr/about:siteadmin/acl.json>,
            cookies => {sk => $account->{sk}},
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
          ok $json->{accounts}->{$account->{account_id}}->{scopes}->{repo};
        } $c;
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 4, name => '/admin/account POST with user';

test {
  my $c = shift;
  my $host = $c->received_data->{host};
  return login ($c)->then (sub {
    my $account = $_[0];
    return Promise->new (sub {
      my ($ok, $ng) = @_;
      http_post
          url => qq<http://$host/admin/account>,
          basic_auth => ['admin', $c->received_data->{admin_token}],
          cookies => {sk => $account->{sk}},
          anyevent => 1,
          max_redirect => 0,
          cb => sub {
            $ok->($_[1]);
          };
    })->then (sub {
      return Promise->new (sub {
        my ($ok, $ng) = @_;
        http_post
            url => qq<http://$host/admin/account>,
            basic_auth => ['admin', $c->received_data->{admin_token}],
            cookies => {sk => $account->{sk}},
            anyevent => 1,
            max_redirect => 0,
            cb => sub {
              $ok->($_[1]);
            };
      });
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 302;
        is $res->header ('Location'),
            qq{http://$host/tr/about:siteadmin/acl};
      } $c;
    })->then (sub {
      return Promise->new (sub {
        my ($ok, $ng) = @_;
        http_get
            url => qq<http://$host/tr/about:siteadmin/acl.json>,
            cookies => {sk => $account->{sk}},
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
          ok $json->{accounts}->{$account->{account_id}}->{scopes}->{repo};
        } $c;
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 4, name => '/admin/account POST existing user';

run_tests;
stop_servers;
