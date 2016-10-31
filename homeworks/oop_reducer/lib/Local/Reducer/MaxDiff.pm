package Local::Reducer::MaxDiff;
use parent 'Local::Reducer';

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Reducer::MaxDiff - выясняет максимальную разницу между полями, указанными в параметрах top и bottom конструктора, среди всех строк лога

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

=head1 SYNOPSIS

=cut

sub _process_elem {
  my ($self, $elem) = @_;
  my $topValue = 0+($self->{_row_class}->new(str => $elem)->get($self->{_top}, 0));
  my $bottomValue = 0+($self->{_row_class}->new(str => $elem)->get($self->{_bottom}, 0));
  my $diff = $topValue - $bottomValue;
  $self->{_reduced} = $diff if $diff > $self->reduced;
}

sub new {
  my ($class, %args) = @_;
  my $reducer = $class->SUPER::new(%args);
  $reducer->{_top} = $args{top};
  $reducer->{_bottom} = $args{bottom};
  return $reducer;
}

1;
