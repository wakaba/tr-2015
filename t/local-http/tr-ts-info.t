use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/lib');
use Tests;

my $wait = web_server;

# XXX repo errors
# XXX permission errors

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'dummy' => '',
    })->then (sub {
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'master', '/', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        is $json->{url}, $url;
        is $json->{branch}, 'master';
        is $json->{texts_path}, '/';
        eq_or_diff $json->{avail_lang_keys}, ['en'];
        is $json->{langs}->{en}->{key}, 'en';
        is $json->{langs}->{en}->{id}, 'en';
        is $json->{langs}->{en}->{label}, 'en';
        is $json->{langs}->{en}->{label_short}, 'en';
        is $json->{langs}->{en}->{label_raw}, undef;
        is $json->{langs}->{en}->{label_short_raw}, undef;
        is $json->{license}->{type}, undef;
        is $json->{preview_url_template}, undef;
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 13, name => 'no config.json';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'texts/config.json' => perl2json_bytes +{
        avail_lang_keys => ['fr', 'it', 'it', {}, undef, 12, '--', 'FO'],
        langs => {
          fr => {desc => 'fr', id => 'fr-fr'},
          '12' => {id => 'en'},
          es => {desc => 'Spanish'},
        },
        license => {type => 'hoge'},
      },
    })->then (sub {
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'master', '/', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        eq_or_diff $json->{avail_lang_keys}, ['fr', 'it', '12'];
        is $json->{langs}->{fr}->{key}, 'fr';
        is $json->{langs}->{12}->{key}, '12';
        is $json->{langs}->{es}->{key}, undef;
        is $json->{langs}->{en}->{key}, undef;
        is $json->{langs}->{fo}->{key}, undef;
        is $json->{langs}->{FO}->{key}, undef;
        is $json->{license}->{type}, 'hoge';
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 9, name => 'has config.json';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'texts/config.json' => perl2json_bytes +{
        avail_lang_keys => 'en,ja',
        langs => 'en=ja',
        license => 12,
      },
    })->then (sub {
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'master', '/', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        eq_or_diff $json->{avail_lang_keys}, ['en'];
        is $json->{langs}->{en}->{key}, 'en';
        is $json->{langs}->{en}->{id}, 'en';
        is $json->{langs}->{en}->{label}, 'en';
        is $json->{langs}->{en}->{label_short}, 'en';
        is $json->{langs}->{en}->{label_raw}, undef;
        is $json->{langs}->{en}->{label_short_raw}, undef;
        is $json->{license}->{type}, undef;
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 9, name => 'broken config.json';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'hoge/fuga/texts/config.json' => perl2json_bytes +{
        avail_lang_keys => ['fr', 'it', 'it', {}, undef, 12, '--', 'FO'],
        langs => {
          fr => {desc => 'fr', id => 'fr-fr'},
          '12' => {id => 'en'},
          es => {desc => 'Spanish'},
        },
        license => {type => 'hoge'},
      },
    })->then (sub {
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'master', '/hoge/fuga', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        is $json->{url}, $url;
        is $json->{branch}, 'master';
        is $json->{texts_path}, '/hoge/fuga';
        eq_or_diff $json->{avail_lang_keys}, ['fr', 'it', '12'];
        is $json->{langs}->{fr}->{key}, 'fr';
        is $json->{langs}->{12}->{key}, '12';
        is $json->{langs}->{es}->{key}, undef;
        is $json->{langs}->{en}->{key}, undef;
        is $json->{langs}->{fo}->{key}, undef;
        is $json->{langs}->{FO}->{key}, undef;
        is $json->{license}->{type}, 'hoge';
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 12, name => 'deep text set, has config.json';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'hoge/fuga/texts/config.json' => perl2json_bytes +{
        avail_lang_keys => ['fr', 'it', 'it', {}, undef, 12, '--', 'FO'],
        langs => {
          fr => {desc => 'fr', id => 'fr-fr'},
          '12' => {id => 'en'},
          es => {desc => 'Spanish'},
        },
        license => {type => 'hoge'},
      },
    }, branch => 'foo')->then (sub {
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'foo', '/hoge/fuga', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        is $json->{url}, $url;
        is $json->{branch}, 'foo';
        is $json->{texts_path}, '/hoge/fuga';
        eq_or_diff $json->{avail_lang_keys}, ['fr', 'it', '12'];
        is $json->{langs}->{fr}->{key}, 'fr';
        is $json->{langs}->{12}->{key}, '12';
        is $json->{langs}->{es}->{key}, undef;
        is $json->{langs}->{en}->{key}, undef;
        is $json->{langs}->{fo}->{key}, undef;
        is $json->{langs}->{FO}->{key}, undef;
        is $json->{license}->{type}, 'hoge';
        is $json->{preview_url_template}, undef;
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 13, name => 'branched, deep text set, has config.json';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'hoge/fuga/texts/config.json' => perl2json_bytes +{
        preview_url_template => q<http://hoge.{lang}.test/{lang}>,
        location_base_url => q<http://hoge.{lang}.test/{lang}>,
      },
    }, branch => 'foo')->then (sub {
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'foo', '/hoge/fuga', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        is $json->{preview_url_template}, q{http://hoge.{lang}.test/{lang}};
        is $json->{location_base_url}, q{http://hoge.{lang}.test/{lang}};
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 3, name => 'has preview_url_template';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'hoge/fuga/texts/config.json' => perl2json_bytes +{
        preview_url_template => q<HTTPS://hoge.{lang}.test/{lang}>,
      },
    }, branch => 'foo')->then (sub {
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'foo', '/hoge/fuga', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        is $json->{preview_url_template}, q{HTTPS://hoge.{lang}.test/{lang}};
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 2, name => 'has preview_url_template';

test {
  my $c = shift;
  login ($c)->then (sub {
    my $account = $_[0];
    my $text_id = new_text_id;
    my $repo_name = rand;
    my $path = $c->received_data->{repos_path}->child ('pub/' . $repo_name);
    my $url = qq<file:///pub/$repo_name>;
    return git_repo ($path, files => {
      'hoge/fuga/texts/config.json' => perl2json_bytes +{
        preview_url_template => q<javascript:http://hoge.{lang}.test/{lang}>,
        location_base_url => q<javascript:http://hoge.{lang}.test/{lang}>,
      },
    }, branch => 'foo')->then (sub {
      return grant_scopes ($c, $url, $account, ['edit']);
    })->then (sub {
      return GET ($c, ['r', $url, 'foo', '/hoge/fuga', 'info.json'], account => $account);
    })->then (sub {
      my $res = $_[0];
      test {
        is $res->code, 200;
        my $json = json_bytes2perl $res->content;
        is $json->{preview_url_template}, undef;
        is $json->{location_base_url}, undef;
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  });
} wait => $wait, n => 3, name => 'has bad preview_url_template';

# XXX scopes tests

run_tests;
stop_servers;
