use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib/";

use Local::TCP::Calc::Client;

use DDP;

my $srv;
my @res;
my @working = ();

$srv = Local::TCP::Calc::Client->set_connect('127.0.0.1', 3456);
@res = Local::TCP::Calc::Client->do_request($srv, Local::TCP::Calc::TYPE_START_WORK(), ['1+1']);
push @working, $res[0];
$srv = Local::TCP::Calc::Client->set_connect('127.0.0.1', 3456);
@res = Local::TCP::Calc::Client->do_request($srv, Local::TCP::Calc::TYPE_START_WORK(), ['4*3']);
push @working, $res[0];
p @working;
while (@working) {
    my $id = shift @working;
    eval {
        $srv = Local::TCP::Calc::Client->set_connect('127.0.0.1', 3456);
        @res = Local::TCP::Calc::Client->do_request($srv, Local::TCP::Calc::TYPE_CHECK_WORK(), [$id]);
        if ($res[0] < Local::TCP::Calc::STATUS_DONE()) {
            push @working, $id;
        } else {
            DDP::p @res;
        }
    };
    push @working, $id if $@;
    sleep(1);
}
