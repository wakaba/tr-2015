package TR::Config;
use strict;
use warnings;
use Encode;
use Promised::File;
use MIME::Base64;
use JSON::PS;
use Dongry::Database;

sub from_file_name ($$) {
  my ($class, $file_name) = @_;
  my $file = Promised::File->new_from_path ($file_name);
  return $file->read_byte_string->then (sub {
    my $json = json_bytes2perl $_[0];
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
    die "$file_name: Not a JSON object" unless defined $json;
    return bless {json => $json}, $class;
  });
} # from_file_name

sub get ($$) {
  return $_[0]->{json}->{$_[1]};
} # get

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
