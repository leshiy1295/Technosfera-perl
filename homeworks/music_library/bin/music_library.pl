#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Local::MusicLibrary ();
use Local::OptionsExtractor ();
use Local::MusicLibrary::Configuration ();

my $config = Local::OptionsExtractor::extractConfigurationFromArgs(\@ARGV);
Local::MusicLibrary::Configuration::saveConfiguration($config);

while (<>) {
  Local::MusicLibrary::saveTrack($_);
}

Local::MusicLibrary::print();
