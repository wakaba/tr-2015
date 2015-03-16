package TR::MongoLab;
use strict;
use warnings;
use Promise;
use JSON::PS;
use Web::UserAgent::Functions qw(http_get http_post_data);
use Wanage::URL;

## Document: <http://docs.mongolab.com/restapi/>

sub new_from_api_key ($$) {
  return bless {api_key => $_[1]}, $_[0];
} # new_from_api_key

sub _get ($$$) {
  my ($self, $path, $params) = @_;
  for (values %$params) {
    $_ = perl2json_chars $_ if ref $_;
  }
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_get
        url => q<https://api.mongolab.com/api/1/> . (join '/', map { percent_encode_c $_ } @$path),
        params => {
          apiKey => $self->{api_key},
          %$params,
        },
        timeout => 100,
        anyevent => 1,
        cb => sub {
          my (undef, $res) = @_;
          if ($res->code == 200) {
            $ok->(json_bytes2perl $res->content);
          } else {
            $ng->($res->status_line);
          }
        };
  });
} # _get

sub _post ($$$$) {
  my ($self, $path, $params, $data) = @_;
  for (values %$params) {
    $_ = perl2json_chars $_ if ref $_;
  }
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post_data
        url => q<https://api.mongolab.com/api/1/> . (join '/', map { percent_encode_c $_ } @$path),
        params => {
          apiKey => $self->{api_key},
          %$params,
        },
        header_fields => {'Content-Type' => 'application/json'},
        content => (perl2json_bytes $data),
        timeout => 100,
        anyevent => 1,
        cb => sub {
          my (undef, $res) = @_;
          if ($res->code == 200) {
            $ok->(json_bytes2perl $res->content);
          } else {
            $ng->($res->status_line);
          }
        };
  });
} # _post

sub _put ($$$$) {
  my ($self, $path, $params, $data) = @_;
  for (values %$params) {
    $_ = perl2json_chars $_ if ref $_;
  }
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post_data
        override_method => 'PUT',
        url => q<https://api.mongolab.com/api/1/> . (join '/', map { percent_encode_c $_ } @$path),
        params => {
          apiKey => $self->{api_key},
          %$params,
        },
        header_fields => {'Content-Type' => 'application/json'},
        content => (perl2json_bytes $data),
        timeout => 100,
        anyevent => 1,
        cb => sub {
          my (undef, $res) = @_;
          if ($res->code == 200) {
            $ok->(json_bytes2perl $res->content);
          } else {
            $ng->($res->status_line);
          }
        };
  });
} # _put

sub get_docs_by_query ($$$$) {
  my ($self, $db, $col, $query) = @_;
  return $self->_get (['databases', $db, 'collections', $col], {q => $query});
} # get_docs_by_query

sub update_doc_by_query ($$$$$$) {
  my ($self, $db, $col, $id, $action, $query) = @_;
  return $self->_put (['databases', $db, 'collections', $col, $id], {q => $query}, $action);
} # update_doc_by_query

sub set_doc ($$$$) {
  my ($self, $db, $col, $data) = @_;
  return $self->_post (['databases', $db, 'collections', $col], {}, $data);
} # set_doc

1;
