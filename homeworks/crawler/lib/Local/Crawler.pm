package Local::Crawler;

use strict;
use warnings;

use AE;
use Guard;
use AnyEvent::HTTP;
use Web::Query;
use Scalar::Util qw(weaken);
use Config::Simple ();

our $VERSION = v1.0;

sub extract_links {
    my ($html) = @_;
    return wq($html)->find('a')->map(sub { my ($i, $elem) = @_; $elem->attr('href'); });
}

$AnyEvent::HTTP::MAX_PER_HOST = 100;

sub fetch {
    my ($url, $cb) = @_;
    my $g;
    $g = http_get $url, sub {
        $cb->(@_);
        undef $g;
    };
    return $g;
}

sub new {
    my ($class, %args) = @_;
    die 'Usage: Local::Crawler->new(config => $config)' unless $args{config};
    my $config = {};
    Config::Simple->import_from($args{config}, $config);
    my $self = {
        base_url => $config->{'crawler.base_url'},
        queue => [$config->{'crawler.base_url'}],
        analyzed => {},
        in_progress => 0,
        pages => [],
        overall_size => 0,
        max_pages => $config->{'crawler.max_pages'},
        config => $config
    };
    $self->{base_url} =~ s{/?$}{};
    return bless $self, $class;
}

sub start {
    my ($self) = @_;
    my $cv = AE::cv;
    $cv->begin;
    my $handler; $handler = sub {
        my $handler = $handler or return;
        while (@{$self->{queue}}) {
            return unless @{$self->{pages}} + $self->{in_progress} < $self->{max_pages};
            my $url = shift @{$self->{queue}};
            next if exists $self->{analyzed}->{$url};
            $self->{analyzed}->{$url} = 1;
            $self->{in_progress} += 1;
            printf "Started %d/%d -> %s\n", @{$self->{pages}} + $self->{in_progress}, $self->{max_pages}, $url;
            $cv->begin;
            fetch($url, sub {
                my ($body, $headers) = @_;
                $self->{in_progress} -= 1;
                do {
                    warn "Error while fetching $url: $headers->{Status}, $headers->{Reason}\n";
                    $cv->end;
                    return;
                } unless $body && $headers->{Status} =~ /^2/;
                do {
                    $cv->end;
                    return;
                } unless @{$self->{pages}} < $self->{max_pages};
                printf "Finished %d/%d -> %s\n", @{$self->{pages}} + 1, $self->{max_pages}, $url;
                my $size = length $body;
                push $self->{pages}, { url => $url, size => $size };
                $self->{overall_size} += $size;
                my $urls;
                eval {
                    $urls = extract_links($body);
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
    weaken($handler);
    print "Totally crawled ${\do{scalar(@{$self->{pages}})}} pages\n";
}

sub show_results {
    my ($self) = @_;
    my $top_count = $self->{config}->{'crawler.top_count'};
    $top_count //= 10;
    print "TOP-$top_count\n";
    my @sorted_pages = sort { $b->{size} <=> $a->{size}; } @{$self->{pages}};
    my @top_pages = splice @sorted_pages, 0, $top_count - 1;
    for my $page (@top_pages) {
        printf("%s -> %d\n", $page->{url}, $page->{size});
    }
    print "Overall size: $self->{overall_size}\n";
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
        push @filtered_urls, $url unless exists $self->{analyzed}->{$url};
    }
    return @filtered_urls;
}

1;
