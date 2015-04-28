use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = {};

{
  my $path = path (__FILE__)->parent->parent->child ('local/plurals.json');
  my $json = json_bytes2perl $path->slurp;
  
  my $key_to_form_id = {'everything else' => 0};
  my $form_id = 1;
  my $form_defs = [{
    label => 'everything else',
    label_short => 'else',
  }];
  for my $key (sort { $a cmp $b } keys %{$json->{forms}}) {
    my $d = $json->{forms}->{$key};
    my @value = split / /, $d->{examples};
    my $data = {
      label => (join ', ', grep { defined } @value[0..4], (@value > 5 ? '...' : undef)),
      label_short => $d->{typical},
    };
    push @$form_defs, $data;
    $key_to_form_id->{$key} = $form_id++;
  }
  {
    my $path = path (__FILE__)->parent->parent->child ('local/plural-forms.json');
    $path->spew (perl2json_bytes_for_record $form_defs);
  }

  my @default_list;
  my @common_list;
  my @uncommon_list;
  for my $key (keys %{$json->{rules}}) {
    my $d = $json->{rules}->{$key};
    my $expr = $d->{expression};
    my $data = {};
    my $score = (keys %{$d->{cldr_locales}->{cardinal} or {}})
              + (keys %{$d->{cldr_locales}->{ordinal} or {}});
    my $count = @{$d->{forms}};
    my $label = $key;
    $label =~ s/^[0-9]+://;
    $label = join ' / ', map {
      join ', ', map {
        s/ excluding .+$//;
        s/ not ends in .+$//;
        s/everything else/else/;
        s/^is //;
        s{^ends in ([0-9, -]+)$}{
          my $v = $1;
          $v =~ s/([0-9]+)/x$1/g;
          $v;
        }e;
        $_;
      } split / or /, $_;
    } split m{/}, $label;
    my $forms = join ',', map { $key_to_form_id->{$_} } @{$d->{forms}};
    my $option = {
      label => $label,
      value => $expr,
      #form_count => $count,
      form_fields => $forms,
    };
    if ($count == 1) {
      push @default_list, [$option, $score];
    } elsif ($score > 2) {
      push @common_list, [$option, $score];
    } else {
      push @uncommon_list, [$option, $key];
    }
  }
  $Data->{rule_list_1} = [map { $_->[0] } @default_list, sort { $b->[1] <=> $a->[1] } @common_list];
  $Data->{rule_list_2} = [map { $_->[0] } sort { $a->[1] cmp $b->[1] } @uncommon_list];
}

print perl2json_bytes_for_record $Data;
