package TR::TextRepo;
use strict;
use warnings;
use Path::Tiny;
use JSON::Functions::XS qw(json_bytes2perl perl2json_bytes);
use Encode;
use Promise;
use Promised::Command;
use Promised::File;
use Digest::SHA qw(sha1_hex);
use Wanage::URL;
use TR::Langs;
use TR::TextEntry;
use TR::Git;
use TR::GitBareRepository;
use TR::GitWorkingTree;

sub new_from_mirror_and_temp_path ($$$) {
  return bless {mirror_path => $_[1], temp_path => $_[2]}, $_[0];
} # new_from_mirror_and_temp_path

sub url ($;$) {
  if (@_ > 1) {
    $_[0]->{url} = $_[1];
  }
  return $_[0]->{url};
} # url

sub mapped_url ($;$) {
  if (@_ > 1) {
    $_[0]->{mapped_url} = $_[1];
  }
  return $_[0]->{mapped_url} // $_[0]->{url};
} # mapped_url

sub repo_type ($;$) {
  if (@_ > 1) {
    $_[0]->{repo_type} = $_[1];
  }
  return $_[0]->{repo_type};
} # repo_type

sub config ($;$) {
  if (@_ > 1) {
    $_[0]->{config} = $_[1];
  }
  return $_[0]->{config};
} # config

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
  return $_[0]->{mirror_repo_path} // die "mirror_repo_path is not set yet";
} # mirror_repo_path

sub mirror_repo ($) {
  return $_[0]->{mirror_repo} ||= TR::GitBareRepository->new_from_dir_name ($_[0]->mirror_repo_path);
} # mirror_repo

sub repo_path ($) {
  return $_[0]->{repo_path} ||= $_[0]->{temp_path}->child ('text-repo-' . rand);
} # repo_path

sub repo ($) {
  return $_[0]->{repo} ||= TR::GitWorkingTree->new_from_dir_name ($_[0]->repo_path);
} # repo

sub lock ($) {
  my $self = $_[0];
  my $lock_dir_path = $self->mirror_parent_path->child ('lock');
  my $lock_path = $lock_dir_path->child ($self->path_name);
  return Promised::File->new_from_path ($lock_dir_path)->mkpath->then (sub {
    return lock_repo ($lock_path, 60);
  });
} # lock

sub home_path ($) {
  return $_[0]->{home_path} ||= $_[0]->{temp_path}->child ('home-' . rand);
} # home_path

sub texts_dir ($;$) {
  if (@_ > 1) {
    $_[0]->{texts_dir} = $_[1];
    delete $_[0]->{texts_dir} unless defined $_[0]->{texts_dir} and length $_[0]->{texts_dir};
  }
  return $_[0]->{texts_dir};
} # texts_dir

sub texts_path ($) {
  return $_[0]->{texts_path} ||= do {
    my $p = $_[0]->repo_path;
    $p = $p->child ($_[0]->{texts_dir}) if defined $_[0]->{texts_dir};
    $p->child ('texts');
  };
} # texts_path

sub remote_viewer_url ($) {
  my $self = $_[0];
  my $repo_type = $self->repo_type;
  if ($repo_type eq 'github') {
    my $url = $self->url; # https://github.com/{user}/{repo}
    $url .= '/tree/' . percent_encode_c ($self->branch);
    $url .= '/' . ($self->texts_dir // '/');
    return $url;
  } else {
    return undef;
  }
} # remote_viewer_url

sub prepare_mirror ($$$) {
  my ($self, $keys, $app) = @_;
  my $p = Promise->resolve;
  die if $self->{fetched} and defined $keys->{access_token};
  return $p if $self->{fetched};

  $p = $p->then (sub {
    $app->send_progress_json_chunk ('Waiting for another operation on the repository...');
    return $self->lock;
  })->then (sub {
    $self->{lock} = $_[0];
  });

  my $home_path = $self->home_path;

  my $mirror_path = $self->mirror_parent_path;
  $mirror_path = $mirror_path->child ('private') if $keys->{requires_token_for_pull};
  $mirror_path = $mirror_path->child ($self->path_name);
  $self->{mirror_repo_path} = $mirror_path;

  my $url2 = my $url = $self->mapped_url;
  my $repo_type = $self->repo_type;
  if ($repo_type eq 'github') {
    if (defined $keys->{access_token}) {
      my $user = percent_encode_c $keys->{access_token};
      $url2 =~ s{^https://github.com/}{https://$user:\@github.com/};
    }
  } elsif ($repo_type eq 'ssh') {
    $self->{private_key_path} = $home_path->child ('key');
    $self->{ssh_path} = path (__FILE__)->parent->parent->parent->child ('bin/ssh_wrapper');
    $p = $p->then (sub {
      return Promised::File->new_from_path ($self->{private_key_path})
          ->write_byte_string ($keys->{access_token}->[1] // '');
    })->then (sub {
      # XXX
      my $cmd = Promised::Command->new (['chmod', '0600', $self->{private_key_path}]);
      return $cmd->run->then (sub { return $cmd->wait });
    });
  } elsif ($repo_type eq 'file-public') {
    #
  } elsif ($repo_type eq 'file-private') {
    #
  } else {
    die "Unknown repository type |$repo_type|";
  }
  unless ($url eq $url2) {
    if ($keys->{requires_token_for_pull}) {
      $self->{keyed_url_for_pull} = $url2;
    }
    $self->{keyed_url_for_push} = $url2;
  }

  my $name = $keys->{name} // '';
  $name = $keys->{account_id} // 'unknown' unless length $name;
  my $email = $self->config->get ('git.author.email_pattern');
  $email =~ s{\{account_id\}}{$keys->{account_id} // ''}ge;
  $self->{author_name} = $name;
  $self->{author_email} = $email;

  my $keyed_url = $self->{keyed_url_for_pull};
  if (defined $keyed_url) {
    $p = $p->then (sub {
      return git_home_config ($home_path, ["url.$keyed_url.insteadOf", $url]);
    });
  }
  my $branch = $self->branch;
  if ($mirror_path->child ('config')->is_file) {
    my $mirror_repo = $self->mirror_repo;
    $mirror_repo->home_dir_name ($home_path);
    $mirror_repo->ssh_file_name ($self->{ssh_path});
    $mirror_repo->ssh_private_key_file_name ($self->{private_key_path});
    $p = $p->then (sub {
      $app->send_progress_json_chunk ('Fetching the remote repository...');
      # XXX skip if guest access
      return $mirror_repo->fetch;
    })->then (sub {
      $self->{fetched} = 1;
      $mirror_repo->home_dir_name (undef);
      $mirror_repo->ssh_file_name (undef);
      $mirror_repo->ssh_private_key_file_name (undef);
    });
  } else {
    $p = $p->then (sub {
      $app->send_progress_json_chunk ('Cloning the remote repository...');
      return git_clone (['--mirror',
                         (defined $branch ? ('-b', $branch) : ()),
                         $url, $mirror_path],
                        home => $home_path,
                        ssh => $self->{ssh_path},
                        ssh_private_key => $self->{private_key_path});
    })->then (sub {
      $self->{fetched} = 1;
    });
  }
  if (defined $branch) {
    $p = $p->then (sub {
      return $self->get_branches ($branch);
    })->then (sub {
      die {bad_branch => 1} unless $_[0]->{branches}->{$branch};
    });
  }
  return $p;
} # prepare_mirror

sub clone_from_mirror ($;%) {
  my ($self, %args) = @_;
  my $p = git_clone ([
    '-b', $self->branch,
    ($args{no_checkout} ? '-n' : ()),
    $self->mirror_repo_path, $self->repo_path,
  ]);
  if ($args{no_checkout}) {
    my $repo = $self->repo;
    $p = $p->then (sub {
      return $repo->git ('reset', ['HEAD']);
    });
  }
  if ($args{push}) {
    my $repo = $self->repo;
    $repo->home_dir_name ($self->home_path);
    $repo->ssh_file_name ($self->{ssh_path});
    $repo->ssh_private_key_file_name ($self->{private_key_path});
    my $keyed_url = $self->{keyed_url_for_push} // $self->mapped_url;
    $p = $p->then (sub {
      return $repo->git ('remote', ['add', 'remoterepo', $keyed_url]);
    });
  }
  return $p;
} # clone_from_mirror

sub get_branches ($;$) {
  my ($self, $name) = @_;
  return $self->mirror_repo->git ('branch',
    ['-v', '--no-abbrev', '--list', '--', (defined $name ? $name : ())],
    timeout => 2,
  )->then (sub {
    my $result = $_[0];
warn "then";
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
  return ((@$commits ? $self->mirror_repo->git ('show', ['--raw', '--format=raw', @$commits, '--']) : Promise->resolve ({stdout => ''}))->then (sub {
    my $result = $_[0];
    require Git::Parser::Log;
    return Git::Parser::Log->parse_format_raw (decode 'utf-8', $result->{stdout});
  }));
} # get_commit_logs

sub get_logs_by_path ($$;%) {
  my ($self, $path, %args) = @_;
  return $self->mirror_repo->log (
    limit => $args{limit},
    range => $self->branch,
    paths => [$path],
  );
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
  my ($self, $treeish, %args) = @_;
  return $self->mirror_repo->git ('ls-tree', [
    ($args{recursive} ? '-r' : ()),
    $treeish,
    @{$args{paths} or []},
  ])->then (sub {
    my $result = $_[0];
    my $parsed = {items => {}};
    for (split /\x0A/, decode 'utf-8', $result->{stdout}) {
      if (/^([0-9]+) (\S+) (\S+)\s+(.+)$/) {
        my $d = {mode => $1, type => $2, object => $3, file => $4};
        $d->{file} =~ s/\\([tn\\])/{t => "\x09", n => "\x0A", "\\" => "\\"}->{$1}/ge;
        $parsed->{items}->{$d->{file}} = $d;
      }
    }
    return $parsed;
  });
} # get_ls_tree

sub get_recent_comments ($;%) {
  my ($self, %args) = @_;
  my $mirror_repo = $self->mirror_repo;
  return $mirror_repo->log (
    limit => $args{limit},
    paths => [$self->comment_path_pattern],
  )->then (sub {
    my $json = {texts => []};
    my $p = Promise->resolve;
    my %id_found;
    for my $commit (@{$_[0]->{commits}}) {
      for my $comments_file_name (keys %{$commit->{files}}) {
        $comments_file_name =~ m{([^/]+)/([^/]+)\.comments\z} or next;
        my $id = $1.$2;
        next if $id_found{$id}++;
        my $dat_file_name = $comments_file_name;
        $dat_file_name =~ s/\.comments\z/.dat/;
        $p = $p->then (sub {
          return $mirror_repo->show_blob_by_path ($commit->{tree}, $dat_file_name);
        })->then (sub {
          my $te = TR::TextEntry->new_from_source_bytes ($_[0] // '');
          my $entry = $te->as_jsonalizable;
          push @{$json->{texts}}, $entry;
          my $comments = $entry->{comments} = [];
          return $mirror_repo->show_blob_by_path ($commit->{tree}, $comments_file_name)->then (sub {
            for (grep { length } split /\x0D?\x0A\x0D?\x0A/, $_[0] // '') {
              push @$comments, TR::TextEntry->new_from_source_bytes ($_)->as_jsonalizable;
            }
          });
        });
      } # $file
    } # $commit
    return $p->then (sub { $json });
  });
} # get_recent_comments

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

sub comment_path_pattern ($$$) {
  my ($self) = @_;
  my $path = (defined $self->{texts_dir} and length $self->{texts_dir})
      ? path ($self->{texts_dir}, 'texts') : path ('texts');
  return $path->child ('*/*.comments');
} # comment_path_pattern

sub git_log_for_text_id_and_lang ($$$;%) {
  my ($self, $id, $lang, %args) = @_;
  my $rel_path = $self->text_id_and_suffix_to_relative_path ($id, $lang . '.txt');
  my $mirror_repo = $self->mirror_repo;
  my $p = $mirror_repo->log (
    range => $self->branch,
    paths => [$rel_path],
  );

  if ($args{with_file_text}) {
    $p = $p->then (sub {
      my $parsed = $_[0];
      my $q = Promise->resolve;
      for my $commit (@{$parsed->{commits}}) {
        $q = $q->then (sub {
          return $mirror_repo->show_blob_by_path ($commit->{tree}, $rel_path);
        })->then (sub {
          my $result = $_[0] // '';
          $commit->{blob_data} = $result;
        });
      } # $commit
      # XXX removed text
      return $q->then (sub { return $parsed });
    });
  }

  return $p;
} # git_log_for_text_id_and_lang

sub write_file_by_path ($$$) {
  my ($self, $path) = @_;
  $path->parent->mkpath;
  $path->spew_utf8 ($_[2]); # or exception # XXX blocking I/O
  return $self->add_by_paths ([$path]);
} # write_file_by_path

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

sub get_tr_config ($) {
  my $self = $_[0];
  my $dir = $self->{texts_dir};
  $dir = defined $dir ? "$dir/texts" : 'texts';
  return $self->mirror_repo->show_blob_by_path ($self->branch, "$dir/config.json")->then (sub {
    return TR::TextEntry->new_from_source_bytes ($_[0] // '');
  });
} # get_tr_config

sub get_data_as_jsonalizable ($%) {
  my ($self, $query, $selected_lang_list, %args) = @_;
  my $data = {};
  my $selected_langs = {};
  return $self->get_tr_config->then (sub {
    my $tr_config = $_[0];
    my %found;
    my $langs = [grep { not $found{$_}++ } grep { length } split /,/, $tr_config->get ('langs') // 'en'];
    if (@$selected_lang_list) {
      my $avail_langs = {map { $_ => 1 } @$langs};
      my %found;
      @$selected_lang_list = grep { not $found{$_}++ } grep { $avail_langs->{$_} } @$selected_lang_list;
    } else {
      $selected_lang_list = $langs;
    }

    $data->{selected_lang_keys} = $selected_lang_list;
    $selected_langs->{$_} = 1 for @$selected_lang_list;
    for my $lang (@$langs) {
      $data->{langs}->{$lang}->{key} = $lang;
      $data->{langs}->{$lang}->{id} = $lang; # XXX
      $data->{langs}->{$lang}->{label} = $lang; # XXX
      $data->{langs}->{$lang}->{label_short} = $lang; # XXX
    }
    my $root_path = path (__FILE__)->parent->parent->parent;
    my $cmd = Promised::Command->new ([
      $root_path->child ('perl'),
      $root_path->child ('bin/dump-textset.pl'),
      $self->mirror_repo_path,
      'branch',
      $self->branch,
      $self->{texts_dir} // '',
    ]);
    $cmd->envs->{WITH_COMMENTS} = 1 if $args{with_comments};
    $cmd->stdout (\my $json);
    return $cmd->run->then (sub { return $cmd->wait })->then (sub {
      die $_[0] unless $_[0]->exit_code == 0;
      return json_bytes2perl $json;
    });
  })->then (sub {
    my $all_texts = $_[0]->{texts};
    my $selected_texts = {};

    if (@{$query->text_ids}) {
      my $texts = {};
      for my $text_id (@{$query->text_ids}) {
        $texts->{$text_id} = $all_texts->{$text_id} if defined $all_texts->{$text_id};
      }
      $all_texts = $texts;
    }

    my $msgids = {map { $_ => 1 } @{$query->msgids}};
    undef $msgids unless keys %$msgids;
    my $tag_ors = $query->tag_ors;
    my $tags = $query->tags;
    my $tag_minuses = $query->tag_minuses;
    my $words = $query->words;
    my $equals = $query->equals;
    TEXT: for my $text_id (keys %$all_texts) {
      my $text = $all_texts->{$text_id};

      if (defined $msgids) {
        next TEXT if not defined $text->{msgid};
        next TEXT if not $msgids->{$text->{msgid}};
      }

      my $t = {map { $_ => 1 } @{$text->{tags} || []}};
      for (@$tag_minuses) {
        next TEXT if $t->{$_};
      }
      if (@$tag_ors) {
        F: {
          for (@$tag_ors) {
            last F if $t->{$_};
          }
          next TEXT;
        } # F
      }
      for (@$tags) {
        next TEXT unless $t->{$_};
      }

      my @all_lang = keys %{$text->{langs} or {}};
      for (@all_lang) {
        delete $text->{langs}->{$_} unless $selected_langs->{$_};
      }

      WORD: for my $word (@$words) {
        for my $lang (keys %{$text->{langs} or {}}) {
          for (qw(body_0 body_1 body_2 body_3 body_4)) {
            my $value = $text->{langs}->{$lang}->{$_} // '';
            $value =~ s/\s+/ /g;
            if ($value =~ /\Q$word\E/i) {
              next WORD;
            }
          }
        }
        next TEXT;
      } # $words

      for my $lang (keys %$equals) {
        my $v = ($text->{langs}->{$lang} // {})->{body_0} // '';
        unless ($v eq $equals->{$lang}) {
          next TEXT;
        }
      }

      $selected_texts->{$text_id} = $text;
    } # TEXT

    $data->{texts} = $selected_texts;
    return $data;
  });
} # get_data_as_jsonalizable

sub run_import ($%) {
  my ($self, %args) = @_;
  my $json_path = $self->{temp_path}->child ('import-'.rand.'.json');
  my $json_file = Promised::File->new_from_path ($json_path);
  return $json_file->write_byte_string (perl2json_bytes \%args)->then (sub {
    my $root_path = path (__FILE__)->parent->parent->parent;
    my $cmd = Promised::Command->new ([
      $root_path->child ('perl'),
      $root_path->child ('bin/import.pl'),
      $self->repo_path,
      $self->branch,
      $self->{texts_dir} // '',
      $json_path,
    ]);
    return $cmd->run->then (sub { return $cmd->wait });
  })->then (sub {
    my $result = $_[0];
    die $result unless $result->exit_code == 0;
  });
} # run_import

sub run_export ($%) {
  my ($self, %args) = @_;
  my $json_path = $self->{temp_path}->child ('export-'.rand.'.json');
  my $json_file = Promised::File->new_from_path ($json_path);
  my $onerror = delete $args{onerror};
  return $self->_run_add->then (sub {
    return $json_file->write_byte_string (perl2json_bytes \%args);
  })->then (sub {
    my $root_path = path (__FILE__)->parent->parent->parent;
    my $cmd = Promised::Command->new ([
      $root_path->child ('perl'),
      $root_path->child ('bin/export.pl'),
      $self->repo_path,
      $self->{texts_dir} // '',
      $json_path,
    ]);
    my $emit_progress = sub {
      my $input = $_[0];
      if ($input =~ /\S/) {
        my $json = json_bytes2perl $input;
        if (defined $json and ref $json eq 'HASH') {
          # XXX error log?
          if (defined $json->{error} and defined $json->{status}) {
            $onerror->($json);
          }
          # XXX progress
        }
      }
    };
    my $stdout = '';
    $cmd->stdout (sub {
      if (defined $_[0]) {
        $stdout .= $_[0];
        while ($stdout =~ s/^([^\x0A]*)\x0A//) {
          $emit_progress->($1);
        }
      } else {
        while ($stdout =~ s/^([^\x0A]*)\x0A//) {
          $emit_progress->($stdout);
        }
        $emit_progress->($stdout);
      }
    });
    return $cmd->run->then (sub { return $cmd->wait });
  })->then (sub {
    my $result = $_[0];
    die $result unless $result->exit_code == 0;
  });
} # run_export

sub add_by_paths ($$) {
  my ($self, $paths) = @_;
  return Promise->reject ("No file to add") unless @$paths;
  my $repo_path = $self->repo_path;
  $self->{git_add}->{$_} = 1 for map { $_->relative ($repo_path) } @$paths;
  return Promise->resolve;
} # add_by_paths

sub _run_add ($) {
  my $self = $_[0];
  my $p = Promise->resolve;
  my @add = keys %{$self->{git_add} or {}};
  while (@add) {
    my @x = splice @add, 0, 30, ();
    $p = $p->then (sub { return $self->repo->git ('add', \@x) });
  }
  delete $self->{git_add};
  return $p;
} # _run_add

sub commit ($$) {
  my ($self, $msg) = @_;
  $msg = ' ' unless length $msg;
  return $self->_run_add->then (sub {
    return $self->repo->commit (
      message => $msg,
      author_email => $self->{author_email}, # set by $self->prepare_mirror
      author_name => $self->{author_name}, # set by $self->prepare_mirror
      committer_email => $self->config->get ('git.committer.email'),
      committer_name => $self->config->get ('git.committer.name'),
    );
  });
} # commit

sub push ($) {
  my $self = $_[0];
  return $self->repo->git ('push', ['remoterepo', $self->branch]);
} # push

sub discard ($) {
  my $self = $_[0];
  close $self->{lock} if defined $self->{lock};
  return Promise->all ([
    Promised::File->new_from_path ($self->repo_path)->remove_tree,
    Promised::File->new_from_path ($self->home_path)->remove_tree,
  ]);
} # discard

1;
