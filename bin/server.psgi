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

if ($config->get ('http.x-forwarded-*')) {
  $Wanage::HTTP::UseXForwardedScheme = 1;
  $Wanage::HTTP::UseXForwardedHost = 1;
  $Wanage::HTTP::UseXForwardedFor = 1;
}

for (qw(WEBUA_DEBUG SQL_DEBUG)) {
  my $value = $config->get ('env.' . $_);
  $ENV{WEBUA_DEBUG} ||= $value if defined $value;
}

return TR::Web->psgi_app ($config);

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
