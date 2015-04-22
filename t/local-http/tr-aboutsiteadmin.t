use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

my $wait = web_server;

test {
  my $c = shift;
  return Promise->resolve->then (sub {
    return Promise->resolve->then (sub {
      my @p;
      for my $t (
        {path => q</tr/about:siteadmin/acl>, status => 403},
        {path => q</tr/about:siteadmin/info.json>, mime => 'application/json'},
      ) {
        push @p, GET ($c, $t->{path})->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{status} // 404;
          } $c;
        });
      }
      for my $t (
        {path => q</tr/about:siteadmin/>},
      ) {
        push @p, GET ($c, $t->{path})->then (sub {
          my $res = $_[0];
          test {
            is $res->code, 404, $t->{path};
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 1*3, name => 'non-user access';

test {
  my $c = shift;
  return login ($c)->then (sub {
    my $account = $_[0];
    return Promise->resolve->then (sub {
      my @p;
      for my $t (
        {path => q</tr/about:siteadmin/acl>, status => 403},
        {path => q</tr/about:siteadmin/info.json>, mime => 'application/json'},
      ) {
        push @p, GET ($c, $t->{path})->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{status} // 404;
          } $c;
        });
      }
      for my $t (
        {path => q</tr/about:siteadmin/>},
      ) {
        push @p, GET ($c, $t->{path})->then (sub {
          my $res = $_[0];
          test {
            is $res->code, 404, $t->{path};
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 1*3, name => 'normal user access';

test {
  my $c = shift;
  return login ($c)->then (sub {
    my $account = $_[0];
    return POST ($c, q</admin/account>,
      basic_auth => ['admin', $c->received_data->{admin_token}],
      account => $account,
    )->then (sub {
      my @p;
      for my $t (
        {path => q</tr/about:siteadmin/acl>},
      ) {
        push @p, GET ($c, $t->{path}, account => $account)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, 200, $t->{path};
            like $res->header ('Content-Type'), qr{@{[$t->{mime} // 'text/html']}};
          } $c;
        });
      }
      for my $t (
        {path => q</tr/about:siteadmin/>},
        {path => q</tr/about:siteadmin/info.json>, mime => 'application/json'},
      ) {
        push @p, GET ($c, $t->{path}, account => $account)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, 404, $t->{path};
            like $res->header ('Content-Type'), qr{text/};
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 2*3, name => 'admin user access';

run_tests;
stop_servers;
