=head1 DESCRIPTION

Эта функция должна принять на вход ссылку на массив, который представляет из себя обратную польскую нотацию,
а на выходе вернуть вычисленное выражение

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

sub evaluate {
	my $rpn = shift;
	my @stack;

	for my $elem (@$rpn) {
		if ($elem =~ m{^[*/^+-]$}) {
			my $operation = $elem eq '^' ? '**' : $elem;
			die "No operands to complete operation $elem" if @stack < 2;
			my $right = pop @stack;
			my $left = pop @stack;
			push @stack, eval "$left$operation$right";
		} elsif ($elem =~ m{^U([+-])$}) {
			die "No operands to complete operation $elem" if @stack < 1;
			my $operand = pop @stack;
			push @stack, eval "$1 $operand";
		} else {
			push @stack, $elem;
		}
	}

	die "Expected the only one value remained in operands stack - the result of an expression" unless @stack == 1;
	return pop @stack;
}

1;
