# -*- perl -*-
use strict;
use warnings;
use AnyEvent;
use TR::Config;
use TR::Web;

$ENV{LANG} = 'C';
$ENV{TZ} = 'UTC';

my $config_file_name = $ENV{APP_CONFIG}
    // die "Usage: APP_CONFIG=config.json ./plackup bin/server.psgi";
my $cv = AE::cv;
TR::Config->from_file_name ($config_file_name)->then (sub {
  $cv->send ($_[0]);
}, sub {
  $cv->croak ($_[0]);
});
my $config = $cv->recv;


#XXX
use Path::Tiny;
use MIME::Base64;
my $key_path = path (__FILE__)->parent->parent->child ('local/keys/devel');
$config->{es_url_prefix} = decode_base64 $key_path->child ('es-url-prefix.txt')->slurp;
$config->{es_user} = decode_base64 $key_path->child ('es-user.txt')->slurp;
$config->{es_password} = decode_base64 $key_path->child ('es-password.txt')->slurp;

$config->{account_url_prefix} = decode_base64 $key_path->child ('account-url-prefix.txt')->slurp;
$config->{account_token} = decode_base64 $key_path->child ('account-token.txt')->slurp;
$config->{account_sk_context} = 'tr';

$config->{mongolab_api_key} = decode_base64 $key_path->child ('mongolab-api-key.txt')->slurp;

return TR::Web->psgi_app ($config);

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
