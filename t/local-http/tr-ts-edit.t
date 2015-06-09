use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

my $wait = web_server;

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return GET ($c, ['r', $url, 'master', '/', 'edit.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 405;
        is $res->header ('Allow'), 'POST';
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 3, name => 'edit.json GET';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    Promise->resolve->then (sub {
      return POST ($c, ['r', 'hoge:foo', 'foo', '/hoge', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 404;
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 1, name => 'edit.json bad repo url';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'foo', '/hoge', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 404;
      } $c;
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json bad branch';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', 'hoge', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 404;
      } $c;
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json bad text set';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account, header_fields => {
        Origin => 'http://hoge.test',
      });
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 400;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json CSRF';

test {
  my $c = shift;
  Promise->resolve->then (sub {
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return git_rev ($path),
    })->then (sub {
      $initial_rev = $_[0];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ]);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 403;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json no account';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return git_rev ($path),
    })->then (sub {
      $initial_rev = $_[0];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 403;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json no read permission';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        ('xyz' x 10000000)
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 413;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json entity body too long';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account, header_fields => {
        'Content-Type' => undef,
      });
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 415;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json bad MIME type';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => 135, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 400;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json bad JSON';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['read']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 204;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json empty commands';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'edited';
      return is_resolved_with_not $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json non-empty commands';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.ndjson'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 202;
        my $json = json_bytes2perl [split /\x0A/, $res->content]->[-1];
        is $json->{status}, 200;
      } $c, name => 'edited';
      return is_resolved_with_not $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 3, name => 'edit.ndjson non-empty commands';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
        undef,
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 400;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json bad command';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.ndjson'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
        undef,
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 202;
        my $json = json_bytes2perl [split /\x0A/, $res->content]->[-1];
        is $json->{status}, 400;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 3, name => 'edit.ndjson bad command';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'texts', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 418;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json unknown command';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['read']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'en', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 403;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json command not allowed';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'text', text_id => '436322', lang => 'fr', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 409;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json lang not allowed';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    my $initial_rev;
    return git_repo ($path, files => {
      'texts/43/6322.en.txt' => '',
    })->then (sub {
      return Promise->all ([
        grant_scopes ($c, $url, $account, ['edit']),
        git_rev ($path),
      ]);
    })->then (sub {
      $initial_rev = $_[0]->[1];
      return POST ($c, ['r', $url, 'master', '/', 'edit.json'], json => [
        {action => 'text', lang => 'en', body_0 => 'foo'},
      ], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 400;
      } $c, name => 'edited';
      return is_resolved_with $c, git_rev ($path), $initial_rev;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'edit.json no text_id';

run_tests;
stop_servers;
