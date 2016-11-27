package Local::Crawler::Parser;
use strict;
use warnings;

use Web::Query;

sub extract_links {
    my ($class, $html) = @_;
    return wq($html)->find('a')->map(sub { my ($i, $elem) = @_; $elem->attr('href'); });
}

1;
