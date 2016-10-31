package Local::Row::Simple;
use parent 'Local::Row';

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Row::Simple - каждая строка - набор пар ключ:значение, соединённых запятой. В ключах и значениях не может быть двоеточий и запятых.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub get {
  my ($self, $name, $default) = @_;
  return defined $self->{_parsedData}->{$name} ? $self->{_parsedData}->{$name} : $default;
}

sub new {
  my ($class, %args) = @_;
  my $object = $class->SUPER::new(%args);
  $object->{_parsedData} = { map { my ($key, $value) = split ':', $_; $key => $value } split ',', $object->{_str} };
  return $object;
}

1;
