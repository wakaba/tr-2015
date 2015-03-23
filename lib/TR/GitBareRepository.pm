package TR::GitBareRepository;
use strict;
use warnings;
use Promised::Command;

sub new_from_dir_name ($$) {
  return bless {dir_name => $_[1]}, $_[0];
} # new_from_dir_name

sub git ($$$) {
  my ($self, $command, $args) = @_;
  AE::log alert => "$self->{dir_name}\$ git $command @$args";
  my $cmd = Promised::Command->new (['git', $command, @$args]);
  $cmd->stdin (\'');
  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);
  $cmd->wd ($self->{dir_name});
  $cmd->timeout (100);
  return $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    die $result unless $result->is_success and $result->exit_code == 0;
    return {stdout => $stdout, stderr => $stderr};
  });
} # git

sub fetch ($) {
  return $_[0]->git ('fetch', []);
} # fetch

1;
