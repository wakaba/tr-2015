use strict;
use warnings;
use JSON::Functions::XS qw(json_bytes2perl perl2json_bytes);

sub entry_is_blob ($) {
  my $entry = $_[0];
  return (defined $entry and
          $entry->object->is_blob and
          not $entry->file_mode & 020000); # symlink
} # entry_is_blob

sub get_texts_tree ($$) {
  my ($git_branch, $texts_dir) = @_;
  my $root_tree = $git_branch->is_tree ? $git_branch : $git_branch->target->tree;
  my $texts_tree = $root_tree;
  if (defined $texts_dir) {
    my $texts_entry = $root_tree->entry_bypath ($texts_dir);
    if (defined $texts_entry and $texts_entry->object->is_tree) {
      $texts_tree = $texts_entry->object;
    } else {
      $texts_tree = undef;
    }
  }
  return $texts_tree;
} # get_texts_tree

sub get_texts_config ($) {
  my $texts_tree = $_[0]; # or undef
  my $config = {};
  if (defined $texts_tree) {
    my $config_entry = $texts_tree->entry_bypath ('texts/config.json');
    if (entry_is_blob $config_entry) {
      $config = json_bytes2perl $config_entry->object->content;
      $config = {} if defined $config and not ref $config eq 'HASH';
    }
  }
  return $config;
} # get_texts_config

sub print_status ($) {
  print STDOUT perl2json_bytes $_[0];
  print STDOUT "\x0A";
} # print_status

1;
