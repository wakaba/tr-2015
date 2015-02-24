# -*- perl -*-
use strict;
use warnings;
use TR::Web;

$ENV{LANG} = 'C';
$ENV{TZ} = 'UTC';

my $config = {
  #XXX
  #web_origin => 'http://localhost:5000',
};

#XXX
use Path::Tiny;
use MIME::Base64;
my $key_path = path (__FILE__)->parent->parent->child ('local/keys/devel');
$config->{es_url_prefix} = decode_base64 $key_path->child ('es-url-prefix.txt')->slurp;
$config->{es_user} = decode_base64 $key_path->child ('es-user.txt')->slurp;
$config->{es_password} = decode_base64 $key_path->child ('es-password.txt')->slurp;

return TR::Web->psgi_app ($config);

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
