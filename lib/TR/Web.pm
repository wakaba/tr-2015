package TR::Web;
use strict;
use warnings;
use Path::Tiny;
use Wanage::URL;
use Encode;
use Promise;
use Promised::File;
use JSON::Functions::XS qw(json_bytes2perl perl2json_bytes json_chars2perl perl2json_chars perl2json_chars_for_record);
use Wanage::HTTP;
use Web::URL::Canonicalize;
use Web::UserAgent::Functions qw(http_get http_post);
use TR::Langs;
use TR::AppServer;
use TR::TextRepo;
use TR::TextEntry;

sub is_text_id ($) {
  return $_[0] =~ /\A[0-9a-f]{3,128}\z/;
} # is_text_id

sub psgi_app ($$) {
  my ($class, $config) = @_;
  return sub {
    ## This is necessary so that different forked siblings have
    ## different seeds.
    srand;

    ## XXX Parallel::Prefork (?)
    delete $SIG{CHLD} if defined $SIG{CHLD} and not ref $SIG{CHLD};

    my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
    my $app = TR::AppServer->new_from_http_and_config ($http, $config);

    # XXX accesslog
    warn sprintf "Access: [%s] %s %s\n",
        scalar gmtime, $app->http->request_method, $app->http->url->stringify;

    return $app->execute_by_promise (sub {
      #XXX
      #my $origin = $app->http->url->ascii_origin;
      #if ($origin eq $app->config->{web_origin}) {
      # XXX HSTS

      return Promise->resolve ($class->main ($app))->then (sub {
        return $app->shutdown;
      }, sub {
        my $error = $_[0];
        if (defined $error and ref $error eq 'HASH') {
          $app->error_log (perl2json_chars_for_record $error);
        }
        return $app->shutdown->then (sub { die $error });
      });

      #} else {
      #  return $app->send_error (400, reason_phrase => 'Bad |Host:|');
      #}
    });
  };
} # psgi_app

my $CatchThenDiscard = sub {
  my ($thenable, $app, $tr) = @_;
  return $thenable->catch (sub {
    if (UNIVERSAL::isa ($_[0], 'Warabe::App::Done')) {
      #
    } elsif (ref $_[0] eq 'HASH' and $_[0]->{bad_branch}) {
      return $app->send_error (404, reason_phrase => 'Bad branch');
    } else {
      $app->error_log ($_[0]);
      return $app->send_error (500);
    }
  })->then (sub {
    return $tr->discard;
  });
}; # $CatchThenDiscard

sub main ($$) {
  my ($class, $app) = @_;
  my $path = $app->path_segments;

  if (@$path == 1 and $path->[0] eq '') {
    # /
    return $app->temma ('index.html.tm', {app => $app});
  }

  if (@$path == 1 and $path->[0] eq 'r') {
    # /r
    return $app->temma ('tr.html.tm', {
      app => $app,
    });
  } elsif (@$path == 2 and $path->[0] eq 'r' and $path->[1] eq '') {
    # /r/
    return $app->send_redirect ('/r');
  } elsif (@$path == 1 and $path->[0] =~ /\Ar\.(json|ndjson)\z/) {
    # /r.json
    # /r.ndjson
    $app->http->set_response_header ('Cache-Control', 'private'); # XXX unless error
    $app->start_json_stream if $1 eq 'ndjson';
    return $class->session ($app)->then (sub {
      my $account = $_[0];
      if ($app->http->request_method eq 'POST') {
        $app->requires_same_origin_or_referer_origin;
        my $op = $app->bare_param ('operation') // '';
        if ($op eq 'github') {
          $app->send_progress_json_chunk ('Preparing for GitHub API access...');
          return $app->account_server (q</token>, {
            sk => $app->http->request_cookies->{sk},
            sk_context => $app->config->get ('account.sk_context'),
            server => 'github',
          })->then (sub {
            my $json = $_[0];
            my $token = $json->{access_token}
                // return $app->throw_error (403, reason_phrase => 'Not linked to any GitHub account');
            $app->send_progress_json_chunk ('Loading GitHub repository list...');
            return Promise->new (sub {
              my ($ok, $ng) = @_;
              # XXX paging support
              http_get
                  url => q<https://api.github.com/user/repos?per_page=100>,
                  header_fields => {Authorization => 'token ' . $token,
                                    Accept => 'application/vnd.github.moondragon+json'},
                  timeout => 100,
                  anyevent => 1,
                  cb => sub {
                    my (undef, $res) = @_;
                    if ($res->code == 200) {
                      $ok->(json_bytes2perl $res->content);
                    } else {
                      $ng->($res->status_line);
                    }
                  };
            });
          })->then (sub {
            my $json = $_[0];
            $app->send_progress_json_chunk ('Caching repository list...');
            $json = {map {
              my $url = qq{https://github.com/$_->{full_name}};
              $url => {
                url => $url,
                default_branch => $_->{default_branch},
                is_public => !$_->{private},
                remote_scopes => {
                  pull => !!$_->{permissions}->{pull},
                  push => !!$_->{permissions}->{push},
                },
                #updated => $_->{updated_at}, # XXX conversion
                label => $_->{full_name},
                desc => $_->{description},
              };
            } @$json};
            return $app->db->insert ('account_repos', [{
              account_id => Dongry::Type->serialize ('text', $account->{account_id}),
              type => 'github',
              data => Dongry::Type->serialize ('json', $json),
              created => time,
              updated => time,
            }], duplicate => {
              data => $app->db->bare_sql_fragment ('VALUES(data)'),
              updated => $app->db->bare_sql_fragment ('VALUES(updated)'),
            });
          })->then (sub {
            return $app->send_last_json_chunk (200, 'Done', {});
          });
        } else {
          return $app->throw_error (400, reason_phrase => 'Bad |operation|');
        }
      } else { # GET
        if (defined $account->{account_id}) {
          # XXX Cache-Control
          return $app->db->select ('repo_access', {
            account_id => Dongry::Type->serialize ('text', $account->{account_id}),
          }, fields => ['repo_url', 'data'])->then (sub {
            my $joined = {map {
              my $url = $_->get ('repo_url');
              $url => {
                url => $url,
                scopes => $_->get ('data'),
                #is_public
                #label
                #desc
              };
            } @{$_[0]->all_as_rows}};
            return $app->db->select ('account_repos', {
              account_id => Dongry::Type->serialize ('text', $account->{account_id}),
            }, fields => ['type', 'data', 'updated'])->then (sub {
              my $all = $_[0]->all_as_rows;
              return $app->send_last_json_chunk (200, 'OK', {
                joined => {data => $joined},
                map {
                  $_->get ('type') => {
                    data => $_->get ('data'),
                    updated => $_->get ('updated'),
                  };
                } @$all
              });
            });
          });
        } else {
          return $app->send_last_json_chunk (200, 'OK', {});
        }
      }
    });
  }

  if ($path->[0] eq 'r' and $path->[2] eq '' and @$path == 3) {
    # /r/{url}/
    my $tr = $class->create_text_repo ($app, $path->[1], undef, undef);
    return $class->check_read ($app, $tr, html => 1)->then (sub {
      return $app->temma ('tr.repo.html.tm', {
        app => $app,
        tr => $tr,
      });
    })->$CatchThenDiscard ($app, $tr);
  } elsif (@$path == 3 and $path->[0] eq 'r' and
           $path->[2] =~ /\Ainfo\.(json|ndjson)\z/) {
    # /r/{url}/info.json
    # /r/{url}/info.ndjson
    my $tr = $class->create_text_repo ($app, $path->[1], undef, undef);
    $app->start_json_stream if $1 eq 'ndjson';
    $app->send_progress_json_chunk ('Checking the repository permission...');
    return $class->check_read ($app, $tr, access_token => 1)->then (sub {
      $app->send_progress_json_chunk ('Cloning the remote repository...');
      return $tr->prepare_mirror ($_[0], $app);
    })->then (sub {
      return $tr->get_branches;
    })->then (sub {
      my $parsed1 = $_[0];
      return $tr->get_commit_logs ([map { $_->{commit} } values %{$parsed1->{branches}}])->then (sub {
        my $parsed2 = $_[0];
        my $sha_to_commit = {};
        $sha_to_commit->{$_->{commit}} = $_ for @{$parsed2->{commits}};
        for (values %{$parsed1->{branches}}) {
          my $log = $sha_to_commit->{$_->{commit}};
          $_->{commit_author} = $log->{author};
          $_->{commit_committer} = $log->{committer};
        }
        return $app->send_last_json_chunk (200, 'Saved', $parsed1);
      });
    })->$CatchThenDiscard ($app, $tr);
  } # /r/{url}/info.json

  if ($path->[0] eq 'r' and @$path == 3 and $path->[2] eq 'acl') {
    # /r/{url}/acl
    my $tr = $class->create_text_repo ($app, $path->[1], undef, undef);
    return $class->session ($app)->then (sub {
      my $account = $_[0];
      return $app->throw_error (403) if not defined $account->{account_id}; # XXX custom 403
      return $app->db->select ('repo_access', {
        repo_url => Dongry::Type->serialize ('text', $tr->url),
        account_id => Dongry::Type->serialize ('text', $account->{account_id}),
      }, fields => ['data'], limit => 1);
    })->then (sub {
      my $row = $_[0]->first_as_row;
      return $app->throw_error (403, reason_phrase => 'Bad privilege')
          if not defined $row or not $row->get ('data')->{repo}; # XXX custom 403
      return $app->temma ('tr.acl.html.tm', {
        app => $app,
        tr => $tr,
      });
    });
  } elsif ($path->[0] eq 'r' and @$path == 3 and
           $path->[2] =~ /\Aacl\.(json|ndjson)\z/) {
    # /r/{url}/acl.json
    # /r/{url}/acl.ndjson
    $app->start_json_stream if $1 eq 'ndjson';
    my $tr = $class->create_text_repo ($app, $path->[1], undef, undef);
    if ($app->http->request_method eq 'POST') {
      $app->requires_same_origin_or_referer_origin;
      return $class->session ($app)->then (sub {
        my $account = $_[0];
        return $app->throw_error (403) if not defined $account->{account_id};

        my $op = $app->bare_param ('operation') // '';
        if ($op eq 'update_account_privilege') {
          my $account_id = $app->bare_param ('account_id')
              // return $app->throw_error (400, reason_phrase => 'Bad |account_id|');
          return $app->db->select ('repo_access', {
            repo_url => Dongry::Type->serialize ('text', $tr->url),
            account_id => Dongry::Type->serialize ('text', $account->{account_id}),
          }, fields => ['data'], limit => 1)->then (sub {
            my $row = $_[0]->first_as_row;
            return $app->throw_error (403, reason_phrase => 'Bad privilege')
                if not defined $row or not $row->get ('data')->{repo};
            my $permissions = {read => 1};
            for my $scope (@{$app->text_param_list ('scope')}) {
              if ({
                edit => 1, comment => 1, texts => 1, repo => 1,
              }->{$scope}) {
                $permissions->{$scope} = 1;
              } elsif ($scope =~ m{\Aedit/[0-9a-z-]+\z}) {
                $permissions->{$scope} = 1;
              }
            }
            return $app->db->insert ('repo_access', [{
              repo_url => Dongry::Type->serialize ('text', $tr->url),
              account_id => Dongry::Type->serialize ('text', $account_id),
              is_owner => 0,
              data => Dongry::Type->serialize ('json', $permissions),
              created => time,
              updated => time,
            }], duplicate => {
              data => $app->db->bare_sql_fragment ('VALUES(data)'),
              updated => $app->db->bare_sql_fragment ('VALUES(updated)'),
            });
          })->then (sub {
            return $app->send_last_json_chunk (200, 'Saved', {});
          });
        } elsif ($op eq 'delete_account_privilege') {
          my $account_id = $app->bare_param ('account_id')
              // return $app->throw_error (400, reason_phrase => 'Bad |account_id|');
          return $app->db->select ('repo_access', {
            repo_url => Dongry::Type->serialize ('text', $tr->url),
            account_id => Dongry::Type->serialize ('text', $account->{account_id}),
          }, fields => ['data'], limit => 1)->then (sub {
            my $row = $_[0]->first_as_row;
            return $app->throw_error (403, reason_phrase => 'Bad privilege')
                if not defined $row or not $row->get ('data')->{repo};
          })->then (sub {
            return $app->db->delete ('repo_access', {
              repo_url => Dongry::Type->serialize ('text', $tr->url),
              account_id => Dongry::Type->serialize ('text', $account_id),
            });
          })->then (sub {
            return $app->send_last_json_chunk (200, 'Deleted', {});
          });
        } elsif ($op eq 'join') {
          return Promise->all ([
            do {
              my $repo_type = $tr->repo_type;
              if ($repo_type eq 'github') {
                $app->account_server (q</token>, {
                  sk => $app->http->request_cookies->{sk},
                  sk_context => $app->config->get ('account.sk_context'),
                  server => 'github',
                })->then (sub {
                  my $json = $_[0];
                  my $token = $json->{access_token};
                  return Promise->new (sub {
                    my ($ok, $ng) = @_;
                    $tr->url =~ m{^https://github.com/([^/]+/[^/]+)} or die;
                    # XXX wiki repos
                    http_get
                        url => qq<https://api.github.com/repos/$1>,
                        header_fields => (defined $token ? {Authorization => 'token ' . $token} : undef),
                        timeout => 100,
                        anyevent => 1,
                        cb => sub {
                          my (undef, $res) = @_;
                          if ($res->code == 200) {
                            $ok->(json_bytes2perl $res->content);
                          } else {
                            $ng->([$res->code, $res->status_line]);
                          }
                        };
                  });
                })->then (sub {
                  my $json = $_[0];
                  return {is_owner => !!$json->{permissions}->{push},
                          is_public => not $json->{private}};
                });
              } elsif ($repo_type eq 'ssh') {
                $app->account_server (q</token>, {
                  sk => $app->http->request_cookies->{sk},
                  sk_context => $app->config->get ('account.sk_context'),
                  server => 'ssh',
                })->then (sub {
                  my $json = $_[0];
                  my $token = $json->{access_token};
                  die [403, "Bad SSH key"] unless defined $token and ref $token eq 'ARRAY';

                  return $tr->prepare_mirror ({access_token => $token,
                                               requires_token_for_pull => 1},
                                              $app);
                })->then (sub {
                  return {is_owner => 1, is_public => 0};
                });
              } elsif ($repo_type eq 'file-public' or
                       $repo_type eq 'file-private') {
                my $url = $tr->mapped_url;
                if ($url =~ s{^file:///}{/}) {
                  #
                } elsif ($url =~ m{/}) {
                  #
                } else {
                  undef $url;
                }
                if (defined $url) {
                  Promised::File->new_from_path ($url)->is_directory->then (sub {
                    if ($_[0]) {
                      return $app->db->select ('repo_access', {
                        repo_url => 'about:siteadmin',
                        account_id => Dongry::Type->serialize ('text', $account->{account_id}),
                      }, fields => ['data'], limit => 1)->then (sub {
                        my $row = $_[0]->first_as_row;
                        return $app->throw_error (403, reason_phrase => 'Bad privilege')
                            if not defined $row or not $row->get ('data')->{repo};
                        return {is_owner => 1,
                                is_public => $repo_type eq 'file-public'};
                      });
                    } else {
                      return {status => 404, message => "Repository not found: <$url>"};
                    }
                  });
                } else {
                  Promise->resolve ({status => 404, message => 'Repository not found'});
                }
              } else { # $repo_type
                Promise->reject ("Can't get ownership of a repository with type |$repo_type|");
              }
            },
            do {
              if ($app->bare_param ('owner')) {
                1;
              } else {
                $app->db->select ('repo_access', {
                  repo_url => Dongry::Type->serialize ('text', $tr->url),
                  is_owner => 1,
                }, fields => ['is_owner'], source_name => 'master', limit => 1)->then (sub {
                  return defined $_[0]->first ? 0 : 1;
                });
              }
            },
          ])->then (sub {
            my ($rights, $should_be_owner) = @{$_[0]};
            if (defined $rights->{status}) {
              return $app->throw_error ($rights->{status}, reason_phrase => $rights->{message});
            }
            my $time = time;
            my $can_be_owner = !!$rights->{is_owner};
            my $can_write = !!$rights->{is_owner};
            $rights->{is_owner} = 0 unless $should_be_owner;
            return $app->db->insert ('repo_access', [{
              repo_url => Dongry::Type->serialize ('text', $tr->url),
              account_id => Dongry::Type->serialize ('text', $account->{account_id}),
              is_owner => $rights->{is_owner} ? 1 : 0,
              data => Dongry::Type->serialize ('json', {
                read => 1,
                edit => $can_write,
                texts => $can_write,
                comment => $can_write,
                repo => $can_be_owner,
              }),
              created => $time,
              updated => $time,
            }], duplicate => {
              ($rights->{is_owner} ? (
                is_owner => $app->db->bare_sql_fragment ('VALUES(is_owner)'),
                data => $app->db->bare_sql_fragment ('VALUES(data)'),
              ) : ()),
              updated => $app->db->bare_sql_fragment ('VALUES(updated)'),
            })->then (sub {
              # XXX as developer / as translator scopes
              return $app->db->execute ('UPDATE `repo_access` SET is_owner = 0 AND updated = ? WHERE repo_url = ? AND account_id != ?', {
                repo_url => Dongry::Type->serialize ('text', $tr->url),
                account_id => Dongry::Type->serialize ('text', $account->{account_id}),
                updated => $time,
              }) if $rights->{is_owner};
            })->then (sub {
              return $app->db->insert ('repo', [{
                repo_url => Dongry::Type->serialize ('text', $tr->url),
                is_public => $rights->{is_public},
                created => time,
                updated => time,
              }], duplicate => {
                is_public => $app->db->bare_sql_fragment ('VALUES(is_public)'),
                updated => $app->db->bare_sql_fragment ('VALUES(updated)'),
              }); # XXXupdate-index
            })->then (sub {
              return $app->send_last_json_chunk (200, 'Joined', $rights);
            });
          }, sub {
            # XXX better error reporting
            die $_[0] unless ref $_[0] eq 'ARRAY';
            my ($status, $status_line) = @{$_[0]};
            if ($status == 404) {
              return $app->send_error (403, reason_phrase => "Can't access to the remote repository");
            } else {
              die $status_line;
            }
          });
        } else {
          return $app->send_error (400, reason_phrase => 'Bad |operation|');
        }
      })->$CatchThenDiscard ($app, $tr);
    } else { # GET
      return $class->session ($app)->then (sub {
        my $account = $_[0];
        return $app->throw_error (403) if not defined $account->{account_id}; # XXX custom 403
        return $app->db->select ('repo_access', {
          repo_url => Dongry::Type->serialize ('text', $tr->url),
          account_id => Dongry::Type->serialize ('text', $account->{account_id}),
        }, fields => ['data'], limit => 1);
      })->then (sub {
        my $row = $_[0]->first_as_row;
        return $app->throw_error (403, reason_phrase => 'Bad privilege')
            if not defined $row or not $row->get ('data')->{repo}; # XXX custom 403

        my $json = {};
        return $app->db->select ('repo_access', {
          repo_url => Dongry::Type->serialize ('text', $tr->url),
        }, fields => ['account_id', 'is_owner', 'data'])->then (sub {
          my $accounts = $json->{accounts} = {map { $_->get ('account_id') => {
            account_id => ''.$_->get ('account_id'),
            scopes => $_->get ('data'),
            is_owner => $_->get ('is_owner'),
          } } @{$_[0]->all_as_rows}};

          return Promise->all ([
            $app->account_server (q</profiles>, {
              account_id => [keys %$accounts],
            }),
            $app->db->select ('repo', {
              repo_url => Dongry::Type->serialize ('text', $tr->url),
            }, fields => ['is_public']),
          ]);
        })->then (sub {
          my $j = $_[0]->[0];
          for my $account_id (keys %{$j->{accounts}}) {
            $json->{accounts}->{$account_id}->{name} = $j->{accounts}->{$account_id}->{name};
            # XXX icon
          }
          my $repo_data = $_[0]->[1]->first;
          if (defined $repo_data) {
            $json->{is_public} = 1 if $repo_data->{is_public};
          } else {
            $json->{is_public} = 1;
          }
          return $app->send_json ($json);
        });
      });
    } # GET
  } # acl

  if ($path->[0] eq 'r' and @$path == 3 and $path->[2] eq 'start') {
    # /r/{url}/start
    my $tr = $class->create_text_repo ($app, $path->[1], undef, undef);
    return $class->check_read ($app, $tr, html => 1)->then (sub {
      return $app->temma ('tr.start.html.tm', {
        app => $app,
        tr => $tr,
      });
    });
  } # start

  if (@$path == 4 and $path->[0] eq 'r' and $path->[3] eq '') {
    # /r/{url}/{branch}/
    my $tr = $class->create_text_repo ($app, $path->[1], $path->[2], undef);
    return $class->check_read ($app, $tr, html => 1)->then (sub {
      return $app->temma ('tr.branch.html.tm', {
        app => $app,
        tr => $tr,
      });
    });
  } elsif (@$path == 4 and $path->[0] eq 'r' and
           $path->[3] =~ /\Ainfo\.(json|ndjson)\z/) {
    # /r/{url}/{branch}/info.json
    # /r/{url}/{branch}/info.ndjson
    my $tr = $class->create_text_repo ($app, $path->[1], $path->[2], undef);
    $app->start_json_stream if $1 eq 'ndjson';
    $app->send_progress_json_chunk ('Checking the repository permission...');
    return $class->check_read ($app, $tr, access_token => 1)->then (sub {
      $app->send_progress_json_chunk ('Cloning the remote repository...');
      return $tr->prepare_mirror ($_[0], $app);
    })->then (sub {
      return $tr->get_commit_logs ([$tr->branch]);
    })->then (sub {
      my $parsed = $_[0];
      my $tree = $parsed->{commits}->[0]->{tree};
      return $tr->get_ls_tree ($tree, recursive => 1);
    })->then (sub {
      my $parsed = $_[0];

      my $text_sets = {};
      for (values %{$parsed->{items}}) {
        next unless $_->{file} =~ m{/texts/config.json\z};
        next unless $_->{type} eq 'blob';
        next if $_->{mode} & 020000; # symlinks
        my $path = '/' . $_->{file};
        $path =~ s{/texts/config.json\z}{};
        $text_sets->{$path}->{path} = $path;
        $text_sets->{$path}->{texts_path} = (substr $path, 1) . '/texts';
        $text_sets->{$path}->{config_path} = $text_sets->{$path}->{texts_path} . '/config.json';
        # XXX text set label, desc, ...
      }

      my $root_config = $parsed->{items}->{'texts/config.json'};
      if (not keys %$text_sets or
          (defined $root_config and
           $root_config->{type} eq 'blob' and
           not $root_config->{mode} & 020000)) { # symlink
        $text_sets->{'/'}->{path} = '/';
        $text_sets->{'/'}->{texts_path} = 'texts';
        $text_sets->{'/'}->{config_path} = 'texts/config.json';
      }

      return $tr->get_last_commit_logs_by_paths ([map { $_->{texts_path} } values %$text_sets])->then (sub {
        my $parsed = $_[0];
        for (values %$text_sets) {
          my $log = $parsed->{$_->{texts_path}};
          $_->{commit} = $log->{commit};
          $_->{commit_message} = $log->{body};
          $_->{committer} = $log->{committer};
          $_->{commit_author} = $log->{author};
        }
        return $app->send_last_json_chunk (200, 'OK', {text_sets => $text_sets});
      });
    })->$CatchThenDiscard ($app, $tr);
  } # /r/{url}/{branch}/info.json

  if ($path->[0] eq 'r' and @$path >= 4) {
    # /r/{url}/{branch}/{path}
    my $tr = $class->create_text_repo
        ($app, $path->[1], $path->[2], $path->[3]);

    if (@$path == 5 and $path->[4] eq '') {
      # .../
      return $class->check_read ($app, $tr, html => 1)->then (sub {
        require TR::Query;
        my $q = TR::Query->parse_query (
          query => $app->text_param ('q'),
          text_ids => $app->text_param_list ('text_id'),
          msgids => $app->text_param_list ('msgid'),
          tag_ors => $app->text_param_list ('tag_or'),
          tags => $app->text_param_list ('tag'),
          tag_minuses => $app->text_param_list ('tag_minus'),
        );
        # XXX Last-Modified
        return $app->temma ('tr.texts.html.tm', {
          app => $app,
          tr => $tr,
          query => $q,
        });
      });

    } elsif (@$path == 5 and $path->[4] =~ /\Adata\.(json|ndjson)\z/) {
      # .../data.json
      # .../data.ndjson

      $app->start_json_stream if $1 eq 'ndjson';
      $app->send_progress_json_chunk ('Checking the repository permission...');
      my $q;
      my $scopes;
      return $class->check_read (
        $app, $tr,
        access_token => 1, scopes => 1,
      )->then (sub {
        $scopes = $_[0]->{scopes};
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        require TR::Query;
        $q = TR::Query->parse_query (
          query => $app->text_param ('q'),
          text_ids => $app->text_param_list ('text_id'),
          msgids => $app->text_param_list ('msgid'),
          tag_ors => $app->text_param_list ('tag_or'),
          tags => $app->text_param_list ('tag'),
          tag_minuses => $app->text_param_list ('tag_minus'),
        );
        $app->send_progress_json_chunk ('Reading the text set...');
        return $tr->get_data_as_jsonalizable
            ($q,
             $app->text_param_list ('lang')->grep (sub { length }),
             config => $app->config,
             with_comments => $app->bare_param ('with_comments'));
      })->then (sub {
        my $json = $_[0];
        $app->send_progress_json_chunk ('Formatting the text set...');
        $json->{scopes} = $scopes;
        $json->{query} = $q->as_jsonalizable;
        $app->send_last_json_chunk (200, 'OK', $json);
      })->$CatchThenDiscard ($app, $tr);
    } elsif (@$path == 5 and $path->[4] =~ /\Ainfo\.(json|ndjson)\z/) {
      # .../info.json
      # .../info.ndjson

      $app->start_json_stream if $1 eq 'ndjson';
      $app->send_progress_json_chunk ('Checking the repository permission...');
      my $scopes;
      return $class->check_read (
        $app, $tr,
        access_token => 1, scopes => 1,
      )->then (sub {
        $scopes = $_[0]->{scopes};
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        $app->send_progress_json_chunk ('Reading metadata...');
        return $tr->get_tr_config;
      })->then (sub {
        my $config = $_[0];
        my $json = {
          url => $tr->url,
          branch => $tr->branch,
          texts_path => '/' . ($tr->texts_dir // ''),
        };

        $json->{avail_lang_keys} = $config->{avail_lang_keys};
        $json->{avail_lang_keys} = ['en'] unless @{$json->{avail_lang_keys}};

        $json->{langs} = {map {
          my $def = $config->{langs}->{$_};
          my $id = $def->{id} // $_; # XXX validation
          my $label_raw = $def->{label};
          my $label = $label_raw // $_; # XXX system's default
          my $label_short_raw = $def->{label_short};
          my $label_short = $label_short_raw // $label; # XXX system's default
          $_ => +{
            key => $_,
            id => $id,
            label_raw => $label_raw,
            label => $label,
            label_short_raw => $label_short_raw,
            label_short => $label_short,
          };
        } @{$json->{avail_lang_keys}}};

        $json->{license} = $config->{license};

        $json->{scopes} = $scopes;

        if (defined $config->{preview_url_template} and
            $config->{preview_url_template} =~ m{^[Hh][Tt][Tt][Pp][Ss]?://}) {
          $json->{preview_url_template} = $config->{preview_url_template};
        }

        $app->send_last_json_chunk (200, 'OK', $json);
      })->$CatchThenDiscard ($app, $tr);

    } elsif (@$path == 5 and $path->[4] eq 'XXXupdate-index') {
      # .../XXXupdate-index
      # XXX request method
      # XXX skip if non-default branch
      return $class->check_read ($app, $tr, access_token => 1)->then (sub {
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        return $tr->get_tr_config;
      })->then (sub {
        my $config = $_[0];
        require TR::Query;
        return $tr->get_data_as_jsonalizable (
          TR::Query->parse_query, [],
          config => $app->config,
        )->then (sub {
          my $json = $_[0];
          $json->{repo_url} = $tr->url;
          $json->{repo_path} = '/' . ($tr->texts_dir // '');
          $json->{repo_license} = $config->{license}->{type}; # XXX
          require TR::Search;
          my $s = TR::Search->new_from_config ($app->config);
          return $s->put_data ($json);
        })->then (sub {
          return $app->send_error (200);
        });
      })->$CatchThenDiscard ($app, $tr);

    } elsif (@$path == 5 and $path->[4] eq 'export') {
      # .../export
      return $class->check_read ($app, $tr, access_token => 1)->then (sub {
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        my $format = $app->text_param ('format') // '';
        my $arg_format = $app->text_param ('arg_format') // '';
        if ($format eq 'po') { # XXX and pot
          my $lang = $app->text_param ('lang')
              or return $app->send_error (400, reason_phrase => '|lang| not specified');
          $arg_format ||= 'printf'; #$arg_format normalization
          $arg_format = 'printf' if $arg_format eq 'auto';
          require TR::Query;
          my $q = TR::Query->parse_query (
            query => $app->text_param ('q'),
            text_ids => $app->text_param_list ('text_id'),
            msgids => $app->text_param_list ('msgid'),
            tag_ors => $app->text_param_list ('tag_or'),
            tags => $app->text_param_list ('tag'),
            tag_minuses => $app->text_param_list ('tag_minus'),
          );
          return $tr->get_data_as_jsonalizable
              ($q, [$lang], config => $app->config)->then (sub {
            my $json = $_[0];
            unless ($json->{langs}->{$lang}) {
              return $app->throw_error (400, reason_phrase => 'Bad |lang|');
            }

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
            $app->http->set_response_header ('Content-Type' => 'text/x-po; charset=utf-8');
            $app->http->set_response_disposition (filename => "$lang.po");
            $app->http->send_response_body_as_text ($es->stringify);
            $app->http->close_response_body;
          });
        } else {
          return $app->send_error (400, reason_phrase => 'Unknown format');
        }
      })->$CatchThenDiscard ($app, $tr);

    } elsif (@$path == 5 and $path->[4] eq 'start') {
      # .../start
      return $class->check_read ($app, $tr, html => 1)->then (sub {
        return $app->temma ('tr.texts.start.html.tm', {
          app => $app,
          tr => $tr,
        });
      });

    } elsif (@$path == 5 and $path->[4] eq 'import') {
      # .../import
      return $class->check_read ($app, $tr, html => 1)->then (sub {
        # XXX $app->text_param_list ('lang');
        # XXX $app->text_param_list ('tag')
        return $app->temma ('tr.texts.import.html.tm', {
          app => $app,
          tr => $tr,
          # XXX scopes
        });
      });
    } elsif (@$path == 5 and $path->[4] =~ /\Aimport\.(json|ndjson)\z/) {
      # .../import.json
      # .../import.ndjson
      my $type = $1;
      return $class->edit_text_set (
        $app, $tr, $type,
        sub {
          my $from = $app->bare_param ('from') // '';
          $app->send_progress_json_chunk ('Importing...');
          my $lang = $app->text_param ('lang') // '';
          my $format = $app->text_param ('format') // '';
          return $tr->run_import ( # XXX progress
            from => $from,
            files => [map {
              my $v = $_;
              +{file_name => $v->as_f . '', # XXX don't use Path::Class
                label => $v->filename,
                lang => $lang,
                format => $format};
            } @{$app->http->request_uploads->{file} || []}],
            format => $format,
            arg_format => $app->text_param ('arg_format') // '',
            tags => $app->text_param_list ('tag')->grep (sub { length }),
          )->then (sub {
            $app->send_progress_json_chunk ('Running export rules...');
            return $tr->run_export (onerror => sub {
              $app->send_last_json_chunk ($_[0]->{status}, $_[0]->{message}, {});
            });
          });
        },
        scope => 'edit', # XXX scope
        default_commit_message => 'Imported',
      );

    } elsif (@$path >= 7 and $path->[4] eq 'i') {
      my $text_id = $path->[5];
      return $app->throw_error (404, reason_phrase => 'Bad text ID')
          unless is_text_id $text_id;

      if (@$path == 7 and $path->[6] =~ /\Atext\.(json|ndjson)\z/) {
        # .../i/{text_id}/text.json
        # .../i/{text_id}/text.ndjson
        my $type = $1;
        $app->requires_request_method ({POST => 1});
        $app->requires_same_origin_or_referer_origin;
        my $lang = $app->text_param ('lang') // '';
        return $class->edit_text_set (
          $app, $tr, $type,
          sub {
            return $tr->get_tr_config->then (sub {
              my $config = $_[0];
              unless (grep { $_ eq $lang } @{$config->{avail_lang_keys}}) {
                $app->send_last_json_chunk (409, "Language key |$lang| is not allowed", {});
                return $app->throw;
              }
              my $path = $tr->text_id_and_suffix_to_relative_path
                  ($text_id, $lang . '.txt');
              return $tr->mirror_repo->show_blob_by_path ($tr->branch, $path);
            })->then (sub {
              my $te = TR::TextEntry->new_from_source_text ($_[0] // '');
              my $modified;
              for (qw(body_0 body_1 body_2 body_3 body_4 body_5 forms)) {
                my $v = $app->text_param ($_);
                next unless defined $v;
                my $current = $te->get ($_);
                if (not defined $current or not $current eq $v) {
                  $te->set ($_ => $v);
                  $modified = 1;
                }
              }
              if ($modified) {
                $te->set (last_modified => time);
                return $tr->write_file_by_text_id_and_suffix
                    ($text_id, $lang . '.txt' => $te->as_source_text);
              }
            })->then (sub {
              $app->send_progress_json_chunk ('Running export rules...');
              return $tr->run_export (onerror => sub {
                $app->send_last_json_chunk
                    ($_[0]->{status}, $_[0]->{message}, {
                      status => $_[0]->{status},
                      message => $_[0]->{message},
                    });
              });
            })->then (sub { return {} });
          },
          scope => 'edit/' . $lang,
          default_commit_message => 'Modified a text',
        );

      } elsif (@$path == 7 and $path->[6] =~ /\Ameta\.(json|ndjson)\z/) {
        # .../i/{text_id}/meta.json
        # .../i/{text_id}/meta.ndjson
        my $type = $1;
        $app->requires_request_method ({POST => 1});
        $app->requires_same_origin_or_referer_origin;
        my $lang = $app->text_param ('lang') // '';
        return $class->edit_text_set (
          $app, $tr, $type,
          sub {
            my $path = $tr->text_id_and_suffix_to_relative_path
                ($text_id, 'dat');
            return $tr->mirror_repo->show_blob_by_path ($tr->branch, $path)->then (sub {
              my $te = TR::TextEntry->new_from_source_text ($_[0] // '');

              $te->set (msgid => $app->text_param ('msgid'));
              $te->set (desc => $app->text_param ('desc'));

              my $enum = $te->enum ('tags');
              %$enum = ();
              $enum->{$_} = 1
                  for grep { length } @{$app->text_param_list ('tag')};

              my $args = $te->list ('args');
              $te->set ('args.desc.' . $_ => undef) for @$args;
              @$args = ();
              my $names = $app->text_param_list ('arg_name');
              my $descs = $app->text_param_list ('arg_desc');
              my %found;
              for (0..$#$names) {
                next if $found{$names->[$_]}++;
                next unless length $names->[$_];
                push @$args, $names->[$_];
                $te->set ('args.desc.'.$names->[$_] => $descs->[$_]);
              }

              return $tr->write_file_by_text_id_and_suffix
                  ($text_id, 'dat' => $te->as_source_text)->then (sub {
                $app->send_progress_json_chunk ('Running export rules...');
              })->then (sub {
                return $tr->run_export (onerror => sub {
                  $app->send_last_json_chunk
                      ($_[0]->{status}, $_[0]->{message}, {});
                });
              })->then (sub {
                return $te->as_jsonalizable;
              });
            });
          },
          scope => 'texts',
          default_commit_message => 'Modified text metadata',
        );

      } elsif (@$path == 7 and $path->[6] =~ /\Acomments\.(json|ndjson)\z/) {
        # .../i/{text_id}/comments.json
        # .../i/{text_id}/comments.ndjson
        my $type = $1;
        $app->requires_request_method ({POST => 1});
        $app->requires_same_origin_or_referer_origin;
        return $class->edit_text_set (
          $app, $tr, $type,
          sub {
            my $keys = $_[0];
            my $path = $tr->text_id_and_suffix_to_relative_path
                ($text_id, 'comments');
            return $tr->repo->git ('checkout', [$tr->branch, '--', $path])->catch (sub {
              ## Ignore |error: pathspec '....comments' did not match any file(s) known to git.|
              die $_[0] unless UNIVERSAL::can ($_[0], 'exit_code') and $_[0]->exit_code == 1;
            })->then (sub {
              my $te = TR::TextEntry->new_from_source_text ('');
              $te->set (id => $tr->generate_section_id);
              my $body = $app->text_param ('body') // '';
              if (1024 < length $body) {
                return $app->throw_error (400, reason_phrase => 'Comment text too llong');
              } elsif ($body eq '') {
                return $app->throw_error (204, reason_phrase => 'Empty comment text');
              }
              $te->set (body => $body);
              my $name = $keys->{name} // '';
              $name = $keys->{account_id} // 'unknown' unless length $name;
              $te->set (author_name => $name);
              $te->set (author_account_id => $keys->{account_id});
              $te->set (last_modified => time);
              return $tr->append_section_to_file_by_text_id_and_suffix
                  ($text_id, 'comments' => $te->as_source_text)->then (sub {
                return {comments => [$te->as_jsonalizable]};
              });
            });
          },
          scope => 'comment',
          default_commit_message => 'Added a comment',
        );

      } elsif (@$path == 7 and $path->[6] eq 'history.json') {
        # .../i/{text_id}/history.json
        my $lang = $app->text_param ('lang') // '';
        return $class->check_read ($app, $tr, access_token => 1)->then (sub {
          return $tr->prepare_mirror ($_[0], $app);
        })->then (sub {
          return $tr->get_tr_config;
        })->then (sub {
          my $config = $_[0];
          unless (grep { $_ eq $lang } @{$config->{avail_lang_keys}}) {
            $app->send_last_json_chunk (400, "Language key |$lang| is not allowed", {});
            return $app->throw;
          }
          return $tr->git_log_for_text_id_and_lang
              ($text_id, $lang, with_file_text => 1);
        })->then (sub {
          my $parsed = $_[0];
          my @json;
          for (@{$parsed->{commits}}) {
            my $te = TR::TextEntry->new_from_source_text (decode 'utf-8', $_->{blob_data});
            push @json, {lang_text => $te->as_jsonalizable,
                         commit => {commit => $_->{commit},
                                    commit_message => $_->{body},
                                    commit_author => $_->{author},
                                    committer => $_->{committer}}};
          }
          return {history => \@json};
        })->then (sub {
          return $app->send_json ($_[0]);
        })->$CatchThenDiscard ($app, $tr);
      } # .../i/{text_id}/...

    } elsif (@$path == 5 and $path->[4] =~ /\Aadd\.(json|ndjson)\z/) {
      # .../add.json
      # .../add.ndjson
      my $type = $1;
      $app->requires_request_method ({POST => 1});
      $app->requires_same_origin_or_referer_origin;
      return $class->edit_text_set (
        $app, $tr, $type,
        sub {
          my $text_id = $tr->generate_text_id;
          my $te = TR::TextEntry->new_from_source_text ('');
          my $msgid = $app->text_param ('msgid') // '';
          $te->set (msgid => $msgid) if length $msgid;
          my $desc = $app->text_param ('desc') // '';
          $te->set (desc => $desc) if length $desc;
          for (@{$app->text_param_list ('tag')}) {
            $te->enum ('tags')->{$_} = 1;
          }
          my $json = {};
          $json->{texts}->{$text_id} = $te->as_jsonalizable;
          return $tr->write_file_by_text_id_and_suffix
              ($text_id, 'dat' => $te->as_source_text)->then (sub {
            return $json;
          });
        },
        scope => 'texts',
        default_commit_message => 'Added a text',
      );

    } elsif (@$path == 5 and $path->[4] eq 'langs') {
      # .../langs
      return $class->check_read ($app, $tr, html => 1)->then (sub {
        return $app->temma ('tr.texts.langs.html.tm', {
          app => $app,
          tr => $tr,
        });
      });
    } elsif (@$path == 5 and $path->[4] =~ /\Alangs\.(json|ndjson)\z/) {
      # .../langs.json
      # .../langs.ndjson
      my $type = $1;
      $app->requires_request_method ({POST => 1});
      $app->requires_same_origin_or_referer_origin;
      return $class->edit_text_set (
        $app, $tr, $type,
        sub {
          return $tr->get_tr_config->then (sub {
            my $config = $_[0];

            my $lang_keys = $app->text_param_list ('lang_key');
            my $lang_ids = $app->text_param_list ('lang_id');
            my $lang_labels = $app->text_param_list ('lang_label');
            my $lang_label_shorts = $app->text_param_list ('lang_label_short');

            my %found;
            my @lang_key;
            for (0..$#$lang_keys) {
              my $lang_key = $lang_keys->[$_];
              next if $found{$lang_key}++;

              return $app->throw_error (400, reason_pharse => "Bad language key |$lang_key|")
                  unless TR::Langs::is_lang_key $lang_key;
              # XXX validate lang.id

              push @lang_key, $lang_key;
              my $lang = $config->{langs}->{$lang_key} = {
                id => $lang_ids->[$_] // '',
                label => $lang_labels->[$_] // '',
                label_short => $lang_label_shorts->[$_] // '',
              };
              delete $lang->{id} if not length $lang->{id};
              delete $lang->{label} if not length $lang->{label};
              delete $lang->{label_short} if not length $lang->{label_short};
            }
            $config->{avail_lang_keys} = \@lang_key;

            return $tr->write_file_by_path
                ($tr->texts_path->child ('config.json'),
                 perl2json_chars_for_record $config);
          })->then (sub { return {} });
        },
        scope => 'repo',
        default_commit_message => 'Modified languages',
      );

    } elsif (@$path == 5 and $path->[4] eq 'LICENSE') {
      # .../LICENSE
      # XXX access token
      return $app->send_plain_text ('XXX');
    } elsif (@$path == 5 and $path->[4] eq 'license') {
      # .../license
      return $class->check_read ($app, $tr, html => 1)->then (sub {
        return $app->temma ('tr.texts.license.html.tm', {
          app => $app,
          tr => $tr,
        });
      });
    } elsif (@$path == 5 and $path->[4] =~ /\Alicense\.(json|ndjson)\z/) {
      # .../license.json
      # .../license.ndjson
      my $type = $1;
      $app->requires_request_method ({POST => 1});
      $app->requires_same_origin_or_referer_origin;
      return $class->edit_text_set (
        $app, $tr, $type,
        sub {
          return $tr->get_tr_config->then (sub {
            my $config = $_[0];
            my $license = {type => $app->text_param ('type') // '',
                           holders => $app->text_param ('holders') // '',
                           additional_terms => $app->text_param ('additional_terms') // ''};
            $config->{license} = $license;
            delete $license->{type} unless length $license->{type};
            delete $license->{holders} unless length $license->{holders};
            delete $license->{additional_terms} unless length $license->{additional_terms};
            return $tr->write_file_by_path
                ($tr->texts_path->child ('config.json'),
                 perl2json_chars_for_record $config)->then (sub {
              return $tr->write_license_file (%$license);
            });
          })->then (sub { return {} });
        },
        scope => 'repo',
        default_commit_message => 'Modified license',
      );

    } elsif (@$path == 5 and ($path->[4] eq 'comments' or $path->[4] eq 'comments.json')) {
      # .../comments # XXX HTML view
      # .../comments.json
      return $class->check_read ($app, $tr, access_token => 1)->then (sub {
        return $tr->prepare_mirror ($_[0], $app);
      })->then (sub {
        return $tr->get_recent_comments (limit => 50);
      })->then (sub {
        return $app->send_json ($_[0]);
      })->$CatchThenDiscard ($app, $tr);

    }
  }

  if (@$path == 1 and $path->[0] eq 'search.json') {
    # /search.json
    require TR::Search;
    my $s = TR::Search->new_from_config ($app->config);
    return $s->search ($app->text_param ('q') // '')->then (sub {
      return $app->send_json ($_[0]);
      # XXX paging
    });
  }

  # XXX Cache-Control
  if (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'login') {
    # /account/login
    $app->requires_request_method ({POST => 1});
    $app->requires_same_origin_or_referer_origin;

    my $server = $app->bare_param ('server') // '';
    unless ($server eq 'github' or $server eq 'hatena') {
      return $app->send_error (400, reason_phrase => 'Bad |server|');
    }
    my $server_scope = {github => 'repo'}->{$server};

    return $app->account_server (q</session>, {
      sk => $app->http->request_cookies->{sk},
      sk_context => $app->config->get ('account.sk_context'),
    })->then (sub {
      my $json = $_[0];
      $app->http->set_response_cookie
          (sk => $json->{sk},
           expires => $json->{sk_expires},
           httponly => 1,
           secure => $app->config->get ('cookie.secure'),
           domain => $app->config->get ('cookie.domain'),
           path => q</>) if $json->{set_sk};
      return $app->account_server (q</login>, {
        sk => $json->{sk},
        sk_context => $app->config->get ('account.sk_context'),
        server => $server,
        server_scope => $server_scope,
        callback_url => $app->http->url->resolve_string ('/account/cb')->stringify,
        app_data => (perl2json_chars {next => $app->text_param ('next')}),
      });
    })->then (sub {
      my $json = $_[0];
      return $app->send_redirect ($json->{authorization_url});
    });
  } elsif (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'cb') {
    # /account/cb
    return $app->account_server (q</cb>, {
      sk => $app->http->request_cookies->{sk},
      sk_context => $app->config->get ('account.sk_context'),
      oauth_token => $app->http->query_params->{oauth_token},
      oauth_verifier => $app->http->query_params->{oauth_verifier},
      code => $app->http->query_params->{code},
      state => $app->http->query_params->{state},
    })->then (sub {
      my $json = $_[0];
      my $app_data = json_chars2perl ($json->{app_data} // '{}');
      my $url = $app->http->url->resolve_string ($app_data->{next} // '/');
      if ($url->ascii_origin eq $app->http->url->ascii_origin) {
        return $app->send_redirect ($url->stringify);
      } else {
        return $app->send_redirect ('/');
      }
    });
  } elsif (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'info.json') {
    # /account/info.json
    $app->http->set_response_header ('Cache-Control' => 'private'); # XXX unless error
    return $class->session ($app)->then (sub {
      my $account = $_[0];
      return $app->send_json ({name => $account->{name}, # or undef
                               account_id => (defined $account->{account_id} ? ''.$account->{account_id} : undef)});
      # XXX icon
    });
  } elsif (@$path == 2 and $path->[0] eq 'account' and $path->[1] eq 'sshkey.json') {
    # /account/sshkey.json
    if ($app->http->request_method eq 'POST') {
      $app->requires_same_origin_or_referer_origin;
      my $comment = $app->config->get ('ssh_key.comment');
      $comment =~ s/\{time\}/time/ge;
      return $app->account_server (q</keygen>, {
        sk => $app->http->request_cookies->{sk},
        sk_context => $app->config->get ('account.sk_context'),
        server => 'ssh',
        comment => $comment,
      })->then (sub {
        return $app->send_json ({});
      });
      # XXX error handling
    } else { # GET
      return $app->account_server (q</token>, {
        sk => $app->http->request_cookies->{sk},
        sk_context => $app->config->get ('account.sk_context'),
        server => 'ssh',
      })->then (sub {
        my $json = $_[0];
        if (defined $json->{access_token} and
            ref $json->{access_token} eq 'ARRAY') {
          return $app->send_json ({public_key => $json->{access_token}->[0]});
        } else {
          return $app->send_json ({});
        }
      });
    }
  } # /account

  if (@$path == 2 and
      $path->[0] eq 'users' and
      $path->[1] eq 'search.json') {
    # /users/search.json
    $app->requires_request_method ({POST => 1});
    # XXX requires session?

    return $app->account_server (q</search>, {
      q => $app->text_param ('q'),
    })->then (sub {
      my $json = $_[0];
      return $app->send_json ($json);
    });
  } # /users/search.json

  if (@$path == 1 and $path->[0] eq 'help') {
    # /help
    return $app->temma ('help.html.tm', {app => $app});
  } elsif (@$path == 1 and $path->[0] eq 'rule') {
    # /rule
    return $app->temma ('rule.html.tm', {app => $app});
  }

  if ($path->[0] eq 'admin') {
    if (@$path == 2 and $path->[1] eq 'repository-rules') {
      # /admin/repository-rules
      my $tr = $class->create_text_repo
          ($app, 'about:siteadmin', 'master', '/');
      return $class->check_read ($app, $tr)->then (sub {
        return $app->temma ('admin.repository-rules.html.tm', {app => $app});
      });
    }

    if (@$path == 2 and $path->[1] =~ /\Arepository-rules\.(json|ndjson)\z/) {
      # /admin/repository-rules.json
      # /admin/repository-rules.ndjson
      my $type = $1;
      my $tr = $class->create_text_repo
          ($app, 'about:siteadmin', 'master', '/');
      if ($app->http->request_method eq 'POST') {
        $app->requires_same_origin_or_referer_origin;
        return $class->edit_text_set (
          $app, $tr, $type,
          sub {
            $app->send_progress_json_chunk ('Updating the configuration file...');
            return $tr->write_file_by_path ($tr->repo_path->child ('repository-rules.json'), $app->text_param ('json') // '{}')->then (sub {
              $app->config->sighup_root_process;
              return {};
            });
          },
          scope => 'repo',
          default_commit_message => 'Updated repository-rules.json',
        );
      } else { # GET
        $app->start_json_stream if $type eq 'ndjson';
        return $class->check_read ($app, $tr, access_token => 1)->then (sub {
          $app->send_progress_json_chunk ('Cloning the repository...');
          return $tr->prepare_mirror ($_[0], $app);
        })->then (sub {
          return $tr->mirror_repo->show_blob_by_path ($tr->branch, 'repository-rules.json');
        })->then (sub {
          my $json = json_bytes2perl $_[0] // '{}';
          $json = {} unless defined $json and ref $json eq 'HASH';
          return $app->send_last_json_chunk (200, 'OK', $json);
        });
      }
    }

    if (@$path == 2 and $path->[1] eq 'account') {
      # /admin/account
      $app->requires_basic_auth ({admin => $app->config->get ('admin.token')});
      if ($app->http->request_method eq 'POST') {
        $app->requires_same_origin_or_referer_origin;
        return $class->session ($app)->then (sub {
          my $account = $_[0];
          unless (defined $account->{account_id}) {
            return $app->send_error (403, reason_phrase => 'Need to login');
          }
          my $time = time;
          return $app->db->execute ('SELECT GET_LOCK(:name, :timeout)', {
            name => 'repo_access=about:siteadmin',
            timeout => 60,
          }, source_name => 'master')->then (sub {
            return $app->db->insert ('repo_access', [{
              repo_url => 'about:siteadmin',
              account_id => Dongry::Type->serialize ('text', $account->{account_id}),
              is_owner => 1,
              data => Dongry::Type->serialize ('json', {
                read => 1, edit => 1, texts => 1, comment => 1, repo => 1,
              }),
              created => $time,
              updated => $time,
            }], duplicate => {
              is_owner => $app->db->bare_sql_fragment ('VALUES(is_owner)'),
              updated => $app->db->bare_sql_fragment ('VALUES(updated)'),
            });
          })->then (sub {
            return $app->db->execute ('UPDATE `repo_access` SET is_owner = 0 AND updated = ? WHERE repo_url = ? AND account_id != ?', {
              repo_url => 'about:siteadmin',
              account_id => Dongry::Type->serialize ('text', $account->{account_id}),
              updated => $time,
            });
          })->then (sub {
            return $app->db->execute ('SELECT RELEASE_LOCK(:name)', {
              name => 'repo_access=about:siteadmin',
            }, source_name => 'master');
          })->then (sub {
            return $app->db->insert ('repo', [{
              repo_url => 'about:siteadmin',
              is_public => 0,
              created => $time,
              updated => $time,
            }], duplicate => 'ignore');
          })->then (sub {
            return $app->send_redirect ('/r/about:siteadmin/acl');
          });
        });
      } else {
        return $app->temma ('admin.account.html.tm', {app => $app});
      }
    }
  } # /admin/

  if (@$path == 2 and
      {js => 1, css => 1, data => 1, images => 1, fonts => 1}->{$path->[0]} and
      $path->[1] =~ /\A[0-9A-Za-z_-]+\.(js|css|jpe?g|gif|png|json|ttf|otf|woff)\z/) {
    # /js/* /css/* /images/* /data/*
    return $app->send_file ("$path->[0]/$path->[1]", {
      js => 'text/javascript; charset=utf-8',
      css => 'text/css; charset=utf-8',
      jpeg => 'image/jpeg',
      jpg => 'image/jpeg',
      gif => 'image/gif',
      png => 'image/png',
      json => 'application/json; charset=utf-8',
    }->{$1} // 'application/octet-stream');
  }

  if (@$path == 1 and $path->[0] eq 'robots.txt') {
    # /robots.txt
    # XXX
    return $app->send_plain_text ("User-Agent: *\nDisallow: /\n");
  }

  return $app->send_error (404);
} # main

sub create_text_repo ($$$) {
  my ($class, $app, $url, $branch, $path) = @_;

  my $tr = TR::TextRepo->new_from_mirror_and_temp_path
      ($app->mirror_path, Path::Tiny->tempdir);
  $tr->config ($app->config);

  return $app->throw_error (404, reason_phrase => 'Bad repository URL')
      if $url =~ /[?#]/;
  $url =~ s{^([^/:\@]+\@[^/:]+):}{ssh://$1/};
  $url =~ s{^/}{file:///};
  $url = (url_to_canon_url $url, 'about:blank') // '';
  $url =~ s{\.git/?\z}{};
  if ($url =~ m{^file:}) {
    $url =~ s{/+\z}{};
  }

  # XXX max URL length
  my $rule;
  if ($url eq 'about:siteadmin') {
    $rule = {
      prefix => q<about:siteadmin>,
      mapped_prefix => $app->config->{siteadmin_path} . '/',
      repository_type => 'file-private',
    };
  } else {
    for my $r (@{$app->config->{repository_rules}}) {
      next unless defined $r and ref $r eq 'HASH';
      next unless defined $r->{prefix} and length $r->{prefix};
      if ($url =~ m{\A\Q$r->{prefix}\E}) {
        $rule = $r;
        last;
      }
    }
  }
  return $app->throw_error (404, reason_phrase => "Bad repository URL: |$url|")
      unless defined $rule;

  $url =~ s{\A\Q$rule->{prefix}\E}{$rule->{canonical_prefix}}
      if defined $rule->{canonical_prefix};
  $tr->url ($url);
  if (defined $rule->{mapped_prefix}) {
    my $mapped_url = $url;
    $mapped_url =~ s{\A\Q$rule->{prefix}\E}{$rule->{mapped_prefix}}
        if defined $rule->{mapped_prefix};
    $tr->mapped_url ($mapped_url);
  }
  $tr->repo_type ($rule->{repository_type});

  if (defined $branch) {
    return $app->throw_error (404, reason_phrase => 'Bad repository branch')
        unless length $branch;
    $tr->branch ($branch);
  }

  if (defined $path) {
    if ($path eq '/' or $path =~ m{\A(?:/[0-9A-Za-z_][0-9A-Za-z_.-]*)+\z}) {
      #
    } else {
      return $app->throw_error (404, reason_phrase => 'Bad text set path');
    }
    return $app->throw_error (404, reason_phrase => 'Text set path too long')
        if 64 < length $path;
    $tr->texts_dir (substr $path, 1);
  }

  return $tr;
} # create_text_repo

sub session ($$) {
  my ($class, $app) = @_;
  my $sk = $app->http->request_cookies->{sk};
  return defined $sk ? $app->account_server (q</info>, {
    sk => $sk,
    sk_context => $app->config->get ('account.sk_context'),
  }) : Promise->resolve ({});
} # session

sub check_read ($$$;%) {
  my ($class, $app, $tr, %args) = @_;
  my $scopes;
  my $is_public;
  my $account = {};
  return $app->db->select ('repo', {
    repo_url => Dongry::Type->serialize ('text', $tr->url),
  }, fields => ['is_public'])->then (sub {
    my $repo = $_[0]->first;
    if (defined $repo) {
      if ($repo->{is_public}) {
        $is_public = 1;
        if ($args{scopes}) {
          return $class->session ($app)->then (sub {
            my $acc = $_[0];
            if (defined $acc->{account_id}) {
              return $app->db->select ('repo_access', {
                account_id => Dongry::Type->serialize ('text', $acc->{account_id}),
                repo_url => Dongry::Type->serialize ('text', $tr->url),
              }, fields => ['data'])->then (sub {
                my $row = $_[0]->first_as_row;
                if (defined $row) {
                  $scopes = $row->get ('data');
                  return $scopes->{read};
                } else {
                  $scopes = {read => 1};
                  return 1;
                }
              });
            } else {
              $scopes = {read => 1};
              return 1;
            }
          });
        } else {
          return 1;
        }
      } else { # private repo
        return $class->session ($app)->then (sub {
          my $acc = $_[0];
          return 0 if not defined $acc->{account_id};
          return $app->db->select ('repo_access', {
            account_id => Dongry::Type->serialize ('text', $acc->{account_id}),
            repo_url => Dongry::Type->serialize ('text', $tr->url),
          }, fields => ['data'])->then (sub {
            my $row = $_[0]->first_as_row;
            $account->{requires_token_for_pull} = 1;
            $scopes = $row->get ('data') if defined $row;
            return (defined $scopes and $scopes->{read});
          });
        });
      }
    } else { # no |repo| row
      return 0;
    }
  })->then (sub {
    if ($_[0]) { # can be read
      if ($args{access_token}) {
        if ($is_public) {
          $account->{scopes} = $scopes if $args{scopes};
          return $account;
        }
        return $app->db->select ('repo_access', {
          repo_url => Dongry::Type->serialize ('text', $tr->url),
          is_owner => 1,
        }, fields => ['account_id'], limit => 1)->then (sub {
          my $owner = $_[0]->first;
          return $app->throw_error (403, reason_phrase => 'The repository has no owner') unless defined $owner;
          my $server;
          my $repo_type = $tr->repo_type;
          if ($repo_type eq 'github') {
            $server = 'github';
          } elsif ($repo_type eq 'ssh') {
            $server = 'ssh';
          } elsif ($repo_type eq 'file-public') {
            return {access_token => ''};
          } elsif ($repo_type eq 'file-private') {
            return {access_token => ''};
          } else {
            die "Can't pull repository of type |$repo_type|";
          }
          return $app->account_server (q</token>, {
            account_id => $owner->{account_id},
            server => $server,
          });
        })->then (sub {
          my $json = $_[0];
          my $token = $json->{access_token};
          return $app->throw_error (403, reason_phrase => 'The repository owner has no access token')
              unless defined $token;
          $account->{scopes} = $scopes if $args{scopes};
          $account->{access_token} = $token;
          return $account;
        });
      } else {
        return;
      }
    } else { # cannot be read
      return $app->throw_error (404, reason_phrase => 'Repository not found or not accessible') unless $args{html};
      $app->http->set_status (404, reason_phrase => 'Repository not found or not accessible');
      return $app->temma ('tr.repo_not_found.html.tm', {
        app => $app,
        tr => $tr,
      })->then (sub { return $app->throw });
    }
  });
} # check_read

sub get_push_token ($$$$) {
  my ($class, $app, $tr, $scope) = @_;
  my $account_id;
  my $name;
  return $class->session ($app)->then (sub {
    my $session = $_[0];
    $name = $session->{name};
    return $app->throw_error (403, reason_phrase => 'Need to login')
        unless defined ($account_id = $session->{account_id});
  })->then (sub {
    return $app->db->select ('repo_access', {
      repo_url => Dongry::Type->serialize ('text', $tr->url),
      account_id => Dongry::Type->serialize ('text', $account_id),
    }, fields => ['data'], limit => 1);
  })->then (sub {
    my $row = $_[0]->first_as_row;
    my $ok = 0;
    if (defined $row) {
      my $scopes = $row->get ('data');
      if ($scopes->{$scope}) {
        $ok = 1;
      } elsif ($scope =~ m{^edit/} and $scopes->{edit}) {
        $ok = 1;
      }
    }
    return $app->throw_error (403, reason_phrase => "Permission for the |$scope| scope is required by this operation")
        unless $ok;
  })->then (sub {
    return $app->db->select ('repo_access', {
      repo_url => Dongry::Type->serialize ('text', $tr->url),
      is_owner => 1,
    }, fields => ['account_id'], limit => 1);
  })->then (sub {
    my $owner = $_[0]->first;
    return $app->throw_error (403, reason_phrase => 'The repository has no owner') unless defined $owner;
    my $server;
    my $repo_type = $tr->repo_type;
    if ($repo_type eq 'github') {
      $server = 'github';
    } elsif ($repo_type eq 'ssh') {
      $server = 'ssh';
    } elsif ($repo_type eq 'file-public') {
      return {access_token => ''};
    } elsif ($repo_type eq 'file-private') {
      return {access_token => ''};
    } else {
      die "Can't pull repository of type |$repo_type|";
    }
    return $app->account_server (q</token>, {
      account_id => $owner->{account_id},
      server => $server,
    });
  })->then (sub {
    my $json = $_[0];
    my $token = {access_token => $json->{access_token},
                 name => $name, account_id => $account_id};
    return $app->throw_error (403, reason_phrase => 'The repository owner has no GitHub access token')
        unless defined $token->{access_token};

    return $app->db->select ('repo', {
      repo_url => Dongry::Type->serialize ('text', $tr->url),
    }, fields => ['is_public'])->then (sub {
      my $repo = $_[0]->first;
      if (defined $repo) {
        $token->{requires_token_for_pull} = 1 unless $repo->{is_public};
      }
    })->then (sub { return $token });
    # XXX name/email for git author
  });
} # get_push_token

sub edit_text_set ($$$$$%) {
  my ($class, $app, $tr, $type, $code, %args) = @_;
  $app->start_json_stream if $type eq 'ndjson';
  $app->send_progress_json_chunk ('Checking the repository permission...', [1,6]);
  my $return;
  my $keys;
  return $class->get_push_token ($app, $tr, $args{scope})->then (sub {
    $app->send_progress_json_chunk ('Cloning the remote repository...', [2,6]);
    return $tr->prepare_mirror ($keys = $_[0], $app);
  })->then (sub {
    $app->send_progress_json_chunk ('Cloning the repository...', [3,6]);
    return $tr->clone_from_mirror (push => 1, no_checkout => 1);
  })->then (sub {
    $app->send_progress_json_chunk ('Applying the change...', [4,6]);
    return $code->($keys);
  })->then (sub {
    $return = $_[0];
    my $msg = $app->text_param ('commit_message') // '';
    $msg = $args{default_commit_message} unless length $msg;
    return $tr->commit ($msg);
  })->then (sub {
    my $commit_result = $_[0];
    if ($commit_result->{no_commit}) {
      return $app->send_last_json_chunk (204, 'Not changed', {});
    } else {
      $app->send_progress_json_chunk ('Pushing the repository...',[5,6]);
      return $tr->push->then (sub { # XXX failure
        return $app->send_last_json_chunk (200, 'Saved', $return);
      });
    }
  })->$CatchThenDiscard ($app, $tr);
} # edit_text_set

1;

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
