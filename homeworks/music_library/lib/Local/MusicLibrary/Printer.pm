package Local::MusicLibrary::Printer;

use strict;
use warnings;

our $VERSION = v1.1.1;

use Exporter qw/import/;

our @EXPORT_OK = qw/printLibrary/;

use List::Util ();

sub printLibrary {
  my ($library, $config) = @_;
  return unless @$library;
  my $columns = $config->{'columns'};
  return unless @$columns;
  my %columnsWidth;
  foreach my $col (@$columns) {
    $columnsWidth{$col} = List::Util::max(map { length $_->{$col} } @$library);
  }

  my $border = '-' x List::Util::sum(-1, map { $columnsWidth{$_} + 2 + 1 } @$columns);
  print "/$border\\\n";

  print join
          # разделитель строк таблицы
          '|'.join('+', map { '-' x ($columnsWidth{$_} + 2) } @$columns)."|\n",
          map {
            # одна строка таблицы
            my $elem = $_;
            '|'.join('|', map { sprintf " %*s ", $columnsWidth{$_}, $elem->{$_} } @$columns)."|\n"
          } @$library;

  print "\\$border/\n";
}

1;
