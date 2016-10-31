package Local::Reducer::MinMaxAvg;
use parent 'Local::Reducer';

use Local::Reducer::MinMaxAvg::Reduced;

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Reducer::MinMaxAvg - считает минимум, максимум и среднее по полю, указанному в параметре field.
Результат (reduced) отдаётся в виде объекта с методами get_max, get_min, get_avg.

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

=head1 SYNOPSIS

=cut

sub _process_elem {
  my ($self, $elem) = @_;
  my $value = 0+($self->{_row_class}->new(str => $elem)->get($self->{_field}, 0));
  $self->{_reduced}->min($value) if !defined $self->{_reduced}->get_min || $value < $self->{_reduced}->get_min;
  $self->{_reduced}->max($value) if !defined $self->{_reduced}->get_max || $value > $self->{_reduced}->get_max;
  $self->{_reduced}->avg(defined $self->{_reduced}->get_avg ?
                          ($self->{_reduced}->get_avg * $self->{_reduced}->get_n + $value) / ($self->{_reduced}->get_n + 1) :
                          $value);
  $self->{_reduced}->n($self->{_reduced}->get_n + 1);
}

sub new {
  my $class = shift;
  my %args = @_;
  my $reducer = $class->SUPER::new(@_);
  $reducer->{_field} = $args{field};
  $reducer->{_reduced} = Local::Reducer::MinMaxAvg::Reduced->new(initial_value => $args{initial_value});
  return $reducer;
}

1;
