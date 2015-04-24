package Tests;
use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use File::Temp;
use AnyEvent;
use Promise;
use Promised::File;
use Promised::Command;
use Promised::Plackup;
use Promised::Mysqld;
use Promised::Docker::WebDriver;
use MIME::Base64;
use Digest::SHA qw(sha1_hex);
use JSON::PS;
use Web::UserAgent::Functions qw(http_get http_post);
use Wanage::URL qw(percent_encode_c);
use Test::More;
use Test::Differences;
use Test::X1;

our @EXPORT;

push @EXPORT, grep { not /^\$/ } @Test::More::EXPORT;
push @EXPORT, @Test::Differences::EXPORT;
push @EXPORT, @Test::X1::EXPORT;
push @EXPORT, @JSON::PS::EXPORT;

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or die qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

my $MySQLServer;
my $HTTPServer;
my $AccountServer;
my $Browsers = {};

my $root_path = path (__FILE__)->parent->parent->parent->absolute;

sub db_sqls () {
  my $file = Promised::File->new_from_path
      ($root_path->child ('db/tr.sql'));
  return $file->read_byte_string->then (sub {
    return [split /;/, $_[0]];
  });
} # db_sqls

push @EXPORT, qw(git_repo);
sub git_repo ($%) {
  my ($repo_dir_name, %args) = @_;
  my $dir_name = File::Temp->newdir;
  return Promised::File->new_from_path ($repo_dir_name)->mkpath->then (sub {
    my $cmd = Promised::Command->new (['git', 'init', '--bare']);
    $cmd->wd ($repo_dir_name);
    return $cmd->run->then (sub {
      return $cmd->wait;
    })->then (sub {
      die $_[0] unless $_[0]->exit_code == 0;
    });
  })->then (sub {
    return Promised::File->new_from_path ($dir_name)->mkpath;
  })->then (sub {
    my $cmd = Promised::Command->new (['git', 'clone', $repo_dir_name, $dir_name]);
    $cmd->wd ($dir_name);
    return $cmd->run->then (sub {
      return $cmd->wait;
    })->then (sub {
      die $_[0] unless $_[0]->exit_code == 0;
    });
  })->then (sub {
    my $files = $args{files} || {};
    return unless keys %$files;
    my @p;
    my $dir_path = path ($dir_name);
    for my $file_name (keys %$files) {
      push @p, Promised::File->new_from_path ($dir_path->child ($file_name))->write_byte_string ($files->{$file_name});
    }
    return Promise->all (\@p)->then (sub {
      my $cmd = Promised::Command->new (['git', 'add', '.']);
      $cmd->wd ($dir_name);
      return $cmd->run->then (sub {
        return $cmd->wait;
      })->then (sub {
        die $_[0] unless $_[0]->exit_code == 0;
      });
    })->then (sub {
      my $cmd = Promised::Command->new (['git', 'commit', '-m', 'Initial']);
      $cmd->wd ($dir_name);
      return $cmd->run->then (sub {
        return $cmd->wait;
      })->then (sub {
        die $_[0] unless $_[0]->exit_code == 0;
      });
    });
  })->then (sub {
    return unless defined $args{script};
    my $script_path = path ($dir_name)->child ('script');
    return Promised::File->new_from_path ($script_path)->write_char_string ($args{script})->then (sub {
      my $cmd = Promised::Command->new (['bash', $script_path]);
      $cmd->wd ($dir_name);
      return $cmd->run->then (sub {
        return $cmd->wait;
      })->then (sub {
        die $_[0] unless $_[0]->exit_code == 0;
      });
    });
  })->then (sub {
    my $cmd = Promised::Command->new (['git', 'push', 'origin', 'master']);
    $cmd->wd ($dir_name);
    return $cmd->run->then (sub {
      return $cmd->wait;
    })->then (sub {
      die $_[0] unless $_[0]->exit_code == 0;
    });
  })->then (sub {
    my $cmd = Promised::Command->new (['git', 'rev-parse', 'HEAD']);
    $cmd->wd ($dir_name);
    $cmd->stdout (\my $stdout);
    return $cmd->run->then (sub {
      return $cmd->wait;
    })->then (sub {
      die $_[0] unless $_[0]->exit_code == 0;
    })->then (sub { undef $dir_name; return $stdout });
  });
} # git_repo

push @EXPORT, qw(git_rev);
sub git_rev ($) {
  my $dir_name = $_[0];
  my $cmd = Promised::Command->new (['git', 'rev-parse', 'HEAD']);
  $cmd->wd ($dir_name);
  $cmd->stdout (\my $stdout);
  return $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    die $_[0] unless $_[0]->exit_code == 0;
  })->then (sub { return $stdout });
} # git_rev

push @EXPORT, qw(file_from_git_repo);
sub file_from_git_repo ($$;%) {
  my ($dir_name, $file_name, %args) = @_;
  my $cmd = Promised::Command->new ([
    'perl',
    path (__FILE__)->parent->parent->parent->child ('bin/git-show-file.pl'),
    $dir_name, 'master', $file_name,
  ]);
  $cmd->stdout (\my $stdout);
  return $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    die $_[0] unless $_[0]->exit_code == 0;
  })->then (sub {
    return $stdout;
  });
} # file_from_git_repo

sub account_server () {
  $AccountServer = Promised::Plackup->new;
  $AccountServer->plackup ($root_path->child ('plackup'));
  $AccountServer->envs->{API_TOKEN} = rand;
  $AccountServer->set_option ('--server' => 'Twiggy');
  $AccountServer->set_app_code (q{
    use Wanage::HTTP;
    use Wanage::URL;
    use AnyEvent;
    use Web::UserAgent::Functions qw(http_post);
    use JSON::PS;
    use MIME::Base64;
    my $api_token = $ENV{API_TOKEN};
    my $Sessions = {};
    sub {
      my $env = shift;
      my $http = Wanage::HTTP->new_from_psgi_env ($env);
      my $path = $http->url->{path};
      if ($http->request_method ne 'POST') {
        $http->set_status (405);
      } elsif ($path eq '/session') {
        my $json = {};
        my $session = $Sessions->{$http->request_body_params->{sk}->[0] // ''};
        unless (defined $session) {
          $json->{set_sk} = 1;
          $session = {sk => rand, expires => time + 1000};
          $Sessions->{$session->{sk}} = $session;
        }
        $json->{sk} = $session->{sk};
        $json->{sk_expires} = $session->{expires};
        $http->send_response_body_as_ref (\perl2json_bytes $json);
      } elsif ($path eq '/login') {
        my $json = {};
        my $server = $http->request_body_params->{server}->[0];
        $json->{authorization_url} = qq<http://$server/auth>;
        $http->send_response_body_as_ref (\perl2json_bytes $json);
      } elsif ($path eq '/info') {
        my $json = {};
        my $session = $Sessions->{$http->request_body_params->{sk}->[0] // ''};
        if (defined $session) {
          $json->{account_id} = $session->{account_id};
          $json->{name} = $session->{name};
        }
        $http->send_response_body_as_ref (\perl2json_bytes $json);
      } elsif ($path eq '/profiles') {
        my $json = {};
        my %account_id = map { $_ => 1 } @{$http->request_body_params->{account_id}};
        $json->{accounts}->{$_->{account_id}} = $_
            for grep { $account_id{$_->{account_id}} } values %$Sessions;
        $http->send_response_body_as_ref (\perl2json_bytes $json);

      } elsif ($path eq '/-add-session') {
        my $sk = rand;
        $Sessions->{$sk} = {
          sk => $sk,
          expires => time + 1000,
          account_id => (sprintf '%llu', int (2**63 + rand (2**62))),
          name => rand,
        };
        $http->set_status (201);
        $http->send_response_body_as_ref (\perl2json_bytes $Sessions->{$sk});
      } else {
        $http->set_status (404);
      }
      $http->close_response_body;
      return $http->send_response;
    };
  });
  return $AccountServer->start;
} # account_server

push @EXPORT, qw(web_server);
sub web_server (;$) {
  my $web_host = $_[0];
  my $cv = AE::cv;
  my $admin_token = rand;
  $MySQLServer = Promised::Mysqld->new;
  $MySQLServer->{_temp} = my $temp = File::Temp->newdir;
  my $temp_dir_path = path ($temp)->absolute;
  my $temp_path = $temp_dir_path->child ('file');
  my $temp_repos_path = $temp_dir_path->child ('repos');
  my $temp_file = Promised::File->new_from_path ($temp_path);
  my $repo_rules = {rules => [
    {
      prefix => q<file:///pub/>,
      mapped_prefix => $temp_repos_path->child ('pub') . '/',
      repository_type => 'file-public',
    },
  ]};
  Promise->all ([
    $MySQLServer->start,
    account_server,
    git_repo ($temp_repos_path->child ('siteadmin'), files => {
      'repository-rules.json' => (perl2json_bytes $repo_rules),
    }),
  ])->then (sub {
    my $dsn = $MySQLServer->get_dsn_string (dbname => 'tr_test');
    $HTTPServer = Promised::Plackup->new;
    $HTTPServer->envs->{APP_CONFIG} = $temp_path;
    return Promise->all ([
      db_sqls->then (sub {
        $MySQLServer->create_db_and_execute_sqls (tr_test => $_[0]);
      }),
      $temp_file->write_byte_string (perl2json_bytes +{
        alt_dsns => {master => {tr => $dsn}},
        dsns => {tr => $dsn},

        'account.url_prefix' => 'http://' . $AccountServer->get_host,
        'account.token' => $AccountServer->envs->{API_TOKEN},
        'account.sk_context'=> rand,

        'cookie.domain' => $web_host // '127.0.0.1',
        'cookie.secure' => 0,

        'admin.token' => $admin_token,
        'admin.repository' => $temp_repos_path->child ('siteadmin'),

        'repos.mirror' => $temp_dir_path->child ('mirror'),
      }),
    ]);
  })->then (sub {
    $HTTPServer->plackup ($root_path->child ('plackup'));
    $HTTPServer->set_option ('--host' => $web_host) if defined $web_host;
    $HTTPServer->set_option ('--app' => $root_path->child ('bin/server.psgi'));
    $HTTPServer->set_option ('--server' => 'Twiggy::Prefork');
    return $HTTPServer->start;
  })->then (sub {
    $cv->send ({host => $HTTPServer->get_host,
                hostname => $HTTPServer->get_hostname,
                account_host => $AccountServer->get_host,
                admin_token => $admin_token,
                repos_path => $temp_repos_path});
  });
  return $cv;
} # web_server

push @EXPORT, qw(stop_servers);
sub stop_servers () {
  my $cv = AE::cv;
  $cv->begin;
  for ($HTTPServer, $MySQLServer, $AccountServer, values %$Browsers) {
    next unless defined $_;
    $cv->begin;
    $_->stop->then (sub { $cv->end });
  }
  $cv->end;
  $cv->recv;
} # stop_servers

push @EXPORT, qw(GET);
sub GET ($$;%) {
  my ($c, $path, %args) = @_;
  my $host = $c->received_data->{host};
  $path = '/' . join '/', map { percent_encode_c $_ } @$path if ref $path;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $cookies = $args{cookies} || {};
    $cookies->{sk} //= $args{account}->{sk}; # or undef
    http_get
        url => qq<http://$host$path>,
        basic_auth => $args{basic_auth},
        header_fields => $args{header_fields},
        params => $args{params},
        cookies => $cookies,
        timeout => 30,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  });
} # GET

push @EXPORT, qw(POST);
sub POST ($$;%) {
  my ($c, $path, %args) = @_;
  my $host = $c->received_data->{host};
  $path = '/' . join '/', map { percent_encode_c $_ } @$path if ref $path;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $cookies = $args{cookies} || {};
    $cookies->{sk} //= $args{account}->{sk}; # or undef
    http_post
        url => qq<http://$host$path>,
        basic_auth => $args{basic_auth},
        header_fields => $args{header_fields},
        params => $args{params},
        files => $args{files},
        cookies => $cookies,
        timeout => 30,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  });
} # POST

push @EXPORT, qw(login);
sub login ($;%) {
  my ($c, %args) = @_;
  my $host = $c->received_data->{account_host};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => qq<http://$host/-add-session>,
        anyevent => 1,
        max_redirect => 0,
        cb => sub {
          $ok->($_[1]);
        };
  })->then (sub {
    my $res = $_[0];
    my $user = {};
    test {
      is $res->code, 201, 'status code' unless $res->code == 201;
      $user = json_bytes2perl $res->content;
      is ref $user, 'HASH' unless ref $user eq 'HASH';
    } $c, name => '//account/-add-session';
    if ($args{admin}) {
      return POST ($c, q</admin/account>,
        basic_auth => ['admin', $c->received_data->{admin_token}],
        account => $user,
      )->then (sub { return $user });
    } else {
      return $user;
    }
  });
} # login

push @EXPORT, qw(new_text_id);
sub new_text_id () {
  return sha1_hex (time () . $$ . rand ());
} # new_text_id

1;
