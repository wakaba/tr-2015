use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

my $wait = web_server;

# XXX repo errors
# XXX permission errors

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'dummy' => '',
    })->then (sub {
      return POST ($c, ['tr', $url, 'acl.json'], params => {
        operation => 'join',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'get access';
      return GET ($c, ['tr', $url, 'master', '/', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        eq_or_diff $json->{avail_lang_keys}, ['en'];
        is $json->{langs}->{en}->{key}, 'en';
        is $json->{langs}->{en}->{id}, 'en';
        is $json->{langs}->{en}->{label}, 'en';
        is $json->{langs}->{en}->{label_short}, 'en';
        is $json->{langs}->{en}->{label_raw}, undef;
        is $json->{langs}->{en}->{label_short_raw}, undef;
        is $json->{license}->{type}, undef;
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 10, name => 'no config.json';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'texts/config.json' => perl2json_bytes +{
        avail_lang_keys => ['fr', 'it', 'it', {}, undef, 12, '--', 'FO'],
        langs => {
          fr => {desc => 'fr', id => 'fr-fr'},
          '12' => {id => 'en'},
          es => {desc => 'Spanish'},
        },
        license => {type => 'hoge'},
      },
    })->then (sub {
      return POST ($c, ['tr', $url, 'acl.json'], params => {
        operation => 'join',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'get access';
      return GET ($c, ['tr', $url, 'master', '/', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        eq_or_diff $json->{avail_lang_keys}, ['fr', 'it', '12'];
        is $json->{langs}->{fr}->{key}, 'fr';
        is $json->{langs}->{12}->{key}, '12';
        is $json->{langs}->{es}->{key}, undef;
        is $json->{langs}->{en}->{key}, undef;
        is $json->{langs}->{fo}->{key}, undef;
        is $json->{langs}->{FO}->{key}, undef;
        is $json->{license}->{type}, 'hoge';
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 10, name => 'has config.json';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'texts/config.json' => perl2json_bytes +{
        avail_lang_keys => 'en,ja',
        langs => 'en=ja',
        license => 12,
      },
    })->then (sub {
      return POST ($c, ['tr', $url, 'acl.json'], params => {
        operation => 'join',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'get access';
      return GET ($c, ['tr', $url, 'master', '/', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        eq_or_diff $json->{avail_lang_keys}, ['en'];
        is $json->{langs}->{en}->{key}, 'en';
        is $json->{langs}->{en}->{id}, 'en';
        is $json->{langs}->{en}->{label}, 'en';
        is $json->{langs}->{en}->{label_short}, 'en';
        is $json->{langs}->{en}->{label_raw}, undef;
        is $json->{langs}->{en}->{label_short_raw}, undef;
        is $json->{license}->{type}, undef;
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 10, name => 'broken config.json';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'hoge/fuga/texts/config.json' => perl2json_bytes +{
        avail_lang_keys => ['fr', 'it', 'it', {}, undef, 12, '--', 'FO'],
        langs => {
          fr => {desc => 'fr', id => 'fr-fr'},
          '12' => {id => 'en'},
          es => {desc => 'Spanish'},
        },
        license => {type => 'hoge'},
      },
    })->then (sub {
      return POST ($c, ['tr', $url, 'acl.json'], params => {
        operation => 'join',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'get access';
      return GET ($c, ['tr', $url, 'master', '/hoge/fuga', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        eq_or_diff $json->{avail_lang_keys}, ['fr', 'it', '12'];
        is $json->{langs}->{fr}->{key}, 'fr';
        is $json->{langs}->{12}->{key}, '12';
        is $json->{langs}->{es}->{key}, undef;
        is $json->{langs}->{en}->{key}, undef;
        is $json->{langs}->{fo}->{key}, undef;
        is $json->{langs}->{FO}->{key}, undef;
        is $json->{license}->{type}, 'hoge';
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 10, name => 'deep text set, has config.json';

# XXX scopes tests

run_tests;
stop_servers;
