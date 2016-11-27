package Local::Crawler::Fetcher;
use strict;
use warnings;
use AnyEvent::HTTP;
use Guard;

$AnyEvent::HTTP::MAX_PER_HOST = 100;

sub fetch {
    my ($class, $url, $cb) = @_;
    my $g;
    $g = http_get $url, sub {
        $cb->(@_);
        undef $g;
    };
    return $g;
}

1;
