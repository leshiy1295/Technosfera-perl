package Local::Habr::Layer::Network::Fetcher;

use strict;
use warnings;

use Encode qw(decode);

use LWP::UserAgent ();
use Local::Habr::Layer::Network::Parser ();
use List::MoreUtils;

our $VERSION = v1.0;

our $BASE_URL = 'https://habrahabr.ru';

sub fetch_html {
    my ($self, $url_end) = @_;
    my $ua = LWP::UserAgent->new;
    my $url = sprintf('%s%s', $BASE_URL, $url_end);
    my $req = HTTP::Request->new(
        GET => $url
    );
    my $res = $ua->request($req);
    my $result_html = '';
    if ($res->is_success) {
        $result_html = $res->content;
    }
    else {
        die "$url -> ${\do{$res->status_line}}";
    }
    $result_html = decode('utf8', $result_html);
    return $result_html;
}

sub get_result {
    my ($class, $command, $keys) = @_;
    my $result;
    my $html;

    if ($command eq 'user') {
        if ($keys->{name}) {
            $html = $class->fetch_html("/users/$keys->{name}");
            $result = Local::Habr::Layer::Network::Parser->parse_html($html, ['user']);
        }
        elsif ($keys->{post}) {
            $html = $class->fetch_html("/post/$keys->{post}");
            $result = Local::Habr::Layer::Network::Parser->parse_html($html, ['user', 'post']);
            return undef unless $result && $result->{post};
            $result->{post}->{id} = $keys->{post};
        }
        else {
            die q(Incorrect command 'user' format);
        }
    }
    elsif ($command eq 'commenters') {
        if ($keys->{post}) {
            $html = $class->fetch_html("/post/$keys->{post}");
            $result = Local::Habr::Layer::Network::Parser->parse_html($html, ['commenters', 'post', 'user']);
            return undef unless $result && $result->{post} && $result->{commenters};
            $result->{post}->{id} = $keys->{post};
            $class->_update_commenters_with_user_info($result->{commenters}, $keys->{refresh});
        }
        else {
            die q(Incorrect command 'commenters' format);
        }
    }
    elsif ($command eq 'post') {
        if ($keys->{id}) {
            $html = $class->fetch_html("/post/$keys->{id}");
            $result = Local::Habr::Layer::Network::Parser->parse_html($html, ['post', 'commenters', 'user']);
            return undef unless $result && $result->{post} && $result->{commenters};
            $result->{post}->{id} = $keys->{id};
            $class->_update_commenters_with_user_info($result->{commenters}, $keys->{refresh});
        }
        else {
            die q(Incorrect command 'post' format);
        }
    }
    else {
        warn 'Unknown command';
    }
    if ($result->{user}->{should_retry}) {
        $result->{user} = Local::Habr->execute_command('user', {
                name => $result->{user}->{nickname},
                $keys->{refresh} ? (refresh => $keys->{refresh}) : ()
        });
    }

    return $result;
}

sub _update_commenters_with_user_info {
    my ($class, $commenters, $refresh) = @_;
    @$commenters = map { Local::Habr->execute_command('user', {
                            name => $_,
                            $refresh ? (refresh => $refresh) : ()
                         });
                       } List::MoreUtils::uniq @$commenters;
}

1;
