package Local::Crawler;

use strict;
use warnings;

use Local::Crawler::Fetcher;
use Local::Crawler::Parser;
use Local::Crawler::DB;
use Local::Crawler::Configuration;
use AE;
use Guard;

sub new {
    my ($class, %args) = @_;
    die 'Usage: Local::Crawler->new(base_url => $url)' unless $args{base_url};
    my $self = {
        base_url => $args{base_url},
        queue => [$args{base_url}],
        max_links => $args{max_links}
    };
    $self->{base_url} =~ s{/?$}{};
    $self->{db} = Local::Crawler::DB->new;
    return bless $self, $class;
}

sub start {
    my ($self) = @_;
    my $cv = AE::cv;
    $cv->begin;
    my $handler; $handler = sub {
        while (@{$self->{queue}}) {
            my $current_count = $self->{db}->get_count;
            return unless $current_count < $self->{max_links};
            my $url = shift @{$self->{queue}};
            next if $self->{db}->get($url);
            printf "Started %s (%d/%d)\n", $url, $current_count + 1, $self->{max_links};
            $self->{db}->save({url => $url});
            $cv->begin;
            Local::Crawler::Fetcher->fetch($url, sub {
                my ($body, $headers) = @_;
                do {
                    warn "Error while fetching $url: $headers->{Status}, $headers->{Reason}\n";
                    $self->{db}->delete($url);
                    $cv->end;
                    return;
                } unless $body && $headers->{Status} =~ /^2/;
                my $current_ready_count = $self->{db}->get_ready_count;
                do {
                    $self->{db}->delete($url);
                    $cv->end;
                    return;
                } unless $current_ready_count < $self->{max_links};
                printf "Finished %s (%d/%d)\n", $url, $current_ready_count + 1, $self->{max_links};
                my $size = length $body;
                $self->{db}->update({url => $url, size => $size, body => $body});
                my $urls;
                eval {
                    $urls = Local::Crawler::Parser->extract_links($body);
                };
                do {
                    warn "Error while parsing $url: $@";
                    $cv->end;
                    return;
                } if $@;
                my @filtered_urls = $self->_filter_urls($urls, $url);
                push @{$self->{queue}}, @filtered_urls;
                $handler->();
                $cv->end;
            });
        }
    }; $handler->();
    $cv->end;
    $cv->recv;
    print "Totally crawled ${\do{$self->{db}->get_ready_count}} links\n";
}

sub show_results {
    my ($self) = @_;
    my $top_count = Local::Crawler::Configuration->get_option('crawler.top_count');
    $top_count //= 10;
    print "TOP-10\n";
    my @pages = $self->{db}->get_top($top_count);
    for my $page (@pages) {
        printf("%s -> %d\n", $page->{url}, $page->{size});
    }
    my $overall_size = $self->{db}->get_overall_size;
    print "Overall size: $overall_size\n";
}

sub _filter_urls {
    my ($self, $urls, $base_url) = @_;
    my @filtered_urls;
    for my $url (@$urls) {
        next unless $url;
        if ($url =~ m{^http://([^/]+)}) {
            my $host = $1;
            ($host) = split /\//, $host;
            my $base_host = $self->{base_url};
            $base_host =~ s{^http://(?:www\.)?}{};
            next if $host !~ m{(?:^|\.)$base_host/?$};
        }
        elsif ($url =~ m{://} || $url =~ m{^mailto:}) {
            next;
        }
        elsif ($url =~ m{^\.\./}) {
            $base_url =~ m{^(.*)/.*$};
            $url = "$1/$url";
        }
        else {
            $url =~ s{^/?}{};
            $base_url =~ s{/?$}{};
            $base_url =~ m{^(http://[^/]+)/?};
            $url = "$1/$url";
        }
        push @filtered_urls, $url unless $self->{db}->get($url);
    }
    return @filtered_urls;
}

1;
