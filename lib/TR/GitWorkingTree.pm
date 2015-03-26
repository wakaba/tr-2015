package TR::GitWorkingTree;
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
    unless ($result->is_success and $result->exit_code == 0) {
      die "$result\n$stderr";
    }
    return {stdout => $stdout, stderr => $stderr};
  });
} # git

sub commit ($%) {
  my ($self, %args) = @_;

  my $args = [];
  push @$args, '--message=' . $args{message} if defined $args{message};

  AE::log alert => "$self->{dir_name}\$ git commit @$args";
  my $cmd = Promised::Command->new (['git', 'commit', @$args]);

  $cmd->envs->{GIT_AUTHOR_EMAIL} = $args{author_email} if defined $args{author_email};
  $cmd->envs->{GIT_AUTHOR_NAME} = $args{author_name} if defined $args{author_name};
  $cmd->envs->{GIT_COMMITTER_EMAIL} = $args{committer_email} if defined $args{committer_email};
  $cmd->envs->{GIT_COMMITTER_NAME} = $args{committer_name} if defined $args{committer_name};

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
} # commit

1;
