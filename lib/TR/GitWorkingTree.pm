package TR::GitWorkingTree;
use strict;
use warnings;
use Promised::Command;

sub new_from_dir_name ($$) {
  return bless {dir_name => $_[1]}, $_[0];
} # new_from_dir_name

sub home_dir_name ($;$) {
  if (@_ > 1) {
    $_[0]->{home_dir_name} = $_[1];
  }
  return $_[0]->{home_dir_name};
} # home_dir_name

sub ssh_file_name ($;$) {
  if (@_ > 1) {
    $_[0]->{ssh_file_name} = $_[1];
  }
  return $_[0]->{ssh_file_name};
} # ssh_file_name

sub ssh_private_key_file_name ($;$) {
  if (@_ > 1) {
    $_[0]->{ssh_private_key_file_name} = $_[1];
  }
  return $_[0]->{ssh_private_key_file_name};
} # ssh_private_key_file_name

sub git ($$$) {
  my ($self, $command, $args) = @_;
  AE::log alert => "$self->{dir_name}\$ git $command @$args";
  my $cmd = Promised::Command->new (['git', $command, @$args]);
  $cmd->envs->{GIT_ASKPASS} = 'true';
  $cmd->envs->{HOME} = $self->{home_dir_name} if defined $self->{home_dir_name};
  $cmd->envs->{GIT_SSH} = $self->{ssh_file_name} if defined $self->{ssh_file_name};
  $cmd->envs->{TR_SSH_PRIVATE_KEY} = $self->{ssh_private_key_file_name}
      if defined $self->{ssh_private_key_file_name};
  $cmd->stdin (\'');
  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);
  $cmd->wd ($self->{dir_name});
  $cmd->create_process_group (1);
  my $timer1; $timer1 = AE::timer 60, 0, sub {
    eval { kill -15, getpgrp $cmd->pid }; undef $timer1;
  };
  my $timer2; $timer2 = AE::timer 70, 0, sub {
    eval { kill -9, getpgrp $cmd->pid }; undef $timer2;
  };
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
    if (not $result->is_success) {
      die $result;
    } elsif ($result->exit_code == 1) {
      if ($stdout =~ /^(?:nothing to commit|no changes added to commit) /m) {
        return {stdout => $stdout, stderr => $stderr, no_commit => 1};
      } else {
        die $result;
      }
    } elsif ($result->exit_code != 0) {
      die $result;
    }
    return {stdout => $stdout, stderr => $stderr};
  });
} # commit

1;
