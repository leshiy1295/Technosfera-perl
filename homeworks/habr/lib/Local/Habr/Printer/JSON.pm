package Local::Habr::Printer::JSON;

use strict;
use warnings;

use JSON::XS ();

our $VERSION = v1.0;

sub render {
    my ($class, $data) = @_;
    my $result = JSON::XS::encode_json($data);
    return $result;
}

1;
