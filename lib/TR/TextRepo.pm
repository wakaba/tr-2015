package TR::TextRepo;
use strict;
use warnings;
use Path::Tiny;
use AnyEvent::Util qw(run_cmd);
use Encode;
use Promise;
use Promised::Command;
use Digest::SHA qw(sha1_hex);
use Wanage::URL;
use TR::TextEntry;
use TR::Git;

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

sub prepare_mirror ($$) {
  my $self = $_[0];
  my $token = $_[1]; # XXX
  my $mirror_path = $self->mirror_repo_path;
  if ($mirror_path->child ('config')->is_file) {
    return git ($mirror_path, 'fetch', []);
  } else {
    my $url = $self->url;
    $token //= '';
    $url =~ s{^https://github.com/}{https://$token:\@github.com/}; # XXX
    return git_clone (['--mirror', $url, $mirror_path]);
  }
} # prepare_mirror

sub clone_from_mirror ($) {
  my $self = $_[0];
  # XXX default branch
  return git_clone (['-b', $self->branch, $self->mirror_repo_path, $self->repo_path]);
} # clone_from_mirror

sub make_pushable ($$$) {
  my ($self, $userid, $password) = @_;
  my $url = $self->url;
  $url =~ s{^https://github\.com/}{'https://'.(percent_encode_c $userid).':'.(percent_encode_c $password).'@github.com/'}e; # XXX
  return git ($self->repo_path, 'remote', ['add', 'remoterepo', $url]);
} # make_pushable

sub get_branches ($) {
  my $self = $_[0];
  return git ($self->mirror_repo_path, 'branch', ['-v', '--no-abbrev'])->then (sub {
    my $result = $_[0];
    my $parsed = {branches => {}};
    for (split /\x0A/, decode 'utf-8', $result->{stdout}) {
      if (/^(\* |  )(\S+)\s+(\S+) (.*)$/) {
        my $d = {name => $2, commit => $3, commit_message => $4};
        $d->{selected} = 1 if $1 eq '* ';
        $parsed->{branches}->{$2} = $d;
      }
    }
    return $parsed;
  });
} # get_branches

sub get_commit_logs ($$) {
  my ($self, $commits) = @_;
  return git ($self->mirror_repo_path, 'show', ['--raw', '--format=raw', @$commits])->then (sub {
    my $result = $_[0];
    require Git::Parser::Log;
    return Git::Parser::Log->parse_format_raw (decode 'utf-8', $result->{stdout});
  });
} # get_commit_logs

sub get_logs_by_path ($$;%) {
  my ($self, $path, %args) = @_;
  return git ($self->mirror_repo_path, 'log', [
    ($args{limit} ? '-'.(0+$args{limit}) : ()),
    '--raw', '--format=raw',
    $self->branch, '--', $path,
  ])->then (sub {
    my $result = $_[0];
    require Git::Parser::Log;
    return Git::Parser::Log->parse_format_raw (decode 'utf-8', $result->{stdout});
  });
} # get_logs_by_path

sub get_last_commit_logs_by_paths ($$) {
  my ($self, $paths) = @_;
  my $p = Promise->resolve;
  my $result = {};
  for my $path (@$paths) {
    $p = $p->then (sub {
      return $self->get_logs_by_path ($path, limit => 1);
    })->then (sub {
      my $parsed = $_[0]; # XXX if not found
      $result->{$path} = $_[0]->{commits}->[0];
    });
  }
  return $p->then (sub { return $result });
} # get_last_commit_logs_by_paths

sub get_ls_tree ($$;%) {
  my ($self, $tree, %args) = @_;
  return git ($self->mirror_repo_path, 'ls-tree', [
    ($args{recursive} ? '-r' : ()),
    $tree,
  ])->then (sub {
    my $result = $_[0];
    my $parsed = {};
    for (split /\x0A/, decode 'utf-8', $result->{stdout}) {
      if (/^([0-9]+) (\S+) (\S+)\s+(.+)$/) {
        my $d = {mode => $1, type => $2, object => $3, file => $4};
        $d->{file} =~ s/\\([tn\\])/{t => "\x09", n => "\x0A", "\\" => "\\"}->{$1}/ge;
        $parsed->{items}->{$d->{file}} = $d;
      }
    }
  });
} # get_ls_tree

sub write_license_file ($%) {
  my ($self, %args) = @_;
  my $path = $self->texts_path->child ('LICENSE');
  # XXX if $path is directory or symlink
  my $license = $args{license} // '';
  $license = 'Unknown license' unless length $license;
  my $holders = $args{license_holders} // '';
  $holders = 'Authors' unless length $holders;
  my $additional = $args{additional_license_terms} // '';

  my $text = 'Copyright {YEAR} {HOLDERS}.'; # XXX
  $text =~ s/\{YEAR\}/[gmtime]->[5]+1900/ge;
  $text =~ s/\{HOLDERS\}/$holders/g;

  my @text;
  push @text, "[$license]";
  push @text, $text;
  push @text, $additional if length $additional;

  return $self->write_file_by_path ($path, join "\n\n", @text);
} # write_license_file

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

sub text_id_and_suffix_to_relative_path ($$$) {
  my ($self, $id, $suffix) = @_;
  my $path = (defined $self->{texts_dir} and length $self->{texts_dir})
      ? path ($self->{texts_dir}, 'texts') : path ('texts');
  return $path->child ((substr $id, 0, 2) . '/' . (substr $id, 2) . '.' . $suffix);
} # text_id_and_suffix_to_relative_path

sub git_log_for_text_id_and_lang ($$$;%) {
  my ($self, $id, $lang, %args) = @_;
  my $rel_path = $self->text_id_and_suffix_to_relative_path ($id, $lang . '.txt');
  my $mirror_path = $self->mirror_repo_path;
  my $branch = $self->branch;
  my $p = git ($mirror_path, 'log', ['--raw', '--format=raw', $branch, '--', $rel_path])->then (sub {
    my $result = $_[0];
    require Git::Parser::Log;
    return Git::Parser::Log->parse_format_raw (decode 'utf-8', $result->{stdout});
  });

  if ($args{with_file_text}) {
    $p = $p->then (sub {
      my $parsed = $_[0];
      my $q = Promise->resolve;
      for my $commit (@{$parsed->{commits}}) {
        $q = $q->then (sub {
          return git ($mirror_path, 'ls-tree', [$commit->{tree}, $rel_path]);
        })->then (sub {
          my $result = $_[0];
          if ($result->{stdout} =~ /^\S+ blob ([0-9a-f]+)\s/m) {
            return git ($mirror_path, 'show', [$1])
          } else {
            die "$commit->{tree} - $rel_path not found";
          }
        })->then (sub {
          my $result = $_[0];
          $commit->{blob_data} = $result->{stdout};
        });
      } # $commit
      return $q->then (sub { return $parsed });
    });
  }

  return $p;
} # git_log_for_text_id_and_lang

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
  my ($self, $query, $selected_langs, %args) = @_;
  my $data = {};
  return $self->read_file_by_path ($self->texts_path->child ('config.json'))->then (sub {
    my $tr_config = TR::TextEntry->new_from_text_id_and_source_text (undef, $_[0] // '');
    my $langs = [grep { length } split /,/, $tr_config->get ('langs') // ''];
    if (@$selected_langs) {
      my $avail_langs = {map { $_ => 1 } @$langs};
      @$selected_langs = grep { $avail_langs->{$_} } @$selected_langs;
    } else {
      $langs = ['en'] unless @$langs;
      $selected_langs = $langs;
    }

    $data->{selected_lang_keys} = $selected_langs;
    for my $lang (@$langs) {
      $data->{langs}->{$lang}->{key} = $lang;
      $data->{langs}->{$lang}->{id} = $lang; # XXX
      $data->{langs}->{$lang}->{label} = $lang; # XXX
      $data->{langs}->{$lang}->{label_short} = $lang; # XXX
    }
  })->then (sub {
    my $text_ids = $query->text_ids;
    if (@$text_ids) {
      return {map { $_ => 1 } grep { /\A[0-9a-f]{3,}\z/ } @$text_ids};
    } else {
      return $self->text_ids;
    }
  })->then (sub {
    # XXX
    my $texts = {};
    my @id = keys %{$_[0]};
    my $tag_ors = $query->tag_ors;
    my $tags = $query->tags;
    my $tag_minuses = $query->tag_minuses;
    my $msgids = {map { $_ => 1 } @{$query->msgids}};
    my $words = $query->words;
    my $equals = $query->equals;
    undef $msgids unless keys %$msgids;
    my $p = Promise->resolve;
    for my $id (@id) {
      $p = $p->then (sub { $self->read_file_by_text_id_and_suffix ($id, 'dat') })->then (sub {
        my $te = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0] // '');
        if (defined $msgids) {
          my $mid = $te->get ('msgid');
          return unless defined $mid;
          return unless $msgids->{$mid};
        }
        my $t = $te->enum ('tags');
        for (@$tag_minuses) {
          return if $t->{$_};
        }
        if (@$tag_ors) {
          F: {
            for (@$tag_ors) {
              last F if $t->{$_};
            }
            return;
          } # F
        }
        if (@$tags) {
          for (@$tags) {
            return unless $t->{$_};
          }
        }
        my $entry = $te->as_jsonalizable;
        my @q;
        my $matched = not @$words;
        for my $lang (@$selected_langs) {
          push @q, $self->read_file_by_text_id_and_suffix ($id, $lang . '.txt')->then (sub {
            return unless defined $_[0];
            my $e = TR::TextEntry->new_from_text_id_and_source_text ($id, $_[0]);
            if (@$words) {
              for my $word (@$words) {
                M: {
                  for (qw(body_0 body_1 body_2 body_3 body_4)) {
                    my $value = $e->get ($_) // '';
                    $value =~ s/\s+/ /g;
                    if ($value =~ /\Q$word\E/i) {
                      $matched = 1;
                      last M;
                    }
                  }
                } # M
              }
            }
            $entry->{langs}->{$lang} = $e->as_jsonalizable;
          });
        }
        if ($args{with_comments}) {
          my $comments = $entry->{comments} = [];
          push @q, $self->read_file_by_text_id_and_suffix ($id, 'comments')->then (sub {
            for (grep { length } split /\x0D?\x0A\x0D?\x0A/, $_[0] // '') {
              push @$comments, TR::TextEntry->new_from_text_id_and_source_text ($id, $_)->as_jsonalizable;
            }
          });
        }
        return Promise->all (\@q)->then (sub {
          for my $lang (keys %$equals) {
            my $v = ($entry->{langs}->{$lang} // {})->{body_0} // '';
            unless ($v eq $equals->{$lang}) {
              $matched = 0;
              last;
            }
          }
          $data->{texts}->{$id} = $entry if $matched;
        });
        # XXX limit
      });
    } # $id
    return $p->then (sub {
      return $data;
    });
  });
} # get_data_as_jsonalizable

sub add_by_paths ($$) {
  my ($self, $paths) = @_;
  return Promise->reject ("No file to add") unless @$paths;
  my $repo_path = $self->repo_path;
  return git ($repo_path, 'add', [map { quotemeta $_->relative ($repo_path) } @$paths]);
} # add_by_paths

sub commit ($$) {
  my ($self, $msg) = @_;
  # XXX author/committer
  $msg = ' ' unless length $msg;
  return git ($self->repo_path, 'commit', ['-m', $msg]);
} # commit

sub push ($) {
  my $self = $_[0];
  return git ($self->repo_path, 'push', ['remoterepo']);
} # push

sub discard ($) {
  my $self = $_[0];
  return Promise->new (sub {
    $self->repo_path->remove_tree ({safe => 0});
    $_[0]->();
  });
} # discard

1;
