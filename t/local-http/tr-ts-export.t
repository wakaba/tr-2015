use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;
use Encode;

my $wait = web_server;

# XXX repo not found tests
# XXX permission tests

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
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'master', '/', 'export'], params => {
        lang => 'en',
        format => 'hoge-fuga',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 400;
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 1, name => 'empty - unknown format';

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
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'master', '/', 'export'], params => {
        lang => 'en',
        format => 'po',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        is $res->header ('Content-Type'), q{text/x-po; charset=utf-8};
        is $res->header ('Content-Disposition'), q{attachment; filename="en.po"};
        like $res->content, qr{MIME-Version: 1.0};
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 4, name => 'empty - .po';

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
      return grant_scopes ($c, $url, $account, ['edit', 'texts']);
    })->then (sub {
      return POST ($c, ['r', $url, 'master', '/', 'i', $text_id, 'meta.json'], params => {
        msgid => "\x{6001}\x00ho ge",
      }, account => $account);
    })->then (sub {
      return POST ($c, ['r', $url, 'master', '/', 'i', $text_id, 'text.json'], params => {
        lang => 'en',
        body_0 => "abc xy\x{6000}\x00",
      }, account => $account);
    })->then (sub {
      return GET ($c, ['r', $url, 'master', '/', 'export'], params => {
        lang => 'en',
        format => 'po',
      }, account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        is $res->header ('Content-Type'), q{text/x-po; charset=utf-8};
        is $res->header ('Content-Disposition'), q{attachment; filename="en.po"};
        like $res->content, qr{\Q@{[encode 'utf-8', qq{msgid "\x{6001}\x00ho ge"
msgstr "abc xy\x{6000}\x00"}]}\E};
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 4, name => 'non-empty - .po';

run_tests;
stop_servers;
