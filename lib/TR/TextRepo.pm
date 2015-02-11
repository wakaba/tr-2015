package TR::TextRepo;
use strict;
use warnings;
use AnyEvent::Util qw(run_cmd);
use Promise;
use Digest::SHA qw(sha1_hex);

sub new_from_temp_path ($) {
  return bless {temp_path => $_[1]}, $_[0];
} # new_from_temp_path

sub repo_path ($) {
  return $_[0]->{repo_path} ||= $_[0]->{temp_path}->child ('text-repo-' . rand);
} # repo_path

sub texts_dir ($;$) {
  if (@_ > 1) {
    $_[0]->{texts_dir} = $_[1];
  }
  return $_[0]->{texts_dir};
} # texts_dir

sub texts_path ($) {
  return $_[0]->{texts_path} ||= do {
    my $p = $_[0]->repo_path;
    $p = $p->child ($_[0]->{texts_dir}) if defined $_[0]->{texts_dir} and length $_[0]->{texts_dir};
    $p->child ('texts');
  };
} # texts_path

sub clone_by_url ($$) { # XXX branch
  my ($self, $url) = @_;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $repo_path = $self->repo_path;
    (run_cmd ['git', 'clone', $url, $repo_path, '--depth', 1])->cb (sub { # XXX timeout
      my  $status = $_[0]->recv;
      if ($status >> 8) {
        $ng->("Can't clone <$url>");
      } else {
        $ok->();
      }
    });
  });
} # clone_by_url

sub generate_text_id ($) {
  return sha1_hex (time () . $$ . rand ());
} # generate_text_id

sub text_id_and_suffix_to_path ($$$) {
  my ($self, $id, $suffix) = @_;
  return $self->texts_path->child ((substr $id, 0, 2) . '/' . (substr $id, 2) . '.' . $suffix);
} # text_id_and_suffix_to_path

sub read_file_by_text_id_and_suffix ($$$) {
  my ($self, $id, $suffix) = @_;
  my $path = $self->text_id_and_suffix_to_path ($id, $suffix);
  return Promise->new (sub {
    if ($path->is_file) {
      $_[0]->($path->slurp_utf8); # or exception # XXX blocking I/O
    } else {
      $_[0]->(undef);
    }
  });
} # read_file_by_text_id_and_suffix

sub write_file_by_text_id_and_suffix ($$$$) {
  my ($self, $id, $suffix, $text) = @_;
  my $path = $self->text_id_and_suffix_to_path ($id, $suffix);
  $path->parent->mkpath;
  $path->spew_utf8 ($text); # or exception # XXX blocking I/O
  return $self->add_by_paths ([$path]);
} # write_file_by_text_id_and_suffix

sub text_ids ($) {
  my $self = $_[0];
  my %list;
  my $texts_path = $self->texts_path;
  if ($texts_path->is_dir) {
    for my $path ($texts_path->children (qr/\A([0-9a-f]{2})\z/)) {
      next unless $path->is_dir;
      for my $path ($path->children (qr/\A([0-9a-f]+)\./)) {
        if ($path =~ m{/([0-9a-f]{2})/([0-9a-f]+)\.}) {
          $list{"$1$2"} = 1;
        }
      }
    }
  }
  return Promise->new (sub { $_[0]->(\%list) });
} # text_ids

sub add_by_paths ($$) {
  my ($self, $paths) = @_;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $repo_path = $self->repo_path;
    die "No file to add" unless @$paths;
    (run_cmd "cd \Q$repo_path\E && git add " . join ' ', map { quotemeta $_->relative ($repo_path) } @$paths)->cb (sub {
      my  $status = $_[0]->recv;
      if ($status >> 8) {
        $ng->("Can't add");
      } else {
        $ok->();
      }
    });
  });
} # add_by_paths

sub commit ($$) {
  my ($self, $msg) = @_;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $repo_path = $self->repo_path;
    $msg = ' ' unless length $msg;
    (run_cmd "cd \Q$repo_path\E && git commit -m \Q$msg\E")->cb (sub { # XXX author/committer
      my  $status = $_[0]->recv;
      if ($status >> 8) {
        $ng->("Can't commit");
      } else {
        $ok->();
      }
    });
  });
} # commit

sub push ($) {
  my $self = $_[0];
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $repo_path = $self->repo_path;
    (run_cmd "cd \Q$repo_path\E && git push")->cb (sub {
      my $status = $_[0]->recv;
      if ($status >> 8) {
        $ng->("Can't push");
      } else {
        $ok->();
      }
    });
  });
} # push

sub discard ($) {
  my $self = $_[0];
  return Promise->new (sub {
    $self->repo_path->remove_tree ({safe => 0});
    $_[0]->();
  });
} # discard

1;
