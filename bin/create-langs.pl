use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = {};

{
  my $path = path (__FILE__)->parent->parent->child ('local/locale-names.json');
  my $json = json_bytes2perl $path->slurp;

  my $scores = {};
  for my $tag (keys %{$json->{tags}}) {
    my $d = $json->{tags}->{$tag};
    my $t = $json->{countryless_tags}->{lc $d->{bcp47_canonical}} // lc $d->{bcp47_canonical};
    $d->{$_} && $scores->{$t}++ for qw(chrome_web_store firefox facebook
                                       mysql ms java);
  }
  for my $tag (keys %{$json->{tags}}) {
    next unless ($scores->{$tag} || 0) >= 2 or {qw(
      ja-jp-kansai 1 ja-latn 1 ja-child 1
      zh-hant 1 zh-hans 1
    )}->{$tag};
    next if {qw(no 1)}->{$tag};
    next if $json->{countryless_tags}->{$tag};
    my $d = $json->{tags}->{$tag};
    next unless $tag eq lc $d->{bcp47_canonical};

    $d->{native_name} =~ s/\)/)\x{200F}/g if defined $d->{native_name}; # RLM
    $Data->{langs}->{$tag}->{label} = $d->{native_name} // $tag;
    $Data->{langs}->{$tag}->{label_short} = $d->{bcp47_canonical};
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('local/plural-forms.json');
  $Data->{plural_forms} = json_bytes2perl $path->slurp;
}

print perl2json_bytes_for_record $Data;

