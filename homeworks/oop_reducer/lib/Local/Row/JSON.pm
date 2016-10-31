package Local::Row::JSON;
use parent 'Local::Row';

use strict;
use warnings;

use JSON::XS ();
my $utf8_json = JSON::XS->new->utf8;

=encoding utf8

=head1 NAME

Local::Row::JSON - каждая строка - JSON.

=head1 VERSION

Version 1.02

=cut

our $VERSION = '1.02';

=head1 SYNOPSIS

=cut

sub get {
  my ($self, $name, $default) = @_;
  return exists $self->{_parsed_JSON}->{$name} ? $self->{_parsed_JSON}->{$name} : $default;
}

sub new {
  my ($class, %args) = @_;
  my $object = $class->SUPER::new(%args);
  $object->{_parsed_JSON} = $utf8_json->decode($object->{_str});
  return $object;
}

1;
