package Local::TCP::Calc::Client;

use strict;
use warnings;

our $VERSION = v1.0;

use IO::Socket;
use Local::TCP::Calc ();
use Carp;
use PerlIO::gzip;
use File::Path qw/make_path/;

sub set_connect {
    my $pkg = shift;
    my $ip = shift;
    my $port = shift;
    warn("[CLIENT]> Connecting to server");
    my $server = IO::Socket::INET->new(
        PeerAddr => $ip,
        PeerPort => $port,
        Proto => 'tcp',
        Type => SOCK_STREAM
    ) or die "[CLIENT]> Can't connect to server: $@.";
    my $expected_header_data_size = 8;
    my $header_data;
    my $bytes_read = $server->sysread($header_data, $expected_header_data_size);
    $bytes_read == $expected_header_data_size
        or _fail_with_error( "[CLIENT]> Incorrect size of header. $expected_header_data_size expected.", $server );
    my ($status, $message_size) = Local::TCP::Calc->unpack_header($header_data);
    _fail_with_error( '[CLIENT]> All workers are busy', $server ) if $status == Local::TCP::Calc::TYPE_CONN_ERR();
    _fail_with_error( '[CLIENT]> Unknown status.', $server ) unless $status == Local::TCP::Calc::TYPE_CONN_OK();
    _fail_with_error( '[CLIENT]> Unexpected message.', $server ) unless $message_size == 0;
    return $server;
}

sub do_request {
    my $pkg = shift;
    my $server = shift;
    my $type = shift;
    my $message = shift;

    warn("[CLIENT]> Sending message");
    use DDP;
    DDP::p $message;

    my $packed_message_data = Local::TCP::Calc->pack_message($message);
    my $packed_header_data = Local::TCP::Calc->pack_header($type, length $packed_message_data);
    my $overall_data = $packed_header_data . $packed_message_data;
    my $overall_data_size = length $overall_data;

    $server->autoflush(1);

    # отправляем запрос на сервер
    $server->syswrite($overall_data, $overall_data_size) == $overall_data_size or _fail_with_error( "[CLIENT]> Incorrect sent data size. $overall_data_size expected", $server );

    # читаем заголовок
    my $expected_header_data_size = 8;
    my $header_data;
    my $bytes_read = $server->sysread($header_data, $expected_header_data_size);
    $bytes_read == $expected_header_data_size or _fail_with_error( "[CLIENT]> Incorrect size of header. $expected_header_data_size expected.", $server );
    my ($status, $message_size) = Local::TCP::Calc->unpack_header($header_data);
    if ($status == Local::TCP::Calc::STATUS_NEW() && $type == Local::TCP::Calc::TYPE_CHECK_WORK()
            || $status == Local::TCP::Calc::STATUS_WORK()) {
        _fail_with_error( '[CLIENT]> No message expected.', $server ) if $message_size != 0;
    }
    elsif ($status == Local::TCP::Calc::STATUS_NEW() && $type == Local::TCP::Calc::TYPE_START_WORK()
            || $status == Local::TCP::Calc::STATUS_DONE()
            || $status == Local::TCP::Calc::STATUS_ERROR()) {
        _fail_with_error( '[CLIENT]> Empty message.', $server ) if $message_size == 0;
    }
    else {
        _fail_with_error( '[CLIENT]> Unknown status.', $server );
    }

    my $struct = [];
    # читаем тело сообщения
    if ($message_size) {
        my $message_data;
        $bytes_read = $server->sysread($message_data, $message_size);
        $bytes_read == $message_size or _fail_with_error( "[CLIENT]> Incorrect size of message. $message_size expected.", $server );
        if ($status == Local::TCP::Calc::STATUS_DONE() || $status == Local::TCP::Calc::STATUS_ERROR()) {
            eval {
                $message_data = _ungzip_data($message_data, $message->[0]);
            1;} or _fail_with_error( $@, $server );
        }
        my $message_data_struct = Local::TCP::Calc->unpack_message($message_data);
        if ($status == Local::TCP::Calc::STATUS_DONE() || $status == Local::TCP::Calc::STATUS_ERROR()) {
            eval {
                _save_result_in_file($message_data_struct, $message->[0]);
            1;} or _fail_with_error( $@, $server );
        }
        push @$struct, @$message_data_struct;
    }

    if ($type == Local::TCP::Calc::TYPE_CHECK_WORK()) {
        # в запросах этого типа требуется первым элементом передавать статус задачи
        unshift @$struct, $status;
    }

    close $server;

    warn("[CLIENT]> Received response from server");
    DDP::p @$struct;

    return @$struct;
}

sub _ungzip_data {
    my $gzipped_data = shift;
    my $task_id = shift;
    my $tmp_gzip_file = "/tmp/task_$task_id.gz";

    open my $fh, '>:raw', $tmp_gzip_file or die "[CLIENT]> Can't create gzip file with result";
    print $fh $gzipped_data;
    close $fh;

    open $fh, '<:gzip', $tmp_gzip_file or die "[CLIENT]> Can't open gzip file with result";
    my $data = do { local $/; <$fh>; };
    close $fh;
    unlink $tmp_gzip_file;
    return $data;
}

sub _save_result_in_file {
    my $results = shift;
    my $task_id = shift;

    make_path('./results');
    my $result_file = "./results/task_$task_id";

    open my $fh, '>:encoding(UTF-8)', $result_file or die "[CLIENT]> Can't create gzip file with result";
    for my $result (@$results) {
        print $fh $result, "\n";
    }
    close $fh;
}

sub _fail_with_error {
    my $error = shift;
    my $server = shift;
    close $server;
    confess $error;
}

1;

