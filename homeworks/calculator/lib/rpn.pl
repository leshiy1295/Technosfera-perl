=head1 DESCRIPTION

Эта функция должна принять на вход арифметическое выражение,
а на выходе дать ссылку на массив, содержащий обратную польскую нотацию
Один элемент массива - это число или арифметическая операция
В случае ошибки функция должна вызывать die с сообщением об ошибке

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
use FindBin;
require "$FindBin::Bin/../lib/tokenize.pl";

sub rpn {
	my $expr = shift;
	my $source = tokenize($expr);

	my @rpn;
	my %priority = (
		'U-' => 3,
		'U+' => 3,
		'^' => 3,
		'*' => 2,
		'/' => 2,
		'+' => 1,
		'-' => 1,
		'(' => 0,
		')' => 0
	);

	my @stack;
	for my $elem (@$source) {
		given ($elem) {
			when ($elem =~ /^\d*\.?\d*(?:e[+-]?\d+)?$/) {
				push @rpn, $elem;
			}
			when ("(") {
				push @stack, '(';
			}
			when (")") {
				while ($stack[-1] ne '(') {
					push @rpn, pop @stack;
				}
				pop @stack;
			}
			when (m{^(?:U[+-]|[*/^+-])$}) {
				if ($elem =~ /^(?:U[+-]|\^)/) { # Правоассоциативная операция
					while (@stack && $priority{$elem} < $priority{$stack[-1]}) {
						push @rpn, pop @stack;
					}
				} else { # Левоассоциативная операция
					while (@stack && $priority{$elem} <= $priority{$stack[-1]}) {
						push @rpn, pop @stack;
					}
				}
				push @stack, $elem;
			}
			default {
				die "Unknown symbol '$elem'";
			}
		}
	}
	push @rpn, reverse @stack;

	return \@rpn;
}

1;
