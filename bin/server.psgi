# -*- perl -*-
use strict;
use warnings;
use TR::Web;

my $config = {
  #XXX
  #web_origin => 'http://localhost:5000',
};

return TR::Web->psgi_app ($config);
