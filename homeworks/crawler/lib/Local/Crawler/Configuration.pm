package Local::Crawler::Configuration;
use strict;
use warnings;

use Config::Simple ();

our $VERSION = v1.0;

my $config = {};

sub load_config {
    my ($class, $config_file) = @_;
    Config::Simple->import_from($config_file, $config);
}

sub get_option {
    my ($class, $option) = @_;
    return $config->{$option};
}

1;
