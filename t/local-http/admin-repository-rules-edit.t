use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;
use File::Temp;
use Promised::Timer;

my $wait = web_server;

test {
  my $c = shift;
  my $temp_dir = File::Temp->newdir;
  return login ($c, admin => 1)->then (sub {
    my $account = $_[0];
    return POST ($c, q</admin/repository-rules.json>, account => $account, params => {
      json => perl2json_chars {rules => [undef, 'hoge', [], {}, {prefix => ''}, {
        prefix => q<file://myfiles/>,
        canonical_prefix => qq<$temp_dir/>,
        repository_type => q<file-public>,
      }]},
    })->then (sub {
      return Promised::Timer->timeout (2);
    })->then (sub {
      my @p;

      push @p, POST ($c, qq</tr/file:%2F%2Fmyfiles%2Fnotfound/acl.json>, params => {
        operation => 'join',
      }, account => $account)->then (sub {
        my $res = $_[0];
        test {
          is $res->code, 404;
        } $c, name => 'repository not found';
      })->then (sub {
        return GET ($c, q</tr/file:%2F%2Fmyfiles%2Fnotfound/>, account => $account);
      })->then (sub {
        my $res = $_[0];
        test {
          is $res->code, 404;
          like $res->content, qr{</html>};
        } $c, name => 'repository not found';
      });

      push @p, git_repo ("$temp_dir/repo1", script => q{
        echo hoge > hoge
        git add hoge
        git commit -m "new"
      })->then (sub {
        return POST ($c, qq</tr/file:%2F%2Fmyfiles%2Frepo1/acl.json>, params => {
          operation => 'join',
        }, account => $account);
      })->then (sub {
        my $res = $_[0];
        test {
          is $res->code, 200;
        } $c, name => 'repository found';
      })->then (sub {
        return GET ($c, qq</tr/file:%2F%2Fmyfiles%2Frepo1/>);
      })->then (sub {
        my $res = $_[0];
        test {
          is $res->code, 200;
          like $res->content, qr{</html>};
        } $c, name => 'repository found';
      });

      return Promise->all (\@p)->then (sub {
        done $c;
        undef $c;
        undef $temp_dir;
      });
    });
  });
} wait => $wait, n => 6;

run_tests;
stop_servers;
