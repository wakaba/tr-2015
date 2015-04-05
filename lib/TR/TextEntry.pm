package TR::TextEntry;
use strict;
use warnings;
use Unicode::UTF8 qw(decode_utf8);

sub is_text_id ($) {
  return $_[0] =~ /\A[0-9a-f]{3,128}\z/;
} # is_text_id

sub _e ($) {
  my $s = $_[0];
  $s =~ s/([\x0D\x0A:\\])/{"\x0D" => "\\r", "\x0A" => "\\n", ":" => "\\C", "\\" => "\\\\"}->{$1}/ge;
  return $s;
} # _e

sub _ue ($) {
  return $_[0] unless $_[0] =~ /\\/;
  my $v = $_[0];
  $v =~ s/\\([nrC\\])/{n => "\x0A", r => "\x0D", "C" => ":", "\\" => "\\"}->{$1}/ge;
  return $v;
} # _ue

sub new_from_text_id_and_source_bytes ($$$) {
  return shift->new_from_text_id_and_source_text ($_[0], decode_utf8 $_[1]);
} # new_from_text_id_and_source_bytes

sub new_from_text_id_and_source_text ($$$) {
  my ($class, $id, $text) = @_;
  my $self = bless {text_id => $id}, $class;
  my $props = $self->{props} = {};
  my $enum_props = $self->{enum_props} = {};
  my $list_props = $self->{list_props} = {};
  $text =~ s/\x0D\x0A/\x0A/g;
  for (split /\x0A/, $text) {
    if (/\A\$([^:]+):(.*)\z/) {
      my ($n, $v) = ($1, $2);
      $props->{_ue $n} = _ue $v;
    } elsif (/\A&([^:]+):(.*)\z/) {
      my ($n, $v) = ($1, $2);
      $enum_props->{_ue $n}->{_ue $v} = 1;
    } elsif (/\A\@([^:]+):(.*)\z/) {
      my ($n, $v) = ($1, $2);
      push @{$list_props->{_ue $n} ||= []}, _ue $v;
    }
  }
  return $self;
} # new_from_text_id_and_source_text

sub text_id ($) {
  return $_[0]->{text_id};
} # text_id

sub get ($$) {
  return $_[0]->{props}->{$_[1]}; # or undef
} # get

sub set ($$$) {
  if (defined $_[2]) {
    $_[0]->{props}->{$_[1]} = $_[2];
  } else {
    delete $_[0]->{props}->{$_[1]};
  }
} # set

sub set_or_delete ($$$) {
  if (defined $_[2] and length $_[2]) {
    $_[0]->{props}->{$_[1]} = $_[2];
  } else {
    delete $_[0]->{props}->{$_[1]};
  }
} # set_or_delete

sub enum ($$) {
  return $_[0]->{enum_props}->{$_[1]} ||= {};
} # enum

sub list ($$) {
  return $_[0]->{list_props}->{$_[1]} ||= [];
} # list

sub as_source_text ($) {
  my $self = $_[0];
  my $props = $self->{props};
  my @s;
  for (sort { $a cmp $b } keys %$props) {
    my $s = '$' . (_e $_) . ':' . _e $props->{$_};
    push @s, $s;
  }
  my $enum_props = $self->{enum_props};
  for my $key (sort { $a cmp $b } keys %$enum_props) {
    for (sort { $a cmp $b } grep { $enum_props->{$key}->{$_} } keys %{$enum_props->{$key}}) {
      my $s = '&' . (_e $key) . ':' . _e $_;
      push @s, $s;
    }
  }
  my $list_props = $self->{list_props};
  for my $key (sort { $a cmp $b } keys %$list_props) {
    for my $item (@{$list_props->{$key}}) {
      my $s = '@' . (_e $key) . ':' . _e $item;
      push @s, $s;
    }
  }
  return join "\x0A", @s;
} # as_source_text

sub as_jsonalizable ($) {
  my $self = $_[0];
  my $json = {%{$self->{props}}};
  for my $key (keys %{$self->{enum_props}}) {
    $json->{$key} = [sort { $a cmp $b } grep { $self->{enum_props}->{$key}->{$_} } keys %{$self->{enum_props}->{$key}}];
  }
  for my $key (keys %{$self->{list_props}}) {
    $json->{$key} = $self->{list_props}->{$key};
  }
  delete $json->{tags} if defined $json->{tags} and not 'ARRAY' eq ref $json->{tags};
  delete $json->{args} if defined $json->{args} and not 'ARRAY' eq ref $json->{args};
  return $json;
} # as_jsonalizable

1;

=head1 Q & A

=over 4

=item Why don't you just use JSON?

It could be difficult to manually merge conflicting branches.

=back

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
