package Local::Habr::Printer;

use strict;
use warnings;
use feature 'fc';
use Encode qw(decode);

use Local::Habr::Printer::JSON ();
use Local::Habr::Printer::JSONL ();

our $VERSION = v1.0;

sub render_result {
    my ($class, $result, $format) = @_;
    my $rendered_result;
    if (fc($format) eq 'json') {
        $rendered_result = Local::Habr::Printer::JSON->render($result);
    }
    elsif (fc($format) eq 'jsonl') {
        $rendered_result = Local::Habr::Printer::JSONL->render($result);
    }
    if (ref $rendered_result eq 'ARRAY') {
        for my $row (@$rendered_result) {
            $row = decode('utf8', $row);
            print $row, "\r\n";
        }
    }
    else {
        $rendered_result = decode('utf8', $rendered_result);
        print $rendered_result, "\r\n";
    }
}

1;
