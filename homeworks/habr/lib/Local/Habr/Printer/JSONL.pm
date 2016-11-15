package Local::Habr::Printer::JSONL;

use Local::Habr::Printer::JSON ();

use strict;
use warnings;

our $VERSION = v1.0;

sub render {
    my ($class, $data) = @_;
    my $result;
    if (ref $data eq 'ARRAY') {
        $result = [];
        for my $elem (@$data) {
            $elem = Local::Habr::Printer::JSON->render($elem);
            push $result, $elem;
        }
    }
    else {
        $result = Local::Habr::Printer::JSON->render($data);
    }
    return $result;
}

1;
