use strict;
use warnings;
use Git::Raw::Repository;
use Git::Raw::Branch;
BEGIN { require 'gitraw.pl' };

my ($repo_dir_name, $branch_name, $file_name) = @ARGV;
die "Usage: $0 repo-dir branch file" unless defined $file_name;

my $git_repo = Git::Raw::Repository->open ($repo_dir_name);
my $git_branch = Git::Raw::Branch->lookup ($git_repo, $branch_name, 1)
    // die "Branch |$branch_name| not found";
my $tree = $git_branch->target->tree;

my $entry = $tree->entry_bypath ($file_name);
if (defined $entry and entry_is_blob $entry) {
  print $entry->object->content;
}

