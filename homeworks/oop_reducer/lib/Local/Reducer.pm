package Local::Reducer;

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Reducer - базовый абстрактный класс. Отвечает за непосредственно схлопывания, но абстрагирован от способа получения и парсинга данных.

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

=head1 SYNOPSIS

=cut

sub reduced {
  my $self = shift;
  return $self->{_reduced};
}

sub reduce_all {
  my $self = shift;
  while (defined (my $elem = $self->{_source}->next)) {
    $self->_process_elem($elem);
  }
  return $self->reduced;
}

sub reduce_n {
  my ($self, $n) = @_;
  die "Incorrect n" if $n < 0;
  while ($n-- > 0 && defined (my $elem = $self->{_source}->next)) {
    $self->_process_elem($elem);
  }
  return $self->reduced;
}

sub _process_elem {
  my $self = shift;
  my $elem = shift;
  die "Not implemented yet";
}

sub new {
  my $class = shift;
  my %args = @_;
  my $reducer = {};
  $reducer->{_source} = $args{source};
  $reducer->{_row_class} = $args{row_class};
  $reducer->{_reduced} = $args{initial_value};
  bless $reducer, $class;
}

1;
