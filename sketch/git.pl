use strict;
use warnings;
use Path::Tiny;
use AnyEvent;
use TR::TextRepo;

my $global = AE::cv;

my $temp_path = path ('local/tmp');
my $url = shift or die;

my $tr = TR::TextRepo->new_from_temp_path ($temp_path);
$tr->texts_dir ('hoge/fuga');
$tr->clone_by_url ($url)->then (sub {
  my $id = $tr->generate_text_id;
  $tr->write_file_by_text_id_and_suffix ($id, 'ja.txt' => qq<\x{6000}abc>);
})->then (sub {
  $tr->text_ids->then (sub {
    warn join "\n", keys %{$_[0]};
  });
})->then (sub {
  $tr->commit ('test');
})->then (sub {
  $tr->push;
})->then (sub {
  warn "ok";
  warn $tr->repo_path;
}, sub {
  warn "ng $_[0]";
})->then (sub {
  return $tr->discard;
})->catch (sub {
  warn $_[0];
})->then (sub {
  $global->send;
});

$global->recv;
