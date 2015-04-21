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
  return Promise->resolve->then (sub {
    return Promise->resolve->then (sub {
      my @p;
      for my $t (
        {path => q</tr/about:siteadmin/acl>, status => 403},
        {path => q</tr/about:siteadmin/info.json>, mime => 'application/json'},
      ) {
        push @p, Promise->new (sub {
          my ($ok, $ng) = @_;
          http_get
              url => qq{http://$host$t->{path}},
              anyevent => 1,
              max_redirect => 0,
              cb => sub {
                $ok->($_[1]);
              };
        })->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{status} // 404;
          } $c;
        });
      }
      for my $t (
        {path => q</tr/about:siteadmin/>},
      ) {
        push @p, Promise->new (sub {
          my ($ok, $ng) = @_;
          http_get
              url => qq{http://$host$t->{path}},
              anyevent => 1,
              max_redirect => 0,
              cb => sub {
                $ok->($_[1]);
              };
        })->then (sub {
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
  my $host = $c->received_data->{host};
  return login ($c)->then (sub {
    my $account = $_[0];
    return Promise->resolve->then (sub {
      my @p;
      for my $t (
        {path => q</tr/about:siteadmin/acl>, status => 403},
        {path => q</tr/about:siteadmin/info.json>, mime => 'application/json'},
      ) {
        push @p, Promise->new (sub {
          my ($ok, $ng) = @_;
          http_get
              url => qq{http://$host$t->{path}},
              cookies => {sk => $account->{sk}},
              anyevent => 1,
              max_redirect => 0,
              cb => sub {
                $ok->($_[1]);
              };
        })->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{status} // 404;
          } $c;
        });
      }
      for my $t (
        {path => q</tr/about:siteadmin/>},
      ) {
        push @p, Promise->new (sub {
          my ($ok, $ng) = @_;
          http_get
              url => qq{http://$host$t->{path}},
              cookies => {sk => $account->{sk}},
              anyevent => 1,
              max_redirect => 0,
              cb => sub {
                $ok->($_[1]);
              };
        })->then (sub {
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
      my @p;
      for my $t (
        {path => q</tr/about:siteadmin/acl>},
      ) {
        push @p, Promise->new (sub {
          my ($ok, $ng) = @_;
          http_get
              url => qq{http://$host$t->{path}},
              cookies => {sk => $account->{sk}},
              anyevent => 1,
              max_redirect => 0,
              cb => sub {
                $ok->($_[1]);
              };
        })->then (sub {
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
        push @p, Promise->new (sub {
          my ($ok, $ng) = @_;
          http_get
              url => qq{http://$host$t->{path}},
              cookies => {sk => $account->{sk}},
              anyevent => 1,
              max_redirect => 0,
              cb => sub {
                $ok->($_[1]);
              };
        })->then (sub {
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
