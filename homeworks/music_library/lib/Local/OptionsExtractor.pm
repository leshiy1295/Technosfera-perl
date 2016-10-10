package Local::OptionsExtractor;

use strict;
use warnings;

our $VERSION = v1.1;

use Exporter qw/import/;

our @EXPORT_OK = qw/extractConfigurationFromArgs/;

use Local::MusicLibrary::Model ();

use Getopt::Long ();

sub extractConfigurationFromArgs {
  my $args = shift;
  my %modelFieldsFormat = Local::MusicLibrary::Model::MODEL_FIELDS_FORMAT;
  my $config = {
    'columns' => [Local::MusicLibrary::Model::MODEL_FIELDS]
  };

  Getopt::Long::GetOptionsFromArray(
    $args,
    (map { ("$_=$modelFieldsFormat{$_}" => \$config->{$_}) } keys %modelFieldsFormat),
    'sort=s' => sub {
      my ($opt_name, $opt_value) = @_;
      die qq/Invalid value '$opt_value' for option '$opt_name'/ unless defined $modelFieldsFormat{$opt_value};
      $config->{'sort'} = $opt_value;
    },
    'columns=s' => sub {
      my ($opt_name, $opt_value) = @_;
      my @splittedValues = split ',', $opt_value;
      my @wrongValues = grep { not defined $modelFieldsFormat{$_} } @splittedValues;
      die qq/Incorrect columns '@wrongValues' were provided for option '$opt_name'/ if @wrongValues;
      $config->{'columns'} = \@splittedValues;
    }
  ) or die "Error in command arguments\n";

  return $config;
}

1;
