use strict;
use warnings;
use Path::Tiny;
use JSON::Functions::XS qw(json_bytes2perl perl2json_bytes);
use Git::Raw::Repository;
use Git::Raw::Branch;
use AnyEvent;
use Promised::Command;

sub get_dump ($$$$) {
  my $root_path = path (__FILE__)->parent->parent;
  my $cmd = Promised::Command->new ([
    $root_path->child ('perl'),
    $root_path->child ('bin/dump-textset.pl'),
    $_[0],
    $_[1],
    $_[2],
  ]);
  my $query = $_[3];
  $cmd->stdout (\my $json);
  my $cv = AE::cv;
  $cmd->run->then (sub { return $cmd->wait })->then (sub {
    die $_[0] unless $_[0]->exit_code == 0;
    return json_bytes2perl $json;
  })->then (sub {
    # XXX filtering by $query
    $cv->send ($_[0]);
  }, sub {
    $cv->croak ($_[0]);
  });
  return $cv->recv;
} # get_dump

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

my $texts_tree = $root_tree;
if (defined $texts_dir) {
  my $texts_entry = $root_tree->entry_bypath ($texts_dir);
  if (defined $texts_entry and $texts_entry->object->is_tree) {
    $texts_tree = $texts_entry->object;
  } else {
    $texts_tree = undef;
  }
}

my $config = {};
if (defined $texts_tree) {
  my $config_entry = $texts_tree->entry_bypath ('texts.json');
  if (defined $config_entry and $config_entry->object->is_blob and
      not $config_entry->file_mode & 020000) { # symlink
    $config = json_bytes2perl $config_entry->object->content;
    undef $config if defined $config and not ref $config eq 'HASH';
  }
}

my $modified_file_names = {};
my $data = {};
my $export = $config->{export};
if (defined $export and ref $export eq 'ARRAY') {
  for my $rule (@$export) {
    next unless ref $rule eq 'HASH';

    # {lang => $lang_key, format => $format, arg_format => $arg_format,
    #  query => $query,
    #  file_template => $file_name_template}
    # XXX lang => undef = auto

    $data->{$rule->{query} // ''} ||= do {
      require TR::Query;
      my $q = TR::Query->parse_query (query => $rule->{query});
      get_dump $repo_dir, $branch_name, $texts_dir, $rule->{query};
    };

    if (($rule->{format} // '') eq 'po') {
      my $json = $data->{$rule->{query} // ''};
      my $lang = $rule->{lang} // die "|lang| not specified"; # XXX validation?

      # XXX
      my $arg_format = $rule->{arg_format} // '';
      $arg_format ||= 'printf'; #$arg_format normalization
      $arg_format = 'printf' if $arg_format eq 'auto';

            require Popopo::Entry;
            require Popopo::EntrySet;
            my $es = Popopo::EntrySet->new;
            my $header = $es->get_or_create_header;
            # XXX $header
            for my $text_id (keys %{$json->{texts} or {}}) {
              my $text = $json->{texts}->{$text_id};
              my $msgid = $text->{msgid};
              next unless defined $msgid; # XXX fallback option?
              my $str = $text->{langs}->{$lang}->{body_0} // '';
              my $args = {};
              my $i = 0;
              for my $arg_name (@{$text->{args} or []}) {
                $i++;
                $args->{$arg_name} = {index => $i, name => $arg_name};
              }
              # XXX $app->text_param ('preserve_html')
              # XXX $app->text_param ('no_fallback')
              my @str;
              for (split /(\{[^{}]+\})/, $str, -1) {
                if (/\A\{([^{}]+)\}\z/) {
                  my $arg = $args->{$1};
                  if ($arg) {
                    if ($arg_format eq 'braced') {
                      push @str, '{' . $arg->{name} . '}';
                    } elsif ($arg_format eq 'printf') {
                      push @str, '%'.$arg->{index}.'$s'; # XXX
                    } elsif ($arg_format eq 'percentn') {
                      push @str, '%' . $arg->{index};
                    }
                  } else {
                    push @str, $_;
                  }
                } else {
                  if ($arg_format eq 'printf' or $arg_format eq 'percentn') {
                    s/%/%%/g;
                  }
                  push @str, $_;
                }
              }
              $str = join '', @str;
              my $e = Popopo::Entry->new
                  (msgid => $msgid,
                   msgstrs => [$str]);
              # XXX more props
              $es->add_entry ($e);
            }

      my $file_name = $rule->{file_template} // die "|file_template| is not specified";
      $file_name =~ s/\{lang\}/$lang/g;

      my $repo_path = path ($repo_dir);
      my $file_path = (defined $texts_dir ? path ($texts_dir) : path ('.'))
          ->child ('texts', $file_name); # XXX validation
      my $path = $repo_path->child ($file_path);
      $path->parent->mkpath; # or die XXX
      $path->spew_utf8 ($es->stringify); # or die XXX
      $modified_file_names->{$file_path} = 1;

      # XXX "PO-Revision-Date should be max(last_modified)

    } else {
      die "XXX unknown format |$rule->{format}|";
    }
  } # $rule
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
