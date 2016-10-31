package Local::Reducer::Sum;
use parent 'Local::Reducer';

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Reducer::Sum - суммирует значение поля, указанного в параметре field конструктора, каждой строки лога

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

=head1 SYNOPSIS

=cut

sub _process_elem {
  my ($self, $elem) = @_;
  $self->{_reduced} += $self->{_row_class}->new(str => $elem)->get($self->{_field}, 0);
}

sub new {
  my ($class, %args) = @_;
  my $reducer = $class->SUPER::new(%args);
  $reducer->{_field} = $args{field};
  return $reducer;
}

1;
