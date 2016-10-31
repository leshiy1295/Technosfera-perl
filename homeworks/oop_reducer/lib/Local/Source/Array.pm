package Local::Source::Array;
use parent 'Local::Source';

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Source::Array - отдаёт поэлементно массив, который передаётся в конструктор в параметре array.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub next {
  my $self = shift;
  shift @{$self->{_array}};
}

sub new {
  my ($class, %args) = @_;
  my $object = $class->SUPER::new;
  $object->{_array} = [@{$args{array}}]; # копируем массив
  return $object;
}

1;
