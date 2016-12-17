#!/usr/bin/env perl
use strict;
use warnings;
use DDP;

use File::Spec;
use FindBin;
use lib File::Spec->catfile("$FindBin::Bin", '..', 'lib');
use Local::Crawler ();

my $crawler = Local::Crawler->new(config => File::Spec->catfile("$FindBin::Bin", 'crawler.cfg'));
$crawler->start;
$crawler->show_results;
