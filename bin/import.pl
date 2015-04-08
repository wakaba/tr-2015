use strict;
use warnings;
use Path::Tiny;
use Encode;
use Digest::SHA qw(sha1_hex);
use JSON::Functions::XS qw(json_bytes2perl);
use TR::Langs;
use TR::TextEntry;
use AnyEvent;
use Promised::Command;

sub generate_text_id () {
  return sha1_hex (time () . $$ . rand ());
} # generate_text_id

sub get_msgid_to_text_id_mapping ($$$) {
  my $root_path = path (__FILE__)->parent->parent;
  my $cmd = Promised::Command->new ([
    $root_path->child ('perl'),
    $root_path->child ('bin/dump-textset.pl'),
    $_[0],
    $_[1],
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

sub checkout_a_file ($$) {
  my ($repo_dir, $path) = @_;
  return if path ($repo_dir)->child ($path)->is_file;
  my $cv = AE::cv;
  my $cmd = Promised::Command->new (['git', 'checkout', '--', $path]);
  $cmd->wd ($repo_dir);
  $cmd->run->then (sub { return $cmd->wait })->then (sub {
    # error: pathspec '...' did not match any file(s) known to git.
    return if $_[0]->exit_code == 1;
    die $_[0] unless $_[0]->exit_code == 0;
  })->then (sub {
    $cv->send;
  }, sub {
    $cv->croak ($_[0]);
  });
  return $cv->recv;
} # checkout_a_file

sub import_file ($$$%) {
  my ($repo_dir, $texts_dir, $msgid_to_text_id, %args) = @_;

  my $new_text_ids = {};
  my $modified_text_ids = {};
  my $modified_file_names = {};

  my $edit_te = sub ($$$) {
    my ($path, $id, $code) = @_;
    checkout_a_file $repo_dir, $path;
    my $file_path = path ($repo_dir)->child ($path);
    my $te = TR::TextEntry->new_from_text_id_and_source_bytes
        ($id, $file_path->is_file ? $file_path->slurp : '');
    $code->($te);
    $file_path->parent->mkpath;
    $file_path->spew_utf8 ($te->as_source_text);
    $modified_file_names->{$path} = 1;
  }; # $edit_te

  my @added_lang;
  for my $file (@{$args{files}}) {
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
        my $id = $msgid_to_text_id->{$e->msgid};
        unless (defined $id) {
          $id = generate_text_id;
          $msgid_to_text_id->{$e->msgid} = $id;
          $new_text_ids->{$id} = $e->msgid;
          $modified_text_ids->{$id} = 1;
        }
        my $path = text_id_and_suffix_to_relative_path $texts_dir, $id, $lang.'.txt';
        $edit_te->($path, $id, sub {
          my $te = $_[0];
          my $current = $te->get ('body_0');
          my $new = $e->msgstr;
          my $modified;
          if (not defined $current or not $current eq $new) {
            $te->set (body_0 => $new);
            $modified = 1;
          }
          if ($modified) {
            $te->set (last_modified => time);
            $modified_text_ids->{$id} = 1;
          }
          # XXX and other fields
          # XXX args
        });
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
      $te->set (msgid => $new_text_ids->{$id}) if defined $new_text_ids->{$id};
      $te->enum ('tags')->{$_} = 1 for @{$args{tags}};
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

sub git_show ($$) {
  my ($repo_dir, $obj) = @_;
  my $cmd = Promised::Command->new (['git', 'show', $obj]);
  $cmd->wd ($repo_dir);
  $cmd->stdout (\my $stdout);
  my $cv = AE::cv;
  $cmd->run->then (sub { return $cmd->wait })->then (sub {
    die $_[0] unless $_[0]->exit_code == 0;
    $cv->send ($stdout);
  }, sub {
    $cv->croak ($_[0]);
  });
  return $cv->recv;
} # git_show

sub import_auto ($$$$%) {
  my ($repo_dir, $branch, $texts_dir, $msgid_to_text_id, %args) = @_;

  my $path = defined $texts_dir ? $texts_dir . '/' : '';
  my $data = git_ls_tree (
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
    warn "XXX importing |$file->{file}|...\n";
    push @$ps, {
      bytes => git_show ($repo_dir, $file->{object}),
      lang => $lang,
      format => 'po',
    };
  } # $file
  return import_file ($repo_dir, $texts_dir, $msgid_to_text_id, %args);
} # import_auto

## ------ Main ------

my ($repo_dir, $branch, $texts_dir, $json_dir) = @ARGV;
die unless defined $json_dir;
my $json = json_bytes2perl path ($json_dir)->slurp;
undef $texts_dir unless length $texts_dir;

my $from = $json->{from} // '';
if ($from eq 'file') {
  my $msgid_to_text_id = get_msgid_to_text_id_mapping ($repo_dir, $branch, $texts_dir);
  import_file $repo_dir, $texts_dir, $msgid_to_text_id, %$json;
} elsif ($from eq 'repo') {
  my $msgid_to_text_id = get_msgid_to_text_id_mapping ($repo_dir, $branch, $texts_dir);
  import_auto $repo_dir, $branch, $texts_dir, $msgid_to_text_id, %$json;
} else {
  die "Unknown |from|: |$from|";
}
