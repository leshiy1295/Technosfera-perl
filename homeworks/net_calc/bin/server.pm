use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Local::TCP::Calc::Server;

my $port = 3456;
Local::TCP::Calc::Server->start_server($port, max_queue_task => 2, max_worker => 3, max_forks_per_task => 8, max_receiver => 2);
