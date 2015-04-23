use strict;
use warnings;
use Git::Raw;
use Git::Raw::Branch;
use Git::Raw::Tree;
use TR::TextEntry;
use JSON::Functions::XS qw(perl2json_bytes);

my ($git_url, $ref_type, $ref, $text_set_path) = @ARGV;
die "Bad args" unless defined $text_set_path;

my $WithComments = $ENV{WITH_COMMENTS};

my $git_repo = Git::Raw::Repository->open ($git_url);
my $root_tree;
if ($ref_type eq 'branch') {
  my $branch = Git::Raw::Branch->lookup ($git_repo, $ref, 1)
      // die "Branch |$ref| not found";
  $root_tree = $branch->target->tree;
} elsif ($ref_type eq 'tree') {
  $root_tree = Git::Raw::Tree->lookup ($git_repo, $ref)
      // die "Tree |$ref| not found";
} else {
  die "Unknown ref type |$ref_type|";
}

my $dat_entries = {};
my $txt_entries = {};
my $comments_entries = {};

my $set_parent_tree = length $text_set_path ? do {
  my $entry = $root_tree->entry_bypath ($text_set_path);
  defined $entry ? $entry->object : undef;
} : $root_tree;
if (defined $set_parent_tree and $set_parent_tree->is_tree) {
  my $set_texts_entry = $set_parent_tree->entry_byname ('texts');
  if (defined $set_texts_entry and $set_texts_entry->object->is_tree) {
    for my $dir_entry ($set_texts_entry->object->entries) {
      next unless $dir_entry->object->is_tree;
      my $name0 = $dir_entry->name;
      next unless $name0 =~ m{\A[0-9a-f]{2}\z};
      for my $entry ($dir_entry->object->entries) {
        next unless $entry->object->is_blob;
        next if $entry->file_mode & 020000; # symlinks
        my $name = $entry->name;
        next unless $name =~ m{\A([0-9a-f]{3,128})\.([0-9a-z-]{1,64}\.txt|dat|comments)\z};
        my $text_id = $name0.$1;
        my $type = $2;
        my $lang;
        if ($type =~ s/\.txt\z//) {
          $lang = $type;
          $type = 'txt';
        }
        if ($type eq 'txt') {
          my $te = TR::TextEntry->new_from_source_bytes
              ($entry->object->content);
          $txt_entries->{$text_id}->{$lang} = $te->as_jsonalizable;
        } elsif ($type eq 'dat') {
          my $te = TR::TextEntry->new_from_source_bytes
              ($entry->object->content);
          $dat_entries->{$text_id} = $te->as_jsonalizable;
        } elsif ($type eq 'comments' and $WithComments) {
          my $comments = $comments_entries->{$text_id} = [];
          for (grep { length } split /\x0D?\x0A\x0D?\x0A/, $entry->object->content) {
            push @$comments, TR::TextEntry->new_from_source_bytes
                ($_)->as_jsonalizable;
          }
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
if ($WithComments) {
  for my $text_id (keys %$dat_entries) {
    $json->{texts}->{$text_id}->{comments} = $comments_entries->{$text_id} || [];
  }
}
for my $text_id (keys %$txt_entries) {
  $json->{texts}->{$text_id}->{langs} = $txt_entries->{$text_id};
}

print perl2json_bytes $json;
