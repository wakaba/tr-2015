package Tests;
use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use File::Temp;
use AnyEvent;
use Promise;
use Promised::File;
use Promised::Plackup;
use Promised::Mysqld;
use Promised::Docker::WebDriver;
use MIME::Base64;
use JSON::PS;
use Web::UserAgent::Functions qw(http_get http_post);

our @EXPORT;

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

sub account_server () {
  $AccountServer = Promised::Plackup->new;
  $AccountServer->plackup ($root_path->child ('plackup'));
  $AccountServer->envs->{API_TOKEN} = rand;
  $AccountServer->set_option ('--server' => 'Twiggy::Prefork');
  $AccountServer->set_app_code (q{
    use Wanage::HTTP;
    use Wanage::URL;
    use AnyEvent;
    use Web::UserAgent::Functions qw(http_post);
    use JSON::PS;
    use MIME::Base64;
    my $api_token = $ENV{API_TOKEN};
    sub {
      my $env = shift;
      my $http = Wanage::HTTP->new_from_psgi_env ($env);
      my $path = $http->url->{path};
      if ($http->request_method ne 'POST') {
        $http->set_status (405);
      } elsif ($path eq '/session') {
        my $json = {};
        $json->{sk} = rand;
        $json->{sk_expires} = time + 1000;
        unless ($http->query_params->{sk}->[0]) {
          $json->{set_sk} = 1;
        }
        $http->send_response_body_as_ref (\perl2json_bytes $json);
      } elsif ($path eq '/login') {
        my $json = {};
        my $server = $http->request_body_params->{server}->[0];
        $json->{authorization_url} = qq<http://$server/auth>;
        $http->send_response_body_as_ref (\perl2json_bytes $json);
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
  my $bearer = rand;
  $MySQLServer = Promised::Mysqld->new;
  Promise->all ([
    $MySQLServer->start,
    account_server,
  ])->then (sub {
    my $dsn = $MySQLServer->get_dsn_string (dbname => 'tr_test');
    $MySQLServer->{_temp} = my $temp = File::Temp->newdir;
    my $temp_dir_path = path ($temp)->absolute;
    my $temp_path = $temp_dir_path->child ('file');
    my $temp_file = Promised::File->new_from_path ($temp_path);
    $HTTPServer = Promised::Plackup->new;
    $HTTPServer->envs->{APP_CONFIG} = $temp_path;
    return Promise->all ([
      db_sqls->then (sub {
        $MySQLServer->create_db_and_execute_sqls (tr_test => $_[0]);
      }),
      $temp_file->write_byte_string (perl2json_bytes +{
        alt_dsns => {master => {account => $dsn}},
        #dsns => {account => $dsn},

        'account.url_prefix' => 'http://' . $AccountServer->get_host,
        'account.token' => $AccountServer->envs->{API_TOKEN},
        'account.sk_context'=> rand,

        'cookie.domain' => $web_host // '127.0.0.1',
        'cookie.secure' => 0,
      }),
    ]);
  })->then (sub {
    $HTTPServer->plackup ($root_path->child ('plackup'));
    $HTTPServer->set_option ('--host' => $web_host) if defined $web_host;
    $HTTPServer->set_option ('--app' => $root_path->child ('bin/server.psgi'));
    $HTTPServer->set_option ('--server' => 'Twiggy::Prefork');
    return $HTTPServer->start;
  })->then (sub {
    $cv->send ({host => $HTTPServer->get_host, hostname => $HTTPServer->get_hostname});
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

1;
