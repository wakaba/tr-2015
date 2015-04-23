use strict;
use warnings;
use Path::Tiny;
use Encode;
use Digest::SHA qw(sha1_hex);
use JSON::Functions::XS qw(json_bytes2perl perl2json_chars_for_record);
use TR::Langs;
use TR::TextEntry;
use AnyEvent;
use Promised::Command;
use Git::Raw;
use Git::Raw::Branch;
use Git::Raw::Blob;
BEGIN { require 'gitraw.pl' };

sub generate_text_id () {
  return sha1_hex (time () . $$ . rand ());
} # generate_text_id

sub get_msgid_to_text_id_mapping ($$$) {
  my $root_path = path (__FILE__)->parent->parent;
  my $cmd = Promised::Command->new ([
    $root_path->child ('perl'),
    $root_path->child ('bin/dump-textset.pl'),
    $_[0],
    branch => $_[1],
    $_[2],
  ]);
  # XXX no lang data
  $cmd->stdout (\my $json);
  my $cv = AE::cv;
  $cmd->run->then (sub { return $cmd->wait })->then (sub {
    die $_[0] unless $_[0]->exit_code == 0;
    return json_bytes2perl $json;
  })->then (sub {
    my $texts = $_[0]->{texts};
    my $data = {};
    for my $text_id (keys %$texts) {
      my $msgid = $texts->{$text_id}->{msgid};
      if (defined $msgid) {
        $data->{$msgid} = $text_id;
      }
    }
    $cv->send ($data);
  }, sub {
    $cv->croak ($_[0]);
  });
  return $cv->recv;
} # get_msgid_to_text_id_mapping

sub text_id_and_suffix_to_relative_path ($$$) {
  my ($texts_dir, $id, $suffix) = @_;
  my $path = (defined $texts_dir and length $texts_dir)
      ? path ($texts_dir, 'texts') : path ('texts');
  return $path->child ((substr $id, 0, 2) . '/' . (substr $id, 2) . '.' . $suffix);
} # text_id_and_suffix_to_relative_path

sub import_file ($$$$%) {
  my ($root_tree, $repo_dir, $texts_dir, $msgid_to_text_id, %args) = @_;

  my $new_text_ids = {};
  my $modified_text_ids = {};
  my $modified_file_names = {};

  my $touch_msgid = sub ($) {
    my $msgid = $_[0];
    my $text_id = $msgid_to_text_id->{$msgid};
    unless (defined $text_id) {
      $text_id = generate_text_id;
      $msgid_to_text_id->{$msgid} = $text_id;
      $new_text_ids->{$text_id} = $msgid;
      $modified_text_ids->{$text_id} = 1;
    }
    return $text_id;
  }; # $touch_msgid

  my $edit_te = sub ($$$) {
    my ($path, $id, $code) = @_;
    my $file_path = path ($repo_dir)->child ($path);
    my $te = TR::TextEntry->new_from_source_bytes
        (do {
          if ($file_path->is_file) {
            $file_path->slurp;
          } else {
            my $file_entry = $root_tree->entry_bypath ($path);
            if (entry_is_blob $file_entry) {
              $file_entry->content;
            } else {
              '';
            }
          }
        });
    $code->($te) or return;
    $file_path->parent->mkpath;
    $file_path->spew_utf8 ($te->as_source_text);
    $modified_file_names->{$path} = 1;
  }; # $edit_te

  my @added_lang;
  for my $file (@{$args{files}}) {
    warn "|$file->{label}|...";
    my $lang = $file->{lang};
    # XXX format=auto
    if ($file->{format} eq 'po') { # XXX and pot
      my $arg_format = $args{arg_format} || 'printf'; #$arg_format normalization
      $arg_format = 'printf' if $arg_format eq 'auto'; # XXX

      require Popopo::Parser;
      my $parser = Popopo::Parser->new;
      # XXX onerror
      my $es = $parser->parse_string (decode 'utf-8', defined $file->{bytes} ? $file->{bytes} : path ($file->{file_name})->slurp); # XXX charset
      # XXX lang and ohter metadata from header

      die "Bad language key |$lang|" unless TR::Langs::is_lang_key $lang;
      push @added_lang, $lang;

      for my $e (@{$es->entries}) {
        # XXX warn duplicate msgid
        my $text_id = $touch_msgid->($e->msgid);
        my $path = text_id_and_suffix_to_relative_path $texts_dir, $text_id, $lang.'.txt';
        $edit_te->($path, $text_id, sub {
          my $te = $_[0];
          my $current = $te->get ('body_0');
          my $new = $e->msgstr;
          my $modified;
          if (not defined $current or not $current eq $new) {
            $te->set (body_0 => $new);
            $modified = 1;
          }
          # XXX and other fields
          # XXX args
          if ($modified) {
            $te->set (last_modified => time);
            $modified_text_ids->{$text_id} = 1;
          }
          return $modified;
        });
      }
    } elsif ($file->{format} eq 'tr-locations') {
      my $json = json_bytes2perl $file->{bytes};
      if (defined $json and ref $json eq 'HASH') {
        if (defined $json->{msgids} and ref $json->{msgids} eq 'HASH') {
          for my $msgid (keys %{$json->{msgids}}) {
            my $entries = $json->{msgids}->{$msgid};
            next unless (defined $entries and ref $entries eq 'ARRAY');
            next unless @$entries;
            my $new_locs = [map { perl2json_chars_for_record $_ } @$entries]; # XXX no indent

            my $text_id = $touch_msgid->($msgid);
            my $path = text_id_and_suffix_to_relative_path $texts_dir, $text_id, 'dat';
            $edit_te->($path, $text_id, sub {
              my $te = $_[0];
              my $locs = $te->list ('locations');
              my %found;
              @$locs = grep { not $found{$_}++ } @$locs, @$new_locs;
              return 1;
            });
            $modified_text_ids->{$text_id} = 1;
          }
        }
      }
    } else {
      # XXX
      die "Unknown format |$file->{format}|";
    }
  } # $file

  ## Text data
  for my $id (keys %$modified_text_ids) {
    my $path = text_id_and_suffix_to_relative_path $texts_dir, $id, 'dat';
    $edit_te->($path, $id, sub {
      my $te = $_[0];
      my $modified = 0;
      if (defined $new_text_ids->{$id}) {
        $te->set (msgid => $new_text_ids->{$id});
        $modified = 1;
      }
      my $tags = $te->enum ('tags');
      for (@{$args{tags}}) {
        unless ($tags->{$_}) {
          $tags->{$_} = 1;
          $modified = 1;
        }
      }
      return $modified;
    });
  }

  ## Text-set-global data
  {
    my $path = defined $texts_dir ? path ($texts_dir)->child ('texts/config.json') : path ('texts/config.json');
    $edit_te->($path, undef, sub {
      my $te = $_[0];
      my @lang = split /,/, $te->get ('langs') // '';
      my %found;
      $found{$_}++ for @lang;
      push @lang, grep { not $found{$_}++ } @added_lang;
      $te->set (langs => join ',', @lang);
      return 1;
    });
  }

  my @add = keys %$modified_file_names;
  while (@add) {
    my @x = splice @add, 0, 30, ();
    my $cmd = Promised::Command->new (['git', 'add', @x]);
    $cmd->wd ($repo_dir);
    my $cv = AE::cv;
    $cmd->run->then (sub { return $cmd->wait })->then (sub {
      $cv->send;
    }, sub {
      $cv->croak ($_[0]);
    });
    $cv->recv;
  }
} # import_file

sub git_ls_tree ($$;%) {
  my ($repo_dir, $treeish, %args) = @_;
  my $cmd = Promised::Command->new ([
    'git', 'ls-tree',
    ($args{recursive} ? '-r' : ()),
    $treeish,
    @{$args{paths} or []},
  ]);
  $cmd->wd ($repo_dir);
  $cmd->stdout (\my $stdout);
  my $cv = AE::cv;
  $cmd->run->then (sub { return $cmd->wait })->then (sub {
    die $_[0] unless $_[0]->exit_code == 0;
    my $parsed = {items => {}};
    for (split /\x0A/, decode 'utf-8', $stdout) {
      if (/^([0-9]+) (\S+) (\S+)\s+(.+)$/) {
        my $d = {mode => $1, type => $2, object => $3, file => $4};
        $d->{file} =~ s/\\([tn\\])/{t => "\x09", n => "\x0A", "\\" => "\\"}->{$1}/ge;
        $parsed->{items}->{$d->{file}} = $d;
      }
    }
    return $parsed;
  })->then (sub {
    $cv->send ($_[0]);
  }, sub {
    $cv->croak ($_[0]);
  });
  return $cv->recv;
} # git_ls_tree

sub import_auto ($$$$$%) {
  my ($root_tree, $repo_dir, $branch, $texts_dir, $msgid_to_text_id, %args) = @_;

  my $path = defined $texts_dir ? $texts_dir . '/' : '';
  my $data = git_ls_tree ( # XXX
    $repo_dir,
    $branch,
    recursive => 1,
    paths => [defined $texts_dir ? ($texts_dir . '/') : ()],
  );
  my $files = [map { $data->{items}->{$_} } grep { m{\A\Q$path\E.+\.po\z} } keys %{$data->{items}}];
  my $ps = $args{files} = [];
  for my $file (@$files) {
    next unless $file->{type} eq 'blob';
    next if $file->{mode} & 020000; # symlinks
    $file->{file} =~ m{([^/]+)\.po\z};
    my $lang = lc $1; # XXX validation, normalization
    $lang =~ s/_/-/g;
    push @$ps, {
      label => $file->{file},
      bytes => Git::Raw::Blob->lookup ($root_tree->owner, $file->{object})->content,
      lang => $lang,
      format => 'po',
    };
    # XXX create export rule
  } # $file
  return import_file ($root_tree, $repo_dir, $texts_dir, $msgid_to_text_id, %args);
} # import_auto

sub import_by_config ($$$$$$) {
  my ($root_tree, $repo_dir, $texts_dir, $texts_tree, $config, $get_msgid_to_text_id) = @_;
  my $msgid_to_text_id;
  if (defined $config->{import} and ref $config->{import} eq 'ARRAY') {
    for my $rule (@{$config->{import}}) {
      next unless defined $rule and ref $rule eq 'HASH';
      my $file_name = $rule->{file};
      die "XXX |file| not specified" unless defined $file_name;
      my $file_entry = $texts_tree->entry_bypath ($file_name);
      undef $file_entry unless entry_is_blob $file_entry;
      die "XXX |file| |$file_name| not found" unless defined $file_entry;
      $msgid_to_text_id ||= $get_msgid_to_text_id->();
      return import_file (
        $root_tree, $repo_dir, $texts_dir, $msgid_to_text_id,
        files => [{
          label => $rule->{file},
          bytes => $file_entry->object->content,
          format => $rule->{format},
        }],
      );
    }
  }
} # import_by_config

## ------ Main ------

my ($repo_dir, $branch_name, $texts_dir, $json_dir) = @ARGV;
die unless defined $json_dir;
my $json = json_bytes2perl path ($json_dir)->slurp;
undef $texts_dir unless length $texts_dir;
# $repo_dir and $texts_dir must be safe values

my $git_repo = Git::Raw::Repository->open ($repo_dir);
my $git_branch = Git::Raw::Branch->lookup ($git_repo, $branch_name, 1)
    // die "Branch |$branch_name| not found";
my $root_tree = $git_branch->target->tree;

my $from = $json->{from} // '';
if ($from eq 'file') {
  my $msgid_to_text_id = get_msgid_to_text_id_mapping
      ($repo_dir, $branch_name, $texts_dir);
  import_file $root_tree, $repo_dir, $texts_dir, $msgid_to_text_id, %$json;
} elsif ($from eq 'repo') {
  my $msgid_to_text_id = get_msgid_to_text_id_mapping
      ($repo_dir, $branch_name, $texts_dir);
  import_auto $root_tree, $repo_dir, $branch_name, $texts_dir, $msgid_to_text_id, %$json;
} elsif ($from eq 'config') {
  my $texts_tree = get_texts_tree $git_branch, $texts_dir; # or undef
  my $config = get_texts_config $texts_tree; # XXX search working directory first
  import_by_config $root_tree, $repo_dir, $texts_dir, $texts_tree, $config, sub {
    return get_msgid_to_text_id_mapping
        ($repo_dir, $branch_name, $texts_dir);
  };
} else {
  die "Unknown |from|: |$from|";
}
