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
      return POST ($c, ['tr', $url, 'master', '/', 'i', $text_id, 'text.json'], params => {
        lang => 'en',
        body_0 => 'abc',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'edited';
      return Promise->all ([
        file_from_git_repo ($path, (sprintf 'texts/%s/%s.en.txt', (substr $text_id, 0, 2), (substr $text_id, 2)))->then (sub {
          my $data = $_[0];
          test {
            like $data, qr{^\$body_0:abc$}m;
          } $c, name => 'text data saved';
        }),
      ]);
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 3, name => 'texts.json POST new test';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'texts.json' => (perl2json_bytes {
        export => [
          {
            lang => 'en',
            format => 'po',
            fileTemplate => '{lang}/lang-{lang}.po',
          },
        ],
      }),
    })->then (sub {
      return POST ($c, ['tr', $url, 'acl.json'], params => {
        operation => 'join',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'get access';
      return POST ($c, ['tr', $url, 'master', '/', 'i', $text_id, 'meta.json'], params => {
        msgid => 'hoge.foo',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'set msgid';
      return POST ($c, ['tr', $url, 'master', '/', 'i', $text_id, 'text.json'], params => {
        lang => 'en',
        body_0 => 'abc',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'edited';
      return Promise->all ([
        file_from_git_repo ($path, (sprintf 'texts/%s/%s.en.txt', (substr $text_id, 0, 2), (substr $text_id, 2)))->then (sub {
          my $data = $_[0];
          test {
            like $data, qr{^\$body_0:abc$}m;
          } $c, name => 'text data saved';
        }),
        file_from_git_repo ($path, 'en/lang-en.po')->then (sub {
          my $data = $_[0];
          test {
            like $data, qr{"abc"}m;
          } $c, name => '.po exported';
        }),
      ]);
    })->then (sub {
      return POST ($c, ['tr', $url, 'master', '/', 'i', $text_id, 'text.json'], params => {
        lang => 'en',
        body_0 => 'XYZ',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'edited (2)';
      return Promise->all ([
        file_from_git_repo ($path, (sprintf 'texts/%s/%s.en.txt', (substr $text_id, 0, 2), (substr $text_id, 2)))->then (sub {
          my $data = $_[0];
          test {
            like $data, qr{^\$body_0:XYZ$}m;
          } $c, name => 'text data saved (2)';
        }),
        file_from_git_repo ($path, 'en/lang-en.po')->then (sub {
          my $data = $_[0];
          test {
            like $data, qr{"XYZ"}m;
          } $c, name => '.po exported (2)';
        }),
      ]);
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 8, name => 'texts.json POST with export';

run_tests;
stop_servers;
