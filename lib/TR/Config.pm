package TR::Config;
use strict;
use warnings;
use Path::Tiny;
use Encode;
use Promised::File;
use Promised::Command;
use MIME::Base64;
use JSON::PS;
use Dongry::Database;

sub new_from_path ($$) {
  my ($class, $path) = @_;
  my $json = json_bytes2perl $path->slurp;
  for my $key (keys %$json) {
    my $value = $json->{$key};
    if (defined $value and ref $value eq 'ARRAY') {
      if (not defined $value->[0]) {
        #
      } elsif ($value->[0] eq 'Base64') {
        $json->{$key} = decode_base64 $value->[1] // '';
      }
    }
  }
  die "$path: Not a JSON object" unless defined $json;
  return bless {base_path => $path->parent, json => $json}, $class;
} # new_from_path

sub load_siteadmin ($$) {
  my ($self, $path) = @_;
  $self->{siteadmin_path} = $path;
  unless (-f $path->child ('HEAD')) {
    (system 'mkdir', '-p', $path) == 0 or die "mkdir -p $path: " . ($? >> 8);
    (system 'sh', '-c', "cd \Q$path\E && git init --bare") == 0
        or die "git init --bare: " . ($? >> 8);
  }
  unless (-f $path->child ('refs/heads/master')) {
    (system 'sh', '-c', "cd \Q$path\E && (git write-tree | GIT_COMMITTER_EMAIL=initial\@invalid GIT_COMMITTER_NAME=Initial GIT_AUTHOR_EMAIL=initial\@invalid GIT_AUTHOR_NAME=Initial xargs git commit-tree | xargs git branch master)") == 0
        or die "git: " . ($? >> 8);
  }
} # load_siteadmin

sub get ($$) {
  return $_[0]->{json}->{$_[1]};
} # get

sub get_path ($$) {
  return path ($_[0]->{json}->{$_[1]} // $_[1])->absolute ($_[0]->{base_path});
} # get_path

$Dongry::Types->{json} = {
  parse => sub {
    if (defined $_[0]) {
      return json_bytes2perl $_[0];
    } else {
      return undef;
    }
  },
  serialize => sub {
    if (defined $_[0]) {
      return perl2json_bytes $_[0];
    } else {
      return undef;
    }
  },
}; # json

my $Schema = {
  repo_access => {
    type => {repo_url => 'text', data => 'json'},
    primary_keys => ['repo_url', 'account_id'],
  },
  account_repos => {
    type => {type => 'text', data => 'json'},
    primary_keys => ['account_id', 'type'],
  },
};

sub get_db ($) {
  my $config = $_[0]->{json};
  my $sources = {};
  $sources->{master} = {
    dsn => (encode 'utf-8', $config->{alt_dsns}->{master}->{tr}),
    writable => 1, anyevent => 1,
  };
  $sources->{default} = {
    dsn => (encode 'utf-8', $config->{dsns}->{tr}),
    anyevent => 1,
  };
  return Dongry::Database->new (sources => $sources, schema => $Schema);
} # get_db

1;
