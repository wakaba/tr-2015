package TR::TextEntry;
use strict;
use warnings;

sub new_from_text_id_and_source_text ($$$) {
  my ($class, $id, $text) = @_;
  my $self = bless {text_id => $id}, $class;
  my $props = $self->{props} = {};
  my $enum_props = $self->{enum_props} = {};
  $text =~ s/\x0D\x0A/\x0A/g;
  for (split /\x0A/, $text) {
    if (/\A\$([0-9A-Za-z_]+):(.*)\z/) {
      my ($n, $v) = ($1, $2);
      $v =~ s/\\([nr\\])/{n => "\x0A", r => "\x0D", "\\" => "\\"}->{$1}/ge;
      $props->{$n} = $v;
    } elsif (/\A&([0-9A-Za-z_]+):(.*)\z/) {
      my ($n, $v) = ($1, $2);
      $v =~ s/\\([nr\\])/{n => "\x0A", r => "\x0D", "\\" => "\\"}->{$1}/ge;
      $enum_props->{$n}->{$v} = 1;
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

sub enum ($$) {
  return $_[0]->{enum_props}->{$_[1]} ||= {};
} # enum

sub as_source_text ($) {
  my $self = $_[0];
  my $props = $self->{props};
  my @s;
  for (sort { $a cmp $b } keys %$props) {
    my $s = '$' . $_ . ':' . $props->{$_};
    $s =~ s/([\x0D\x0A\\])/{"\x0D" => "\\r", "\x0A" => "\\n", "\\" => "\\\\"}->{$1}/ge;
    push @s, $s;
  }
  my $enum_props = $self->{enum_props};
  for my $key (sort { $a cmp $b } keys %$enum_props) {
    for (sort { $a cmp $b } grep { $enum_props->{$key}->{$_} } keys %{$enum_props->{$key}}) {
      my $s = '&' . $key . ':' . $_;
      $s =~ s/([\x0D\x0A\\])/{"\x0D" => "\\r", "\x0A" => "\\n", "\\" => "\\\\"}->{$1}/ge;
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
