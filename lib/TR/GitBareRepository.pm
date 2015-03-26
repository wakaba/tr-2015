package TR::GitBareRepository;
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

sub git ($$$) {
  my ($self, $command, $args) = @_;
  AE::log alert => "$self->{dir_name}\$ git $command @$args";
  my $cmd = Promised::Command->new (['git', $command, @$args]);
  $cmd->envs->{HOME} = $self->{home_dir_name} if defined $self->{home_dir_name};
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

sub fetch ($) {
  return $_[0]->git ('fetch', []);
} # fetch

sub log ($;%) {
  my ($self, %args) = @_;

  my $args = [];
  push @$args, '--raw', '--format=raw';
  push @$args, '-'.(0+$args{limit}) if $args{limit};
  push @$args, $args{range} if defined $args{range};
  push @$args, '--', @{$args{paths}} if @{$args{paths} or []};

  return $self->git ('log', $args)->then (sub {
    require Git::Parser::Log;
    require Encode;
    return Git::Parser::Log->parse_format_raw
        (Encode::decode ('utf-8', $_[0]->{stdout}));
  });
} # log

sub ls_tree ($$;%) {
  my ($self, $treeish, %args) = @_;

  my $args = ['-z', '-l', '--full-name'];
  push @$args, '-r' if $args{recursive};
  push @$args, $treeish;
  push @$args, @{$args{paths} or []};

  return $self->git ('ls-tree', $args)->then (sub {
    my $result = {};
    for (split /\x00/, $_[0]->{stdout}) {
      if (/\A([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+)\t(.+)/s) {
        $result->{$5} = {mode => $1, type => $2, object => $3, object_size => $4, file => $5};
      }
    }
    return $result;
  });
} # ls_tree

sub show_blob_by_path ($$$) {
  my ($self, $treeish, $path) = @_;
  return $self->ls_tree ($treeish, recursive => 1, paths => [$path])->then (sub {
    my $file = $_[0]->{$path};
    if (defined $file and $file->{type} eq 'blob') {
      return $self->git ('show', [$file->{object}])->then (sub {
        return $_[0]->{stdout};
      });
    } else {
      return undef;
    }
  });
} # show_blob_by_path

1;
