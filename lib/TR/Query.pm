package TR::Query;
use strict;
use warnings;

sub parse_query ($%) {
  my ($class, %args) = @_;
  my $self = bless {
    text_ids => $args{text_ids} || [],
    msgids => $args{msgids} || [],
    tag_ors => $args{tag_ors} || [],
    tags => $args{tags} || [],
    tag_minuses => $args{tag_minuses} || [],
    words => $args{words} || [],
    equals => $args{equals} || {},
  }, $class;

  my $q = $args{query} // '';
  while (length $q) {
    $q =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
    my $prefix;
    if ($q =~ s/^(text_id|msgid|tag|[-|]tag|\$[0-9a-z-]+)://) {
      $prefix = $1;
    }
    if ($q =~ s/^"((?>[^"\\]|\\.)*)"//s) {
      my $v = $1;
      $v =~ s/\\(.)/$1/g;
      if (not defined $prefix) {
        push @{$self->{words}}, $v;
      } elsif ($prefix eq '-tag') {
        push @{$self->{tag_minuses}}, $v;
      } elsif ($prefix eq '|tag') {
        push @{$self->{tag_ors}}, $v;
      } elsif ($prefix =~ /^\$([0-9a-z-]+)$/) {
        $self->{equals}->{$1} = $v;
      } else {
        push @{$self->{$prefix.'s'}}, $v;
      }
    } elsif ($q =~ s/^([^\x09\x0A\x0C\x0D\x20]*)//) {
      my $v = $1;
      if (not defined $prefix) {
        push @{$self->{words}}, $v if length $v;
      } elsif ($prefix eq '-tag') {
        push @{$self->{tag_minuses}}, $v;
      } elsif ($prefix eq '|tag') {
        push @{$self->{tag_ors}}, $v;
      } elsif ($prefix =~ /^\$([0-9a-z-]+)$/) {
        $self->{equals}->{$1} = $v;
      } else {
        push @{$self->{$prefix.'s'}}, $v;
      }
    }
  }

  return $self;
} # parse_query

sub text_ids ($) { return $_[0]->{text_ids} }
sub msgids ($) { return $_[0]->{msgids} }
sub tag_ors ($) { return $_[0]->{tag_ors} }
sub tags ($) { return $_[0]->{tags} }
sub tag_minuses ($) { return $_[0]->{tag_minuses} }
sub words ($) { return $_[0]->{words} }
sub equals ($) { return $_[0]->{equals} }

sub _s ($) {
  my $s = $_[0];
  if (not length $s or
      $s =~ /[\x09\x0A\x0C\x0D\x20\x22\x5C:]/ or
      $s =~ /^[-|&~!\$%&#\@+*?=]/) {
    $s =~ s/(["\\])/\\$1/g;
    return qq<"$s">;
  } else {
    return $s;
  }
} # _s

sub stringify ($) {
  my $self = shift;
  my @result;
  push @result, '-tag:' . _s $_ for @{$self->{tag_minuses}};
  push @result, '|tag:' . _s $_ for @{$self->{tag_ors}};
  push @result, 'tag:' . _s $_ for @{$self->{tags}};
  push @result, 'text_id:' . _s $_ for @{$self->{text_ids}};
  push @result, 'msgid:' . _s $_ for @{$self->{msgids}};
  for my $l (sort { $a cmp $b } keys %{$self->{equals}}) {
    push @result, '$' . (_s $l) . ':' . _s $self->{equals}->{$l};
  }
  push @result, _s $_ for @{$self->{words}};
  return join ' ', @result;
} # stringify

sub as_jsonalizable ($) {
  my $self = $_[0];
  return {%$self};
} # as_jsonalizable

1;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
