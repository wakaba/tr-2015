# -*- perl -*-
use strict;
use warnings;
use TR::Web;

my $config = {
  #XXX
  #web_origin => 'http://localhost:5000',
};

return TR::Web->psgi_app ($config);

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
