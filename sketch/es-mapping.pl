use strict;
use warnings;

my $config = {};
#XXX
use Path::Tiny;
use MIME::Base64;
my $key_path = path (__FILE__)->parent->parent->child ('local/keys/devel');
$config->{es_url_prefix} = decode_base64 $key_path->child ('es-url-prefix.txt')->slurp;
$config->{es_user} = decode_base64 $key_path->child ('es-user.txt')->slurp;
$config->{es_password} = decode_base64 $key_path->child ('es-password.txt')->slurp;

use AnyEvent;
use JSON::PS;
use Web::UserAgent::Functions qw(http_post_data);
my $cv = AE::cv;

      my $prefix = $config->{es_url_prefix};
      my $auth = [$config->{es_user},
                  $config->{es_password}];
      http_post_data
          override_method => 'PUT',
          url => qq<$prefix/_mapping/texts>,
          basic_auth => $auth,
          anyevent => 1,
          content => (perl2json_bytes {texts => {
            _id => {path => 'text_id'},
          }}),
          cb => sub {
            my (undef, $res) = @_;
            $cv->send;
          };
$cv->recv;
