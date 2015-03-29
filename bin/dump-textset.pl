use strict;
use warnings;
use Git::Raw;
use Git::Raw::Branch;
use TR::TextEntry;
use JSON::Functions::XS qw(perl2json_bytes);

my ($git_url, $git_branch, $text_set_path) = @ARGV;
die "Bad args" unless defined $text_set_path;

my $git_repo = Git::Raw::Repository->open ($git_url);
my $branch = Git::Raw::Branch->lookup ($git_repo, $git_branch, 1)
    // die "Branch not found";
my $root_tree = $branch->target->tree;

my $dat_entries = {};
my $txt_entries = {};
my $comments_entries = {};

my $set_parent_entry = length $text_set_path ? $root_tree->entry_bypath ($text_set_path) : $root_tree;
if (defined $set_parent_entry and $set_parent_entry->object->is_tree) {
  my $set_texts_entry = $set_parent_entry->object->entry_byname ('texts');
  if (defined $set_texts_entry and $set_texts_entry->object->is_tree) {
    for my $dir_entry ($set_texts_entry->object->entries) {
      next unless $dir_entry->object->is_tree;
      my $name0 = $dir_entry->name;
      next unless $name0 =~ m{\A[0-9a-f]{2}\z};
      for my $entry ($dir_entry->object->entries) {
        next unless $entry->object->is_blob;
        next if $entry->file_mode & 020000; # symlinks
        my $name = $entry->name;
        next unless $name =~ m{\A([0-9a-f]+)\.([0-9a-z-]+\.txt|dat|comments)\z};
        my $text_id = $name0.$1;
        my $type = $2;
        my $lang;
        if ($type =~ s/\.txt\z//) {
          $lang = $type;
          $type = 'txt';
        }
        if ($type eq 'txt') {
          my $te = TR::TextEntry->new_from_text_id_and_source_bytes
              ($text_id, $entry->object->content);
          $txt_entries->{$text_id}->{$lang} = $te->as_jsonalizable;
        } elsif ($type eq 'dat') {
          my $te = TR::TextEntry->new_from_text_id_and_source_bytes
              ($text_id, $entry->object->content);
          $dat_entries->{$text_id} = $te->as_jsonalizable;
        }
      }
    }
  }
}

my $json = {};

for my $text_id (keys %$dat_entries) {
  $json->{texts}->{$text_id} = $dat_entries->{$text_id};
  $json->{texts}->{$text_id}->{langs} = {};
}
for my $text_id (keys %$txt_entries) {
  $json->{texts}->{$text_id}->{langs} = $txt_entries->{$text_id};
}

print perl2json_bytes $json;
