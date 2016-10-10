package Local::MusicLibrary::Configuration;

use strict;
use warnings;

our $VERSION = v1.1;

use Exporter qw/import/;

our @EXPORT_OK = qw/saveConfiguration getConfiguration/;

my %config = ();

sub saveConfiguration {
  my $configRef = shift;
  %config = (%$configRef);
}

sub getConfiguration {
  my %configCopy = %config;
  return \%configCopy;
}

1;
