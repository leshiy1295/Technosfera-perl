package Local::Source::Text;
use parent 'Local::Source::Array';

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Text - отдаёт построчно текст, который передаётся в конструктор в параметре text.
Разделитель - \n, но можно изменить параметром конструктора delimiter.

=head1 VERSION

Version 1.02

=cut

our $VERSION = '1.02';

=head1 SYNOPSIS

=cut

sub new {
  my ($class, %args) = @_;
  my $text = $args{text};
  my $delimiter = defined $args{delimiter} ? $args{delimiter} : "\n";
  return $class->SUPER::new(array => [split $delimiter, $text]);
}

1;
