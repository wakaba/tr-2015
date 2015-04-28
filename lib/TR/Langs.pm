package TR::Langs;
use strict;
use warnings;

## See also: tr.texts.langs.html.tm
sub is_lang_key ($) {
  return $_[0] =~ /\A[a-z0-9][a-z0-9-]{0,63}\z/;
} # is_lang_key

1;
