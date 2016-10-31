package Local::Source;

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Source - базовый абстрактный класс, объекты которого отвечают за подачу данных в Reducer.
Отвечает за получение данных, но не их парсинг.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub next {
  my $self = shift;
  die "Not implemented yet";
}

sub new {
  my $class = shift;
  bless {}, $class;
}

1;
