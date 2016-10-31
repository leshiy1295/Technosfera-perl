package Local::Row;

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Row - базовый абстрактный класc, объекты которого отвечают за парсинг строк из источника.
Отвечает за парсинг данных: формат логов может быть разным, для каждого нужен свой подкласс Row.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub get {
  my ($self, $name, $default) = @_;
  die "Not implemented yet";
}

sub new {
  my ($class, %args) = @_;
  my $object = {};
  $object->{_str} = $args{str};
  bless $object, $class;
}

1;
