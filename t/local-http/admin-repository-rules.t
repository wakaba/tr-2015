use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

my $wait = web_server;

test {
  my $c = shift;
  return login ($c, admin => 1)->then (sub {
    return GET ($c, q</admin/repository-rules.json>)->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 404;
      } $c, name => 'no account';
    });
  })->then (sub {
    return login ($c)->then (sub {
      my $account = $_[0];
      return GET ($c, q</admin/repository-rules.json>, account => $account)->then (sub {
        my $res = $_[0];
        test {
          is $res->code, 404;
        } $c, name => 'non-admin account';
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 2, name => '/admin/repository-rules.json GET non-admin';

test {
  my $c = shift;
  return login ($c, admin => 1)->then (sub {
    return POST ($c, q</admin/repository-rules.json>)->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 403;
      } $c, name => 'no account';
    });
  })->then (sub {
    return login ($c)->then (sub {
      my $account = $_[0];
      return POST ($c, q</admin/repository-rules.json>, account => $account)->then (sub {
        my $res = $_[0];
        test {
          is $res->code, 403;
        } $c, name => 'non-admin account';
        done $c;
        undef $c;
      });
    });
  });
} wait => $wait, n => 2, name => '/admin/repository-rules.json POST non-admin';

test {
  my $c = shift;
  return login ($c, admin => 1)->then (sub {
    my $account = $_[0];
    return GET ($c, q</admin/repository-rules.json>, account => $account)->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        like $res->header ('Content-Type'), qr{application/json};
        my $json = json_bytes2perl $res->content;
        is $json->{rules}, undef;
      } $c;
    })->then (sub {
      return POST ($c, q</admin/repository-rules.json>, account => $account, params => {
        json => perl2json_chars {rules => [{foo => "\x{5000}*bar"}], ab => 44},
      });
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        like $res->header ('Content-Type'), qr{application/json};
        my $json = json_bytes2perl $res->content;
        is ref $json, 'HASH';
      } $c, name => 'POST';
    })->then (sub {
      return GET ($c, q</admin/repository-rules.json>, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        like $res->header ('Content-Type'), qr{application/json};
        my $json = json_bytes2perl $res->content;
        eq_or_diff $json, {rules => [{foo => "\x{5000}*bar"}], ab => 44};
      } $c, name => 'GET after POST, json';
    })->then (sub {
      return POST ($c, q</admin/repository-rules.ndjson>, account => $account, params => {
        json => perl2json_chars {rules => [{foo => "_\x{5000}"}], ab => 1.44},
      });
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 202;
        like $res->header ('Content-Type'), qr{ndjson};
        my $json = json_bytes2perl [split /\x0A/, $res->content]->[-1];
        is ref $json, 'HASH';
      } $c, name => 'POST, ndjson';
    })->then (sub {
      return GET ($c, q</admin/repository-rules.json>, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        like $res->header ('Content-Type'), qr{application/json};
        my $json = json_bytes2perl $res->content;
        eq_or_diff $json, {rules => [{foo => "_\x{5000}"}], ab => 1.44};
      } $c, name => 'GET after POST, json';
    })->then (sub {
      return GET ($c, q</admin/repository-rules.ndjson>, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 202;
        like $res->header ('Content-Type'), qr{ndjson};
        my $json = json_bytes2perl [split /\x0A/, $res->content]->[-1];
        eq_or_diff $json, {data => {rules => [{foo => "_\x{5000}"}], ab => 1.44}, message => 'OK', status => 200};
      } $c, name => 'GET after POST, ndjson';
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 18, name => '/admin/repository-rules.json POST admin';

test {
  my $c = shift;
  return login ($c, admin => 1)->then (sub {
    my $account = $_[0];
    return POST ($c, q</admin/repository-rules.json>, account => $account, params => {
      json => perl2json_chars {ab => 42424},
    }, header_fields => {
      Origin => q<http://hoge.test>,
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 400;
      } $c, name => 'POST';
    })->then (sub {
      return GET ($c, q</admin/repository-rules.json>, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        isnt $json->{ab}, 42424;
      } $c, name => 'GET after POST';
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 3, name => '/admin/repository-rules.json POST bad origin';

run_tests;
stop_servers;
