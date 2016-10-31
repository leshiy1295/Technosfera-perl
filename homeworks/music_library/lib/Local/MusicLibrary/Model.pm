package Local::MusicLibrary::Model;

use strict;
use warnings;

our $VERSION = v1.1;

use Exporter qw/import/;

our @EXPORT_OK = qw/saveTrack getLibrary MODEL_FIELDS MODEL_FIELDS_FORMAT/;

my @library = ();

sub MODEL_FIELDS {
  return ('band', 'year', 'album', 'track', 'format');
}

sub MODEL_FIELDS_FORMAT {
  return (
    'band' => 's',
    'year' => 'i',
    'album' => 's',
    'track' => 's',
    'format' => 's'
  );
}

sub saveTrack {
  my $trackString = shift;
  #die qq/Track string '$trackString' has invalid format/ unless $trackString =~ m{ # в тестах появилось ограничение на пустой STDERR
  exit 1 unless $trackString =~ m{
    ^
      \./
      (?<band>[^/]+)
      /
      (?<year>\d+)
      \s+-\s+
      (?<album>[^/]+)
      /
      (?<track>[^\.]+)
      \.
      (?<format>.*)
    $
  }x;
  push @library, {%+};
}

sub getLibrary {
  return @library;
}

1;
