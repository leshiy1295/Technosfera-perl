=head1 DESCRIPTION

Эта функция должна принять на вход арифметическое выражение,
а на выходе дать ссылку на массив, состоящий из отдельных токенов.
Токен - это отдельная логическая часть выражения: число, скобка или арифметическая операция
В случае ошибки в выражении функция должна вызывать die с сообщением об ошибке

Знаки '-' и '+' в первой позиции, или после другой арифметической операции стоит воспринимать
как унарные и можно записывать как "U-" и "U+"

Стоит заметить, что после унарного оператора нельзя использовать бинарные операторы
Например последовательность 1 + - / 2 невалидна. Бинарный оператор / идёт после использования унарного "-"

=cut

use 5.010;
use strict;
use warnings;
use diagnostics;
BEGIN{
	if ($] < 5.018) {
		package experimental;
		use warnings::register;
	}
}
no warnings 'experimental';

sub tokenize($) {
	chomp(my $expr = shift);
	my @res;

	@res = grep /[^\s]/, split m{((?<!e)[+-]|[*/()^]|\s+)}, $expr;

	my $brackets = 0;
	my $numericFound = 1;
	while (my ($i, $symbol) = each @res) {
		given ($symbol) {
			when (/^\d*\.?\d*(?:e[-+]?\d+)?$/) { # Корректное число
				$res[$i] = 0+$symbol; # Venus
				$numericFound = 1;
			}
			when ("(") {
				$brackets += 1;
			}
			when (")") {
				$brackets -= 1;
				die "Wrong brackets sequence" if $brackets < 0;
				die "Not enough arguments for one-arg operation" unless $numericFound;
			}
			when (m{^[+-]$}) {
				if ($i == 0 || $res[$i-1] eq "(" || $res[$i-1] =~ m{^(?:U[+-]|[*/^+-])$}) {
					$res[$i] = "U$symbol";
					$numericFound = 0; # После унарной операции должно быть число
				} else {
					continue; # Проверим +- как бинарную операцию дальше
				}
			}
			when (m{^[*/^+-]$}) {
				die "One-arg operation found before $symbol" if ($res[$i-1] =~ /U[+-]/);
			}
			default {
				die "Bad: '$symbol'";
			}
		}
	}

	die "Wrong brackets sequence" if $brackets != 0;
	die "Not enough arguments for one-arg operation" unless $numericFound;
	return \@res;
}

1;
