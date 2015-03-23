package TR::Git;
use strict;
use warnings;
use Promised::Command;

our @EXPORT;

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or die qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

push @EXPORT, qw(git);
sub git ($$$) {
  my ($repo_dir, $command, $args) = @_;
  my $cmd = Promised::Command->new (['git', $command, @$args]);
  $cmd->stdin (\'');
  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);
  $cmd->wd ($repo_dir);
  $cmd->timeout (100);
  return $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    die $result unless $result->is_success and $result->exit_code == 0;
    return {stdout => $stdout, stderr => $stderr};
  });
} # git

push @EXPORT, qw(git_clone);
sub git_clone ($) {
  my ($args) = @_;
  my $cmd = Promised::Command->new (['git', 'clone', @$args]);
  $cmd->stdin (\'');
  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);
  $cmd->timeout (100);
  return $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    die $result unless $result->is_success and $result->exit_code == 0;
    return {stdout => $stdout, stderr => $stderr};
  });
} # git_clone

1;
