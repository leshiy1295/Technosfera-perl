#!/usr/bin/env perl

use strict;
use warnings;

use open qw(:std :utf8);
use FindBin;
use File::Spec;
use lib File::Spec->catfile("$FindBin::Bin", '..', 'lib');
use Local::Habr::OptionsParser ();
use Local::Habr ();
use Local::Habr::Printer ();
use Local::Habr::Configuration ();

Local::Habr::Configuration->load_config(File::Spec->catfile("$FindBin::Bin", 'habr.cfg'));
Local::Habr::Configuration->get_option('database.dbi');
Local::Habr->init;
my ($command, $keys, $format) = Local::Habr::OptionsParser->parse_options(\@ARGV);
my $result = Local::Habr->execute_command($command, $keys);
Local::Habr::Printer->render_result($result, $format) if $result;
