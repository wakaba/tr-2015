package TR::AppServer;
use strict;
use warnings;
use Warabe::App;
push our @ISA, qw(Warabe::App);
use Path::Tiny;
use AnyEvent::Handle;
use Promise;

sub new_from_http_and_config ($$$) {
  my $self = $_[0]->SUPER::new_from_http ($_[1]);
  $self->{config} = $_[1];
  return $self;
} # new_from_http_and_config

sub config ($) {
  return $_[0]->{config};
} # config

sub error_log ($$) {
  #$_[0]->ikachan (1, $_[1]);
  warn "ERROR: $_[1]\n"; # XXX blocking I/O
} # error_log

my $RootPath = path (__FILE__)->parent->parent->parent;

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

1;
