package Local::JSONParser;

use strict;
use warnings;

our $VERSION = v1.0;

use base qw(Exporter);
our @EXPORT_OK = qw( parse_json );
our @EXPORT = qw( parse_json );

sub extract_object {
  my $source_ref = shift;
  my $object = {};
  for ($$source_ref) {
    return undef unless /\G\s*\{\s*/gc; # Открывающаяся скобка
    my $has_keys = 1;
    my $comma_found = undef;
    my $is_first_value = 1;
    while ($has_keys) {
      my $string = extract_string($source_ref);
      if ($string) {
        die qq/No comma found before key '$string' on pos /, pos unless $is_first_value || $comma_found; # если перед не первым значением не обнаружено запятой
        die_on_pos(pos) unless /\G\s*:\s*/gc; # должен быть символ :
        my ($has_value, $value) = extract_value($source_ref);
        die_on_pos(pos) unless $has_value; # если значения не найдено, то в выражении есть ошибка
        $object->{$string} = $value; # сохраняем найденное значение в хеш
        $comma_found = /\G\s*,\s*/gc; # все значения, кроме первого, должны идти через запятую
        $is_first_value = undef;
      } else {
        die_on_pos(pos) if $comma_found; # если нашли висячую запятую, то выбрасываем ошибку
        $has_keys = undef;
      }
    }
    die_on_pos(pos) unless /\G\s*\}\s*/gc; # после всех значений должна быть закрывающаяся скобка
  }
  return $object; # если такая найдена, то возвращаем полученный объект
}

sub extract_array {
  my $source_ref = shift;
  my $array = [];
  for ($$source_ref) {
    return undef unless /\G\s*\[\s*/gc; # Открывающаяся скобка
    my $is_first_value = 1;
    my $comma_found = undef;
    my $has_values = 1;
    while ($has_values) {
      my ($has_value, $value) = extract_value($source_ref);
      if ($has_value) {
        die qq/No comma found before value '$value' on pos /, pos unless $is_first_value || $comma_found; # если перед не первым значением не обнаружено запятой
        push @$array, $value; # добавляем найденное значение в массив
        $comma_found = /\G\s*,\s*/gc; # все значения, кроме первого, должны идти через запятую
        $is_first_value = undef; # дальнейшие значения должны идти через ,
      } else {
        die_on_pos(pos) if $comma_found; # если нашли висячую запятую, то выбрасываем ошибку
        $has_values = undef;
      }
    }
    die_on_pos(pos) unless /\G\s*\]\s*/gc; # после всех значений должна быть закрывающаяся скобка
  }
  return $array; # если такая найдена, то возвращаем полученный объект
}

sub extract_value {
  my $source_ref = shift;
  my $value = extract_string($source_ref);
  return 1, $value if $value;
  $value = extract_number($source_ref);
  return 1, $value if $value;
  $value = extract_object($source_ref);
  return 1, $value if $value;
  $value = extract_array($source_ref);
  return 1, $value if $value;
  return 1, undef if /\G\s*null\s*/gc;
  use JSON::XS::Boolean;
  #return 1, do { bless \(my $dummy = 1), "JSON::XS::Boolean" } if /\G\s*true*\s*/gc;
  return 1, $JSON::XS::true if /\G\s*true*\s*/gc;
  #return 1, do { bless \(my $dummy = 0), "JSON::XS::Boolean" } if /\G\s*false\s*/gc;
  return 1, $JSON::XS::false if /\G\s*false*\s*/gc;
  return undef;
}

sub extract_string {
  my $source_ref = shift;
  my @escaped_symbols = qw(" / \\\\ n b f r t);
  return undef unless $$source_ref =~ m<
    \G
    "                                 # Открывающаяся кавычка
    (                                 # Захватываем строку
      (?:
        [^ \cA-\cZ " \\]                # Любой юникодный символ кроме " или \ или символа управления
      |                                 # или
        \\                              # символ \
        (?:
          [{join "", @escaped_symbols} u] # Любой из символов из списка
        |                                 # или
          u[0-9 A-F a-f]{4}               # код юникод-символа с ровно 4 hex-цифрами
        )
      |
        [ ]                             # или пробел (не допускаем спец. символы, как \t\n.., которые есть в \s)
      )*                                # Захватываем все такие символы, их может и не быть
    )
    "                                 # Закрывающаяся кавычка
    >xgc;
  my $string = $1;
  $string =~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/ge; # меняем юникод-символы на читаемые
  # интерполируем escape-последовательности
  my %interpolated_escapes = ((map { $_, $_ } qw(\\ / ")),
                              ('n' => "\n", 'b' => "\b", 'f' => "\f", 'n' => "\n", 'r' => "\r", 't' => "\t"));
  $string =~ s<\\([{join "",@escaped_symbols}])><$interpolated_escapes{$1}>ge;
  return $string;
}

sub extract_number {
  my $source_ref = shift;
  return undef unless $$source_ref =~ m{
    \G
    (
      -?                       # унарный минус
      (?:
        0                      # 0
      |                        # или
        [1-9]\d*               # число без незначащих нулей
      )
      (?:
        \.                     # точка
        \d+                    # хотя бы одна цифра
      )?                       # необязательный блок
      (?:
        [eE]                   # e или E
        (?:\+|\-)?             # необязательный + или -
        \d+                    # хотя бы одна цифра
      )?                       # необязательный блок
    )
  }xgc;
  return 0+$1; # Превращаем найденное число в виде строки в число
}

sub die_on_pos {
  my $pos = shift;
  die 'Incorrect format at pos ', $pos;
}

sub parse_json {
	my $source = shift;

=pod
  use JSON::XS;
	return JSON::XS->new->utf8->decode($source);
=cut

  my $json_object = {};

  use Encode qw/decode_utf8/;
  $source = decode_utf8($source);

  for ($source) {
    /^/gc; # начинаем просмотр с самого начала строки
    $json_object = extract_object(\$source);
    if (!$json_object) { # если это не объект
      $json_object = extract_array(\$source); # проверяем на то, является ли строка JSON-массивом
    }
    die_on_pos(pos) unless $json_object;
    die_on_pos(pos) unless /\G\s*$/gc;
  }

	return $json_object;
}

1;
