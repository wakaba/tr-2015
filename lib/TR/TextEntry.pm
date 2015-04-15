package TR::TextEntry;
use strict;
use warnings;
use TEON;

sub new_from_source_bytes ($$) {
  return bless TEON->parse_bytes ($_[1]), $_[0];
} # new_from_source_bytes

sub new_from_source_text ($$) {
  return bless TEON->parse_text ($_[1]), $_[0];
} # new_from_source_text

sub get ($$) {
  return $_[0]->{scalars}->{$_[1]}; # or undef
} # get

sub set ($$$) {
  if (defined $_[2]) {
    $_[0]->{scalars}->{$_[1]} = $_[2];
  } else {
    delete $_[0]->{scalars}->{$_[1]};
  }
} # set

sub set_or_delete ($$$) {
  if (defined $_[2] and length $_[2]) {
    $_[0]->{scalars}->{$_[1]} = $_[2];
  } else {
    delete $_[0]->{scalars}->{$_[1]};
  }
} # set_or_delete

sub enum ($$) {
  return $_[0]->{enums}->{$_[1]} ||= {};
} # enum

sub list ($$) {
  return $_[0]->{lists}->{$_[1]} ||= [];
} # list

sub as_source_text ($) {
  return TEON->to_text ($_[0]);
} # as_source_text

sub as_jsonalizable ($) {
  my $self = $_[0];
  my $json = {%{$self->{scalars}}};
  for my $key (keys %{$self->{enums}}) {
    $json->{$key} = [sort { $a cmp $b } grep { $self->{enums}->{$key}->{$_} } keys %{$self->{enums}->{$key}}];
  }
  for my $key (keys %{$self->{lists}}) {
    $json->{$key} = $self->{lists}->{$key};
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

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
