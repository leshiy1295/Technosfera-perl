package Local::MusicLibrary;

use strict;
use warnings;
use Exporter qw/import/;

use Local::MusicLibrary::Model ();
use Local::MusicLibrary::ModelProcessor ();
use Local::MusicLibrary::Printer ();
use Local::MusicLibrary::Configuration ();

=encoding utf8

=head1 NAME

Local::MusicLibrary - core music library module

=head1 VERSION

Version 1.1.1

=cut

our $VERSION = v1.1.1;

=head1 SYNOPSIS

=cut

our @EXPORT_OK = qw/saveTrack print/;

sub saveTrack {
  my $trackString = shift;
  Local::MusicLibrary::Model::saveTrack($trackString);
}

sub print {
  my $library = [Local::MusicLibrary::Model::getLibrary()];
  my $config = Local::MusicLibrary::Configuration::getConfiguration();
  Local::MusicLibrary::ModelProcessor::applyConfiguration($library, $config);
  Local::MusicLibrary::Printer::printLibrary($library, $config);
}

1;
