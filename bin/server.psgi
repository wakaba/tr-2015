# -*- perl -*-
use strict;
use warnings;
use Path::Tiny;
use TR::Config;
use TR::Web;

$ENV{LANG} = 'C';
$ENV{TZ} = 'UTC';

my $config_file_name = $ENV{APP_CONFIG}
    // die "Usage: APP_CONFIG=config.json ./plackup bin/server.psgi";
my $config_path = path ($config_file_name);
my $config = TR::Config->new_from_path ($config_path);
$config->load_siteadmin ($config->get_path ('admin.repository'));

if ($config->get ('http.x-forwarded-*')) {
  $Wanage::HTTP::UseXForwardedScheme = 1;
  $Wanage::HTTP::UseXForwardedHost = 1;
  $Wanage::HTTP::UseXForwardedFor = 1;
}

return TR::Web->psgi_app ($config);

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
