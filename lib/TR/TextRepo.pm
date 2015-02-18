package TR::TextRepo;
use strict;
use warnings;
use AnyEvent::Util qw(run_cmd);
use Promise;
use Digest::SHA qw(sha1_hex);
use Wanage::URL;
use TR::TextEntry;

sub new_from_mirror_and_temp_path ($$$) {
  return bless {mirror_path => $_[1], temp_path => $_[2]}, $_[0];
} # new_from_mirror_and_temp_path

sub url ($;$) {
  if (@_ > 1) {
    $_[0]->{url} = $_[1];
  }
  return $_[0]->{url};
} # url

sub path_name ($) {
  my $self = $_[0];
  $self->{path_name} ||= percent_encode_c $self->url;
} # path_name

sub branch ($;$) {
  if (@_ > 1) {
    $_[0]->{branch} = $_[1];
  }
  return $_[0]->{branch};
} # branch

sub langs ($;$) {
  if (@_ > 1) {
    $_[0]->{langs} = $_[1];
  }
  return $_[0]->{langs} || [];
} # langs

sub avail_langs ($;$) {
  if (@_ > 1) {
    $_[0]->{avail_langs} = $_[1];
  }
  return $_[0]->{avail_langs} || [];
} # avail_langs

sub mirror_parent_path ($) {
  return $_[0]->{mirror_parent_path} ||= $_[0]->{mirror_path}->child ('git_mirrors');
} # mirror_parent_path

sub mirror_repo_path ($) {
  return $_[0]->{mirror_repo_path} ||= $_[0]->mirror_parent_path->child ($_[0]->path_name);
} # mirror_repo_path

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

sub prepare_mirror ($) {
  my $self = $_[0];
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $mirror_path = $self->mirror_repo_path;
    if ($mirror_path->child ('config')->is_file) {
      (run_cmd "cd \Q$mirror_path\E && git fetch")->cb (sub { # XXXtimeout
        my $status = $_[0]->recv;
        if ($status >> 8) {
          $ng->("Can't clone <".$self->url.">"); # XXX
        } else {
          $ok->();
        }
      });
    } else {
      (run_cmd ['git', 'clone', '--mirror', $self->url, $mirror_path])->cb (sub { # XXX timeout
        my $status = $_[0]->recv;
        if ($status >> 8) {
          $ng->("Can't clone <".$self->url.">"); # XXX
        } else {
          $ok->();
        }
      });
    }
  });
} # prepare_mirror

sub clone_from_mirror ($) {
  my $self = $_[0];
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    # XXX default branch
    (run_cmd ['git', 'clone', '-b', $self->branch, $self->mirror_repo_path, $self->repo_path])->cb (sub {
      my $status = $_[0]->recv;
      if ($status >> 8) {
        $ng->("Can't clone");
      } else {
        $ok->();
      }
    });
  });
} # clone_from_mirror

sub make_pushable ($$$) {
  my ($self, $userid, $password) = @_;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $url = $self->url;
    $url =~ s{^https://github\.com/}{'https://'.(percent_encode_c $userid).':'.(percent_encode_c $password).'@github.com/'}e;
    my $path = $self->repo_path;
    (run_cmd "cd \Q$path\E && git remote add remoterepo \Q$url\E")->cb (sub {
      my $status = $_[0]->recv;
      if ($status >> 8) {
        $ng->("Can't config");
      } else {
        $ok->();
      }
    });
  });
} # make_pushable

sub generate_text_id ($) {
  return sha1_hex (time () . $$ . rand ());
} # generate_text_id

sub generate_section_id ($) {
  return sha1_hex (time () . $$ . rand ());
} # generate_section_id

sub text_id_and_suffix_to_path ($$$) {
  my ($self, $id, $suffix) = @_;
  return $self->texts_path->child ((substr $id, 0, 2) . '/' . (substr $id, 2) . '.' . $suffix);
} # text_id_and_suffix_to_path

sub read_file_by_path ($$) {
  my ($self, $path) = @_;
  # XXX max file size
  return Promise->new (sub {
    if ($path->is_file) {
      $_[0]->($path->slurp_utf8); # or exception # XXX blocking I/O
    } else {
      $_[0]->(undef);
    }
  });
} # read_file_by_path

sub write_file_by_path ($$$) {
  my ($self, $path) = @_;
  $path->parent->mkpath;
  $path->spew_utf8 ($_[2]); # or exception # XXX blocking I/O
  return $self->add_by_paths ([$path]);
} # write_file_by_path

sub read_file_by_text_id_and_suffix ($$$) {
  my ($self, $id, $suffix) = @_;
  my $path = $self->text_id_and_suffix_to_path ($id, $suffix);
  return $self->read_file_by_path ($path);
} # read_file_by_text_id_and_suffix

sub write_file_by_text_id_and_suffix ($$$$) {
  my ($self, $id, $suffix, $text) = @_;
  my $path = $self->text_id_and_suffix_to_path ($id, $suffix);
  return $self->write_file_by_path ($path, $text);
} # write_file_by_text_id_and_suffix

sub append_section_to_file_by_text_id_and_suffix ($$$$) {
  my ($self, $id, $suffix, $text) = @_;
  my $path = $self->text_id_and_suffix_to_path ($id, $suffix);
  $path->parent->mkpath;
  $path->append_utf8 ("\x0A\x0A" . $text); # or exception # XXX blocking I/O
  return $self->add_by_paths ([$path]);
} # append_section_to_file_by_text_id_and_suffix

sub text_ids ($) {
  my $self = $_[0];
  my %list;
  my $texts_path = $self->texts_path;
  if ($texts_path->is_dir) { # XXX blocking I/O ??; symlink ??
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

sub get_data_as_jsonalizable ($%) {
  my ($self, %args) = @_;
  my $langs;
  return $self->read_file_by_path ($self->texts_path->child ('config.json'))->then (sub {
    my $tr_config = TR::TextEntry->new_from_text_id_and_source_text (undef, $_[0] // '');
    $langs = [grep { length } split /,/, $tr_config->get ('langs') // ''];
    my $specified_langs = $args{langs} || [];
    if (@$specified_langs) {
      my $avail_langs = {map { $_ => 1 } @$langs};
      @$specified_langs = grep { $avail_langs->{$_} } @$specified_langs;
      $langs = $specified_langs;
    }
  })->then (sub {
    my $text_ids = $args{text_ids} || [];
    if (@$text_ids) {
      return {map { $_ => 1 } grep { /\A[0-9a-f]{3,}\z/ } @$text_ids};
    } else {
      return $self->text_ids;
    }
  })->then (sub {
    # XXX
    my $data = {};
    my $texts = {};
    my @id = keys %{$_[0]};
    my @p;
    my $tags = $args{tags} || [];
    my $msgids = {map { $_ => 1 } @{$args{msgids} || []}};
    undef $msgids unless keys %$msgids;
    for my $id (@id) {
      push @p, $self->read_file_by_text_id_and_suffix ($id, 'dat')->then (sub {
        my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
        my $ok = 1;
        if (defined $msgids) {
          my $mid = $te->get ('msgid');
          return unless defined $mid;
          return unless $msgids->{$mid};
        }
        if (@$tags) {
          my $t = $te->enum ('tags');
          for (@$tags) {
            return unless $t->{$_};
          }
        }
        $data->{texts}->{$id} = $te->as_jsonalizable;
        my @q;
        for my $lang (@$langs) {
          push @q, $self->read_file_by_text_id_and_suffix ($id, $lang . '.txt')->then (sub {
            return unless defined $_[0];
            $data->{texts}->{$id}->{langs}->{$lang} = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0])->as_jsonalizable;
          });
        }
        if ($args{with_comments}) {
          my $comments = $data->{texts}->{$id}->{comments} = [];
          push @q, $self->read_file_by_text_id_and_suffix ($id, 'comments')->then (sub {
            for (grep { length } split /\x0D?\x0A\x0D?\x0A/, $_[0] // '') {
              push @$comments, TR::TextEntry->new_from_text_id_and_source_text ($id, $_)->as_jsonalizable;
            }
          });
        }
        return Promise->all (\@q);
        # XXX limit
      });
    } # $id
    return Promise->all (\@p)->then (sub {
      return $data;
    });
  });
} # get_data_as_jsonalizable

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
    (run_cmd "cd \Q$repo_path\E && git push remoterepo")->cb (sub {
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
