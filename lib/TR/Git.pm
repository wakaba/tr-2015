package TR::Git;
use strict;
use warnings;
use Promised::Command;
use Promised::File;

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

push @EXPORT, qw(git_clone);
sub git_clone ($;%) {
  my ($args, %opt) = @_;
  my $cmd = Promised::Command->new (['git', 'clone', @$args]);
  $cmd->envs->{HOME} = $opt{home} if defined $opt{home};
  $cmd->stdin (\'');
  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);
  $cmd->timeout (100);
  return $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    unless ($result->is_success and $result->exit_code == 0) {
      die "$result\n$stderr";
    }
    return {stdout => $stdout, stderr => $stderr};
  });
} # git_clone

push @EXPORT, qw(git_home_config);
sub git_home_config ($$) {
  my ($home_dir_name, $args) = @_;
  my $cmd = Promised::Command->new
      (['git', 'config', '-f', "$home_dir_name/.gitconfig", @$args]);
  $cmd->stdin (\'');
  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);
  $cmd->timeout (10);
  return Promised::File->new_from_path ($home_dir_name)->mkpath->then (sub {
    return $cmd->run;
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    unless ($result->is_success and $result->exit_code == 0) {
      die "$result\n$stderr";
    }
    return {stdout => $stdout, stderr => $stderr};
  });
} # git_home_config

1;
