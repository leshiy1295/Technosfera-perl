package Local::Reducer::MinMaxAvg::Reduced;

use strict;
use warnings;

use Class::XSAccessor
  getters => {
    get_max => '_max',
    get_min => '_min',
    get_avg => '_avg',
    get_n => '_n'
  },
  setters => {
    max => '_max',
    min => '_min',
    avg => '_avg',
    n => '_n'
  };

=encoding utf8

=head1 NAME

Local::Reducer::MinMaxAvg::Reduced - объект, возвращаемый при вызове метода reduced у Local::Reducer::MinMaxAvg
Имеет следующие методы: get_max, get_min, get_avg.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub new {
  my ($class, %args) = @_;
  my $object = {};
  $object->{_n} = 0; # количество просмотренных элементов
  ($object->{_max}, $object->{_min}, $object->{_avg}) = @{$args{initial_value}};
  bless $object, $class;
}

1;
