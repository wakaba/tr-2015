package TR::AppServer;
use strict;
use warnings;
use Warabe::App;
push our @ISA, qw(Warabe::App);
use Path::Tiny;
use JSON::PS;
use AnyEvent::Handle;
use Promise;
use Web::UserAgent::Functions qw(http_get http_post);
use Web::DOM::Document;
use Temma::Parser;
use Temma::Processor;

sub new_from_http_and_config ($$$) {
  my $self = $_[0]->SUPER::new_from_http ($_[1]);
  $self->{config} = $_[2];
  return $self;
} # new_from_http_and_config

sub config ($) {
  return $_[0]->{config};
} # config

sub db ($) {
  return $_[0]->{db} ||= $_[0]->config->get_db;
} # db

{
  my $app_rev = `git rev-parse HEAD`;
  chomp $app_rev;
  sub app_revision ($) {
    return $app_rev;
  } # app_revision
}

sub account_server ($$$) {
  my ($self, $path, $params) = @_;
  my $prefix = $self->config->get ('account.url_prefix');
  my $api_token = $self->config->{account_token};
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post
        url => $prefix . $path,
        header_fields => {Authorization => 'Bearer ' . $api_token},
        params => $params,
        timeout => 30,
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
} # account_server

sub error_log ($$) {
  #$_[0]->ikachan (1, $_[1]);
  warn "ERROR: $_[1]\n"; # XXX blocking I/O
} # error_log

sub send_json ($$) {
  my ($self, $data) = @_;
  $self->http->set_response_header ('Content-Type' => 'application/json; charset=utf-8');
  $self->http->send_response_body_as_ref (\perl2json_bytes $data);
  $self->http->close_response_body;
} # send_json

sub start_json_stream ($) {
  my $self = $_[0];
  $self->{in_json_stream} = 1;
  $self->http->set_status (202, reason_phrase => 'See payload body');
  $self->http->set_response_header
      ('Content-Type' => 'application/x-ndjson; charset=utf-8');
} # start_json_stream

sub send_progress_json_chunk ($$;$) {
  my ($self, $reason, $values) = @_;
  return unless $self->{in_json_stream};
  my $json = {status => 102, message => $reason};
  if (defined $values) {
    $json->{value} = $values->[0];
    $json->{max} = $values->[1];
  }
  $self->http->send_response_body_as_ref (\perl2json_bytes $json);
  $self->http->send_response_body_as_ref (\"\nnull\n");
} # send_progress_json_chunk

sub send_last_json_chunk ($$$$) {
  my ($self, $status, $reason, $data) = @_;
  if (delete $self->{in_json_stream}) {
    $self->http->send_response_body_as_ref
        (\perl2json_bytes {status => $status, message => $reason // $status,
                           data => $data});
    $self->http->send_response_body_as_ref (\"\nnull\n");
  } else {
    $self->http->set_status ($status, reason_phrase => $reason);
    $self->http->set_response_header
        ('Content-Type' => 'application/json; charset=utf-8');
    $self->http->send_response_body_as_ref (\perl2json_bytes $data);
  }
  $self->http->close_response_body;
} # send_last_json_chunk

sub send_error ($$;%) {
  my ($self, $status, %args) = @_;
  if ($self->{in_json_stream}) {
    return $self->send_last_json_chunk ($status, $args{reason_phrase});
  } else {
    return $self->SUPER::send_error ($status, %args);
  }
} # send_error

my $RootPath = path (__FILE__)->parent->parent->parent;

sub mirror_path ($) {
  return $RootPath->child ('local/mirrors');
} # mirror_path

sub send_file ($$$) {
  my ($self, $file_name, $content_type) = @_;
  ## $file_name MUST be safe.
  $self->http->set_response_header ('Content-Type' => $content_type);
  my $path = $RootPath->child ($file_name);
  unless ($path->is_file) {
    return $self->send_error (404, reason_phrase => 'File not found');
  }
  $self->http->set_response_last_modified ($path->stat->mtime);
  my ($ok, $ng) = @_;
  my $p = Promise->new (sub { ($ok, $ng) = @_ });
  my $hdl; $hdl = AnyEvent::Handle->new
    (fh => $path->openr,
     on_error => sub {
       $self->error_log ("$path: $_[2]");
       $hdl->destroy;
       $ng->();
     },
     on_read => sub {
       $self->http->send_response_body_as_ref (\($_[0]->{rbuf}));
       $hdl->rbuf = '';
     },
     on_eof => sub {
       $hdl->destroy;
       $ok->();
     });
  return $p->catch (sub {
    eval { $self->http->set_status (500, reason_phrase => 'File error') };
  })->then (sub {
    $self->http->close_response_body;
  });
} # send_file

my $TemplatesPath = $RootPath->child ('templates');

use Path::Class; # XXX
sub temma ($$$) {
  my ($self, $template_path, $args) = @_;
  $template_path = $TemplatesPath->child ($template_path);
  die "|$template_path| not found" unless $template_path->is_file;

  my $http = $self->http;
  $http->set_response_header ('Content-Type' => 'text/html; charset=utf-8');
  my $fh = TR::AppServer::TemmaPrinter->new_from_http ($http);
  my $ok;
  my $p = Promise->new (sub { $ok = $_[0] });

  my $doc = new Web::DOM::Document;
  my $parser = Temma::Parser->new;
  $parser->parse_f (file ($template_path) => $doc); # XXX blocking
  my $processor = Temma::Processor->new;
  $processor->process_document ($doc => $fh, ondone => sub {
    $http->close_response_body;
    $ok->();
  }, args => $args);

  return $p;
} # temma

sub shutdown ($) {
  return $_[0]->{db}->disconnect if defined $_[0]->{db};
  return Promise->resolve;
} # shutdown

package TR::AppServer::TemmaPrinter;

sub new_from_http ($$) {
  return bless {http => $_[1]}, $_[0];
} # new_from_http

sub print ($$) {
  $_[0]->{value} .= $_[1];
  if (length $_[0]->{value} > 1024*10 or length $_[1] == 0) {
    $_[0]->{http}->send_response_body_as_text ($_[0]->{value});
    $_[0]->{value} = '';
  }
} # print

sub DESTROY {
  $_[0]->{http}->send_response_body_as_text ($_[0]->{value})
      if length $_[0]->{value};
} # DESTROY

1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
