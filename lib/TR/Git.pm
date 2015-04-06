package TR::Git;
use strict;
use warnings;
use Fcntl;
use AnyEvent;
use AnyEvent::IO qw(:DEFAULT :flags);
use Promise;
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
  AE::log alert => "HOME=$opt{home}" if defined $opt{home};
  AE::log alert => "\$ git clone @$args";
  my $cmd = Promised::Command->new (['git', 'clone', @$args]);
  $cmd->envs->{GIT_ASKPASS} = 'true';
  $cmd->envs->{HOME} = $opt{home} if defined $opt{home};
  $cmd->envs->{GIT_SSH} = $opt{ssh} if defined $opt{ssh};
  $cmd->envs->{TR_SSH_PRIVATE_KEY} = $opt{ssh_private_key}
      if defined $opt{ssh_private_key};
  $cmd->stdin (\'');
  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);
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
    if (not $result->is_success) {
      die "$result\n$stderr";
    } elsif ($result->exit_code == 1) {
      if ($stderr =~ /^fatal: Remote branch .+ not found in upstream /ms) {
        die {result => $result, stdout => $stdout, stderr => $stderr,
             bad_branch => 1};
      } else {
        die "$result\n$stderr";
      }
    } elsif ($result->exit_code != 0) {
      die "$result\n$stderr";
    }
    return {stdout => $stdout};
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

push @EXPORT, qw(lock_repo);
sub lock_repo ($$) {
  my ($path, $timeout) = @_;
  $timeout += AE::now;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    aio_open $path, O_WRONLY | O_TRUNC | O_CREAT, 0644, sub {
      return $ng->("|$path|: open: $!") unless @_;
      my $fh = $_[0];
      my $try; $try = sub {
        my $result = flock $fh, Fcntl::LOCK_EX | Fcntl::LOCK_NB;
        if ($result) {
          $ok->($fh);
          undef $try;
        } else {
          if ($! == 11) { # EAGAIN
            if (AE::now < $timeout) {
              my $timer; $timer = AE::timer 0.5, 0, sub {
                $try->();
                undef $timer;
              };
            } else {
              $ng->("|$path|: flock: $!");
              undef $try;
            }
          } else {
            $ng->("|$path|: flock: $!");
            undef $try;
          }
        }
      }; # $try
      $try->();
    };
  });
} # lock

1;
