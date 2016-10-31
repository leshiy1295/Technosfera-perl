use strict;
use warnings;

use Test::More tests => 12;

use Local::Reducer::MinMaxAvg;
use Local::Source::FileHandler;
use Local::Row::JSON;

my $file = 't/input.txt';
open my $fh, '<:encoding(UTF-8)', $file or die "Can't open file '$file': $!\n";

my $min_max_avg_reducer = Local::Reducer::MinMaxAvg->new(
    field => 'price',
    source => Local::Source::FileHandler->new(fh => $fh),
    row_class => 'Local::Row::JSON',
    initial_value => [undef, undef, undef],
);

my $reduce_result;

$reduce_result = $min_max_avg_reducer->reduce_n(1);
is($reduce_result->get_min, 1, 'get_min reduced 1');
is($reduce_result->get_max, 1, 'get_max reduced 1');
is($reduce_result->get_avg, 1, 'get_avg reduced 1');
is($min_max_avg_reducer->reduced->get_min, 1, 'get_min reducer saved');
is($min_max_avg_reducer->reduced->get_max, 1, 'get_max reducer saved');
is($min_max_avg_reducer->reduced->get_avg, 1, 'get_avg reducer saved');

$reduce_result = $min_max_avg_reducer->reduce_all();
is($reduce_result->get_min, 1, 'get_min reduced all');
is($reduce_result->get_max, 3, 'get_max reduced all');
is($reduce_result->get_avg, 2, 'get_avg reduced all');
is($min_max_avg_reducer->reduced->get_min, 1, 'get_min reducer saved at the end');
is($min_max_avg_reducer->reduced->get_max, 3, 'get_max reducer saved at the end');
is($min_max_avg_reducer->reduced->get_avg, 2, 'get_avg reducer saved at the end');

close $fh;
