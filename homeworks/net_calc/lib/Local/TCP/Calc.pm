package Local::TCP::Calc;

use strict;
use warnings;

our $VERSION = v1.0;

sub TYPE_START_WORK {1}
sub TYPE_CHECK_WORK {2}
sub TYPE_CONN_ERR   {3}
sub TYPE_CONN_OK    {4}

sub STATUS_NEW   {1}
sub STATUS_WORK  {2}
sub STATUS_DONE  {3}
sub STATUS_ERROR {4}

sub pack_header {
    my $pkg = shift;
    my $type = shift;
    my $size = shift;
    return pack "LL", $type, $size;
}

sub unpack_header {
    my $pkg = shift;
    my $header = shift;
    my ($type, $size) = unpack "LL", $header;
    return ($type, $size);
}

sub pack_message {
    my $pkg = shift;
    my $tasks = shift;
    return pack "L(L/A*)*", scalar(@$tasks), @$tasks;
}

sub unpack_message {
    my $pkg = shift;
    my $message = shift;
    my ($size, @tasks) = unpack "L(L/A*)*", $message;
    die 'Incorrect format' unless $size == @tasks;
    return \@tasks;
}

1;
