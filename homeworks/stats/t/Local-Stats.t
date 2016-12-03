# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Local-Stats.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 30;
BEGIN { use_ok('Local::Stats') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

sub get_settings {
    my ($name) = @_;
    return () if $name eq 'empty_m';
    return ('avg') if $name eq 'avg_m';
    return ('cnt') if $name eq 'cnt_m';
    return ('max') if $name eq 'max_m';
    return ('min') if $name eq 'min_m';
    return ('sum') if $name eq 'sum_m';
    return ('avg','cnt','max','min','sum');
}

# Creating Local::Stats object
my $stats_counter = Local::Stats->new(\&get_settings);
isa_ok($stats_counter, 'Local::Stats', 'new returns Local::Stats object');

for my $iteration (0..1) {
    # Addings some stats
    for (0..10) {
        $stats_counter->add('empty_m', $_);
        $stats_counter->add('avg_m', $_);
        $stats_counter->add('cnt_m', $_);
        $stats_counter->add('max_m', $_);
        $stats_counter->add('min_m', $_);
        $stats_counter->add('sum_m', $_);
        $stats_counter->add('m', $_);
    }
    # Checking stats
    my $stats = $stats_counter->stat;
    ok(!exists $stats->{empty_m}, 'no empty_m stats');
    is_deeply($stats->{avg_m}, {avg => 5}, 'stats for avg_m');
    is_deeply($stats->{cnt_m}, {cnt => 11}, 'stats for cnt_m');
    is_deeply($stats->{max_m}, {max => 10}, 'stats for max_m');
    is_deeply($stats->{min_m}, {min => 0}, 'stats for min_m');
    is_deeply($stats->{sum_m}, {sum => 55}, 'stats for sum_m');
    is_deeply($stats->{m}, {avg => 5, cnt => 11, max => 10, min => 0, sum => 55}, 'stats for m');

    # Checking stats reset
    $stats = $stats_counter->stat;
    ok(!exists $stats->{empty_m}, 'still no empty_m stats');
    is_deeply($stats->{avg_m}, {avg => undef}, 'stats for avg_m reset');
    is_deeply($stats->{cnt_m}, {cnt => undef}, 'stats for cnt_m reset');
    is_deeply($stats->{max_m}, {max => undef}, 'stats for max_m reset');
    is_deeply($stats->{min_m}, {min => undef}, 'stats for min_m reset');
    is_deeply($stats->{sum_m}, {sum => undef}, 'stats for sum_m reset');
    is_deeply($stats->{m}, {avg => undef, cnt => undef, max => undef, min => undef, sum => undef}, 'stats for m reset');
}
