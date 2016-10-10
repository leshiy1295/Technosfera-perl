package Local::MusicLibrary::ModelProcessor;

use strict;
use warnings;
use feature 'fc';

our $VERSION = v1.1;

use Exporter qw/import/;

our @EXPORT_OK = qw/applyConfiguration/;

use Local::MusicLibrary::Model ();

sub filterLibrary {
  my ($library, $config) = @_;
  my %modelFieldsFormat = Local::MusicLibrary::Model::MODEL_FIELDS_FORMAT;
  @$library = grep {
    my $shouldBeIncluded = 1;
    for my $k (keys %modelFieldsFormat) {
      if (defined $config->{$k}) {
        if ($modelFieldsFormat{$k} eq 'i') {
          $shouldBeIncluded = 0+$_->{$k} == 0+$config->{$k};
        } elsif ($modelFieldsFormat{$k} eq 's') {
          $shouldBeIncluded = fc($_->{$k}) eq fc($config->{$k});
        }
        last unless $shouldBeIncluded;
      }
    }
    $shouldBeIncluded;
  } @$library;
}

sub sortLibrary {
  my ($library, $config) = @_;
  my %modelFieldsFormat = Local::MusicLibrary::Model::MODEL_FIELDS_FORMAT;
  if ($modelFieldsFormat{$config->{'sort'}} eq 'i') {
    @$library = sort { $a->{$config->{'sort'}} <=> $b->{$config->{'sort'}} } @$library;
  } elsif ($modelFieldsFormat{$config->{'sort'}} eq 's') {
    @$library = sort { fc($a->{$config->{'sort'}}) cmp fc($b->{$config->{'sort'}}) } @$library;
  }
}

sub applyConfiguration {
  my ($library, $config) = @_;
  filterLibrary($library, $config);
  sortLibrary($library, $config) if defined $config->{'sort'};
}

1;
