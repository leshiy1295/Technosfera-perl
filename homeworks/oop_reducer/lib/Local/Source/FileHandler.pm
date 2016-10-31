package Local::Source::FileHandler;
use parent 'Local::Source';

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Source::FileHandler - отдаёт построчно содержимое файла, дескриптор которого передаётся в конструкторе в параметре fh.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub next {
  my $self = shift;
  my $fh = $self->{_fh};
  my $string = <$fh>;
  chomp $string if $string;
  return $string;
}

sub new {
  my ($class, %args) = @_;
  my $object = $class->SUPER::new(%args);
  $object->{_fh} = $args{fh};
  return $object;
}

1;
