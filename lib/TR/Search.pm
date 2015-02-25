package TR::Search;
use strict;
use warnings;
use Promise;
use JSON::PS;
use Web::UserAgent::Functions qw(http_post_data);

sub new_from_config ($$) {
  return bless {config => $_[1]}, $_[0];
} # new_from_config

sub put_data ($$) {
  my ($self, $data) = @_;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    if (keys %{$data->{texts}}) {
      my $prefix = $self->{config}->{es_url_prefix};
      my $auth = [$self->{config}->{es_user},
                  $self->{config}->{es_password}];

      my $repo_url = $data->{repo_url};
      my $repo_path = $data->{repo_path};
      my $repo_license = $data->{repo_license};
      http_post_data
          url => qq<$prefix/texts/_bulk>,
          basic_auth => $auth,
          anyevent => 1,
          content => (join "\x0A", map {
            my $d = {%{$data->{texts}->{$_}},
                     text_id => $_,
#                     _id => $_,
                     repo_url => $repo_url,
                     repo_path => $repo_path,
                     repo_license => $repo_license};
            $d->{ft} = join ' ', grep { defined } map { ($_->{body_0}, $_->{body_1}, $_->{body_2}, $_->{body_3}, $_->{body_4}) } values %{$d->{langs} or {}};
            $d->{pre} = perl2json_chars {map { $_ => $d->{langs}->{$_}->{body_0} } keys %{$d->{langs} or {}}};
            ((perl2json_bytes {index => {}}), (perl2json_bytes $d));
          } keys %{$data->{texts}}),
          cb => sub {
            my (undef, $res) = @_;
            if ($res->is_success) {
              $ok->();
            } else {
              $ng->();
            }
          };
    } else {
      $ok->();
    }
  });
} # put_data

sub search ($$) {
  my ($self, $word) = @_;
  #katakana_to_hiragana $word;
  #$word =~ s/\s+/ /g;
  #$word =~ s/^ //;
  #$word =~ s/ $//;

  ## <http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html>
  $word =~ s{([+\-=&|><!(){}\[\]^"~*?:\\/])}{\\$1}g;
  $word = qq{"$word"};

  my $prefix = $self->{config}->{es_url_prefix};
  my $auth = [$self->{config}->{es_user},
              $self->{config}->{es_password}];
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    http_post_data
        url => qq<$prefix/texts/_search?fields=repo_url,repo_path,repo_license,text_id,pre>,
        basic_auth => $auth,
        content => perl2json_bytes {
          query => {
            query_string => {
              query => $word,
              default_field => 'ft',
            },
          },
        },
        anyevent => 1,
        cb => sub {
          my (undef, $res) = @_;
          if ($res->is_success) {
            my $result = [];
            my $json = json_bytes2perl $res->content;
            push @$result, map {
              +{score => $_->{_score},
                repo_url => $_->{fields}->{repo_url}->[0],
                repo_branch => 'master',
                repo_path => $_->{fields}->{repo_path}->[0],
                repo_license => $_->{fields}->{repo_license}->[0],
                text_id => $_->{fields}->{text_id}->[0],
                preview => (json_chars2perl ($_->{fields}->{pre}->[0] // '{}')) || {}};
            } @{$json->{hits}->{hits}};
            $ok->($result);
          } else {
            $ng->();
          }
        };
  });
} # search

1;
