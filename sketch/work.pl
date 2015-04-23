use strict;
use warnings;
use Git::Raw::Repository;
use Git::Raw::Branch;

my $repo_dir_name = '/tmp/repo1';
my $branch_name = 'master';

my $git_repo = Git::Raw::Repository->open ($repo_dir_name);
my $git_branch = Git::Raw::Branch->lookup ($git_repo, $branch_name, 1)
    // die "Branch |$branch_name| not found";
my $tree = $git_branch->target->tree;

my $index = $git_repo->index;

warn $index->write_tree->id;

my $name = rand . '-';

system "cd $repo_dir_name && touch $name-1";

$index->add ("$name-1");

for ($index->entries) {
  warn $_->path;
}

$index->write;

warn $index->write_tree->id;

system "cd $repo_dir_name && perl -e 'print rand' > $name-2";
$index->add ("$name-2");

warn $index->write_tree->id;
warn $index->write_tree->id;
