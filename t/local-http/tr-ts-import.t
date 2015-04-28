use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

my $wait = web_server;

# XXX GET
# XXX CSRF
# XXX repo errors
# XXX permission

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
      return POST ($c, ['r', $url, 'acl.json'], params => {
        operation => 'join',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'get access';
      return POST ($c, ['r', $url, 'master', '/', 'i', $text_id, 'text.json'], params => {
        lang => 'en',
        body_0 => 'abc',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'edited';
      return POST ($c, ['r', $url, 'master', '/', 'import.json'], params => {
        from => 'file',
        format => 'po',
        lang => 'en',
      }, files => {
        file => {
          ref => \q{msgid ""
msgstr ""

msgid "abcd"
msgstr "ABCD"},
        },
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'imported';
      return Promise->all ([
        file_from_git_repo ($path, (sprintf 'texts/%s/%s.en.txt', (substr $text_id, 0, 2), (substr $text_id, 2)))->then (sub {
          my $data = $_[0];
          test {
            like $data, qr{^\$body_0:abc$}m;
          } $c, name => 'existing data not affected';
        }),
      ]);
    })->then (sub {
      return GET ($c, ['r', $url, 'master', '/', 'data.json'], params => {
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      my $json = json_bytes2perl $res->content;
      test {
        my $abcd = [];
        for my $text_id (keys %{$json->{texts}}) {
          my $text = $json->{texts}->{$text_id};
          if (defined $text->{msgid} and $text->{msgid} eq 'abcd') {
            push @$abcd, $text;
          }
        }
        is 0+@$abcd, 1;
        is $abcd->[0]->{langs}->{en}->{body_0}, 'ABCD';
      } $c, name => 'imported data';
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 6, name => 'import';

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
      return POST ($c, ['r', $url, 'acl.json'], params => {
        operation => 'join',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'get access';
      return POST ($c, ['r', $url, 'master', '/', 'import.json'], params => {
        from => 'file',
        format => 'po',
        lang => 'en',
      }, files => {
        file => {
          ref => \q{msgid ""
msgstr ""

msgid "abcd"
msgstr "ABCD"},
        },
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'imported (en)';
      return POST ($c, ['r', $url, 'master', '/', 'import.json'], params => {
        from => 'file',
        format => 'po',
        lang => 'fr',
      }, files => {
        file => {
          ref => \q{msgid ""
msgstr ""

msgid "abcd"
msgstr "XYZW"},
        },
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'imported (fr)';
      return GET ($c, ['r', $url, 'master', '/', 'data.json'], params => {
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      my $json = json_bytes2perl $res->content;
      test {
        my $abcd = [];
        for my $text_id (keys %{$json->{texts}}) {
          my $text = $json->{texts}->{$text_id};
          if (defined $text->{msgid} and $text->{msgid} eq 'abcd') {
            push @$abcd, $text;
          }
        }
        is 0+@$abcd, 1;
        is $abcd->[0]->{langs}->{en}->{body_0}, 'ABCD';
        is $abcd->[0]->{langs}->{fr}->{body_0}, 'XYZW';
        is $json->{langs}->{en}->{key}, 'en';
        is $json->{langs}->{fr}->{key}, 'fr';
      } $c, name => 'imported data';
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 8, name => 'import / multiple langs';

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
      return POST ($c, ['r', $url, 'acl.json'], params => {
        operation => 'join',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'get access';
      return POST ($c, ['r', $url, 'master', '/', 'import.json'], params => {
        from => 'file',
        format => 'po',
        lang => 'en',
      }, files => {
        file => [{
          ref => \q{msgid ""
msgstr ""

msgid "abcd"
msgstr "ABCD"

msgid "abcd2"
msgstr "ABCD2"},
        },
        {
          ref => \q{msgid ""
msgstr ""

msgid "abcd"
msgstr "XYZW"},
        }],
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
      } $c, name => 'imported (fr)';
      return GET ($c, ['r', $url, 'master', '/', 'data.json'], params => {
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      my $json = json_bytes2perl $res->content;
      test {
        my $abcd = [];
        my $abcd2 = [];
        for my $text_id (keys %{$json->{texts}}) {
          my $text = $json->{texts}->{$text_id};
          if (defined $text->{msgid} and $text->{msgid} eq 'abcd') {
            push @$abcd, $text;
          }
          if (defined $text->{msgid} and $text->{msgid} eq 'abcd2') {
            push @$abcd2, $text;
          }
        }
        is 0+@$abcd, 1;
        is 0+@$abcd2, 1;
        is $abcd->[0]->{langs}->{en}->{body_0}, 'XYZW';
        is $abcd2->[0]->{langs}->{en}->{body_0}, 'ABCD2';
        is $json->{langs}->{en}->{key}, 'en';
      } $c, name => 'imported data';
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 7, name => 'import / multiple files';

run_tests;
stop_servers;
