#!/usr/bin/env perl
use strict;
use warnings;
use DDP;

use File::Spec;
use FindBin;
use lib File::Spec->catfile("$FindBin::Bin", '..', 'lib');
use Local::Crawler ();
use Local::Crawler::Configuration;

Local::Crawler::Configuration->load_config(File::Spec->catfile("$FindBin::Bin", 'crawler.cfg'));
my $crawler = Local::Crawler->new(base_url => Local::Crawler::Configuration->get_option('crawler.base_url'),
                                  max_links => Local::Crawler::Configuration->get_option('crawler.max_links'));
$crawler->start;
$crawler->show_results;
