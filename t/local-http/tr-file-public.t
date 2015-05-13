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
      my $eurl = percent_encode_c q<file:///pub/notfound/> . rand;
      for my $t (
        {path => qq</r/$eurl/acl>, status => 403},
        {path => qq</r/$eurl/info.json>},
        {path => qq</r/$eurl/>},
      ) {
        push @p, GET ($c, $t->{path})->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{status} // 404;
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 1*3, name => 'non-user / not found';

test {
  my $c = shift;
  return login ($c, admin => 0)->then (sub {
    my $account = $_[0];
    return Promise->resolve->then (sub {
      my @p;
      my $eurl = percent_encode_c q<file:///pub/notfound/> . rand;
      for my $t (
        {path => qq</r/$eurl/acl>, status => 403},
        {path => qq</r/$eurl/info.json>},
        {path => qq</r/$eurl/>},
      ) {
        push @p, GET ($c, $t->{path}, account => $account)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{status} // 404;
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 1*3, name => 'normal user / not found';

test {
  my $c = shift;
  return login ($c, admin => 1)->then (sub {
    my $account = $_[0];
    return Promise->resolve->then (sub {
      my @p;
      my $eurl = percent_encode_c q<file:///pub/notfound/> . rand;
      for my $t (
        {path => qq</r/$eurl/acl>, status => 403},
        {path => qq</r/$eurl/info.json>},
        {path => qq</r/$eurl/>},
      ) {
        push @p, GET ($c, $t->{path}, account => $account)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{status} // 404;
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 1*3, name => 'admin user / not owner / not found';

test {
  my $c = shift;
  return login ($c, admin => 1)->then (sub {
    my $account = $_[0];
    my $eurl = percent_encode_c q<file:///pub/notfound/> . rand;
    POST ($c, qq</r/$eurl/acl.json>, params => {
      operation => 'join',
    }, account => $account)->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 404;
      } $c;
    })->then (sub {
      my @p;
      for my $t (
        {path => qq</r/$eurl/acl>, status => 403},
        {path => qq</r/$eurl/acl.json>, status => 403},
        {path => qq</r/$eurl/acl.ndjson>, status => 202},
        {path => qq</r/$eurl/info.json>},
        {path => qq</r/$eurl/>},
      ) {
        push @p, GET ($c, $t->{path}, account => $account)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{status} // 404;
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 1+1*5, name => 'admin user / not owner / not found';

test {
  my $c = shift;
  return Promise->all ([
    login ($c, admin => 1),
    login ($c),
  ])->then (sub {
    my $account1 = $_[0]->[0];
    my $account2 = $_[0]->[1];
    my $key = rand;
    my $eurl = percent_encode_c q<file:///pub/> . $key;
    (git_repo $c->received_data->{repos_path}->child ("pub/$key"), files => {
      hoge => 'foo',
    })->then (sub {
      return POST ($c, qq</r/$eurl/acl.json>, params => {
        operation => 'join',
      }, account => $account1)->then (sub {
        my $res = $_[0];
        test {
          is $res->code, 200;
        } $c;
      });
    })->then (sub {
      my @p;
      for my $t (
        {path => qq</r/$eurl/acl>, guest_status => 403},
        {path => qq</r/$eurl/acl.json>, guest_status => 403},
        {path => qq</r/$eurl/acl.ndjson>, guest_status => 202, status => 202},
        {path => qq</r/$eurl/info.json>},
        {path => qq</r/$eurl/>},
      ) {
        push @p, GET ($c, $t->{path}, account => $account1)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{status} // 200;
          } $c;
        });
        push @p, GET ($c, $t->{path}, account => $account2)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{guest_status} // 200;
          } $c;
        });
        push @p, GET ($c, $t->{path})->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{guest_status} // 200;
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 1+3*5, name => 'has owner / found';

test {
  my $c = shift;
  return Promise->all ([
    login ($c, admin => 1),
    login ($c),
  ])->then (sub {
    my $account1 = $_[0]->[0];
    my $account2 = $_[0]->[1];
    my $key = rand;
    my $eurl = percent_encode_c q<file:///pub/> . $key;
    (git_repo $c->received_data->{repos_path}->child ("pub/$key"), files => {
      hoge => 'foo',
    })->then (sub {
      my @p;
      for my $t (
        {path => qq</r/$eurl/acl>, guest_status => 403},
        {path => qq</r/$eurl/acl.json>, guest_status => 403},
        {path => qq</r/$eurl/acl.ndjson>, guest_status => 202, status => 202},
        {path => qq</r/$eurl/info.json>},
        {path => qq</r/$eurl/>},
      ) {
        push @p, GET ($c, $t->{path}, account => $account1)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{guest_status} // 404;
          } $c;
        });
        push @p, GET ($c, $t->{path}, account => $account2)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{guest_status} // 404;
          } $c;
        });
        push @p, GET ($c, $t->{path})->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{guest_status} // 404;
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 3*5, name => 'no owner / found';

test {
  my $c = shift;
  return Promise->all ([
    login ($c, admin => 1),
    login ($c),
  ])->then (sub {
    my $account1 = $_[0]->[0];
    my $account2 = $_[0]->[1];
    my $key = rand;
    my $eurl = percent_encode_c q<file:///pub/> . $key;
    (git_repo $c->received_data->{repos_path}->child ("pub/$key"), files => {
      hoge => 'foo',
    })->then (sub {
      return POST ($c, qq</r/$eurl/acl.json>, params => {
        operation => 'join',
      }, account => $account2)->then (sub {
        my $res = $_[0];
        test {
          is $res->code, 403;
        } $c;
      });
    })->then (sub {
      my @p;
      for my $t (
        {path => qq</r/$eurl/acl>, guest_status => 403},
        {path => qq</r/$eurl/acl.json>, guest_status => 403},
        {path => qq</r/$eurl/acl.ndjson>, guest_status => 202, status => 202},
        {path => qq</r/$eurl/info.json>},
        {path => qq</r/$eurl/>},
      ) {
        push @p, GET ($c, $t->{path}, account => $account1)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{guest_status} // 404;
          } $c;
        });
        push @p, GET ($c, $t->{path}, account => $account2)->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{guest_status} // 404;
          } $c;
        });
        push @p, GET ($c, $t->{path})->then (sub {
          my $res = $_[0];
          test {
            is $res->code, $t->{guest_status} // 404;
          } $c;
        });
      }
      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 1+3*5, name => 'no owner / found / normal user cannot join';

run_tests;
stop_servers;
