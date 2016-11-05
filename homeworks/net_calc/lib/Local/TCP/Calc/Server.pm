package Local::TCP::Calc::Server;

use strict;
use warnings;
use Local::TCP::Calc ();
use Local::TCP::Calc::Server::Queue ();
use Local::TCP::Calc::Server::Worker ();
use POSIX qw(:sys_wait_h);
use IO::Socket;
use Carp;
use Errno qw/EINTR/;
use PerlIO::gzip;

our $VERSION = v1.0;

use FindBin;

my $max_worker;

my $in_process = 0;

my $pids_master = {};
my $pids_worker = {};

my $receiver_count = 0;
my $max_forks_per_task = 0;
my $q;

sub REAPER {
    while ( my $pid = waitpid(-1, WNOHANG) ) {
        # не обрабатываем чужих детей
        last if $pid == -1;
        next if !exists $pids_master->{$pid} && !exists $pids_worker->{$pid};

        warn "[SERVER][$$]> IN REAPER WITH PID: $pid";
        if ( WIFEXITED($?) ) {
            my $status = $? >> 8;
            #warn "$pid exited with status $status";
            if (exists $pids_master->{$pid}) {
                delete $pids_master->{$pid};
                --$receiver_count;
                warn "[SERVER][$$]> Connection closed -> Totally connected: $receiver_count";
            }
            if (exists $pids_worker->{$pid}) {
                delete $pids_worker->{$pid};
                --$in_process;
            }
            check_queue_workers($q);
        }
        else {
            #warn "Process $pid sleeps";
        }
    }
};
$SIG{CHLD} = \&REAPER;

sub start_server {
    my ($pkg, $port, %opts) = @_;
    $max_worker         = $opts{max_worker} // die "max_worker required";
    $max_forks_per_task = $opts{max_forks_per_task} // die "max_forks_per_task required";
    my $max_receiver    = $opts{max_receiver} // die "max_receiver required";
    my $max_queue_task  = $opts{max_queue_task} // die "max_queue_task required";

    my $server = IO::Socket::INET->new(
        LocalPort => $port,
        Type => SOCK_STREAM,
        ReuseAddr => 1,
        Listen => $max_receiver,
    ) or die "Can't create server: $@";

    $server->autoflush(1);

    $q = Local::TCP::Calc::Server::Queue->new(
        max_task => $max_queue_task,
        queue_filename => "/tmp/queue_$port"
    );
    $q->init();

    while (1) {
        my $client = $server->accept();
        if (!$client) {
            next if $! == EINTR;
            warn "ERROR ?? -> $$";
            last;
        }
        if ($receiver_count < $max_receiver) {
            ++$receiver_count;
            my $header_data = Local::TCP::Calc->pack_header(Local::TCP::Calc::TYPE_CONN_OK(), 0);
            my $header_data_size = length $header_data;
            if ($client->syswrite($header_data, $header_data_size) != $header_data_size) {
                _send_conn_error_response( "[SERVER]> Incorrect sent data size. $header_data_size expected", $client );
                --$receiver_count;
                next;
            }
            # дальше обрабатываем клиента в отдельном процессе
            my $server_worker = fork();
            if (!defined $server_worker) {
                _send_conn_error_response( "[SERVER]> Can't fork server worker: $!", $client );
                --$receiver_count;
                next;
            }
            if ($server_worker) {
                # сохраняем воркеров в отдельной структуре, чтобы отлавливать их CHLD
                $pids_master->{$server_worker} = 1;
                warn "[SERVER][$$]> Client connected. Totally connected: $receiver_count";
                warn "[SERVER][$$]> CREATED WORKER FOR CLIENT WITH PID: $server_worker";
                close $client;
                next;
            }
            close $server;

            my $expected_header_data_size = 8;
            my $bytes_read = $client->sysread($header_data, $expected_header_data_size);
            # если по какой-то причине сокет оборвался, то перестаём обрабатывать клиента
            _fail_with_error( "[SERVER]> Client broke socket connection", $client ) unless $bytes_read;
            $bytes_read == $expected_header_data_size
                or _fail_with_error( "[SERVER]> Incorrect header data size. $expected_header_data_size expected", $client );
            my ($status, $message_size) = Local::TCP::Calc->unpack_header($header_data);
            if ($status == Local::TCP::Calc::TYPE_START_WORK()) {
                my $message_data;
                $bytes_read = $client->sysread($message_data, $message_size);
                _fail_with_error( "[SERVER]> Client broke socket connection", $client ) unless $bytes_read;
                $bytes_read == $message_size or _fail_with_error( "[SERVER]> Incorrect message data size. $message_size expected", $client );
                my $task = Local::TCP::Calc->unpack_message($message_data);
                my $id = $q->add($task);
                warn "[SERVER]> Added task to queue -> $id" if $id;
                warn "[SERVER]> Queue overflow" unless $id;
                my $response_data = Local::TCP::Calc->pack_message([$id]);
                $header_data = Local::TCP::Calc->pack_header(Local::TCP::Calc::STATUS_NEW(), length $response_data);
                my $overall_data = $header_data . $response_data;
                my $overall_data_size = length $overall_data;
                $client->syswrite($overall_data, $overall_data_size) == $overall_data_size or _fail_with_error( "Incorrect sent data size. $overall_data_size expected", $client );
                close $client;
                exit;
            }
            elsif ($status == Local::TCP::Calc::TYPE_CHECK_WORK()) {
                my $message_data;
                $bytes_read = $client->sysread($message_data, $message_size);
                exit unless $bytes_read;
                $bytes_read == $message_size or die "[SERVER]> Incorrect message data size. $message_size expected";
                my $query = Local::TCP::Calc->unpack_message($message_data);
                _fail_with_error( '[SERVER]> Unknown query format. Expected only 1 parameter - id of task.', $client ) unless @$query == 1;
                my $task_id = pop @$query;
                my ($task_status, $task_result_filename) = $q->get_status($task_id);
                if ($task_status) {
                    warn "[SERVER]> requested: $task_id, response: {status => $task_status" . do { defined $task_result_filename ? ", result_filename => $task_result_filename" : ""} . "}";
                    my $message_data_size = 0;
                    $message_data = '';
                    if (defined $task_result_filename) {
                        my $fh;
                        open $fh, '<:encoding(UTF-8)', $task_result_filename or _fail_with_error( "[SERVER]> Can't open file with result", $client );
                        my $task_result = [];
                        while (<$fh>) {
                            chomp;
                            push @$task_result, $_ if length $_ > 0; # в файле может быть пустая строка в конце
                        }
                        close $fh;
                        unlink $task_result_filename;
                        $message_data = Local::TCP::Calc->pack_message($task_result);
                        eval {
                            $message_data = _gzip_data($message_data, $task_id);
                        1;} or _fail_with_error ( $@, $client );
                        $message_data_size = length $message_data;
                    }
                    $header_data = Local::TCP::Calc->pack_header($task_status, $message_data_size);
                }
                else {
                    warn "[SERVER]> No tasks with id $task_id found";
                    my $error_message = "No tasks with id $task_id found";
                    $message_data = Local::TCP::Calc->pack_message([$error_message]);
                    $header_data = Local::TCP::Calc->pack_header(Local::TCP::Calc::STATUS_ERROR(), length $message_data);
                }
                my $overall_data = $header_data . $message_data;
                my $overall_data_size = length $overall_data;
                $client->syswrite($overall_data, $overall_data_size) == $overall_data_size or _fail_with_error( "Incorrect sent data size. $overall_data_size expected", $client );
                close $client;
                exit;
            }
            else {
                _fail_with_error( "[SERVER]> Unknown task type $status", $client );
            }
        }
        else {
            _send_conn_error_response( "[SERVER]> No workers", $client );
            next;
        }
    }
    warn "[SERVER][$$]> CLOSING SERVER";
    close $server;
}

sub check_queue_workers {
    my $q = shift;
    if (defined $q->check && $in_process < $max_worker) {
        # при получении задачи из очереди меняется её статус на work, поэтому пытаемся форкнуться
        # перед извлечением задачи
        my $task_worker = fork();
        if (!defined $task_worker) {
            warn "[SERVER]> Can't fork task worker: $!";
            return;
        }

        my $task_id;
        my $tasks;
        if (!$task_worker) {
            ($task_id, $tasks) = $q->get();
            exit unless $task_id;
        }

        if ($task_worker) {
            # сохраняем воркеров в отдельной структуре, чтобы отлавливать их CHLD
            $pids_worker->{$task_worker} = 1;
            warn "[SERVER]> CREATED WORKER WITH PID $task_worker";
            ++$in_process;
            return;
        }

        warn "[SERVER]> CREATED WORKER FOR TASK $task_id";
        my $worker = Local::TCP::Calc::Server::Worker->new(
            cur_task_id => $task_id,
            calc_ref => sub {
                my $task = shift;
                my @out = `perl -e 'print "$task"' | $FindBin::Bin/../calculator/bin/calculator`;
                return $out[-1];
            },
            max_forks => $max_forks_per_task,
            queue => $q,
            result_filename => "/tmp/task_$task_id"
        );
        $worker->start($tasks);
    }
}

sub _gzip_data {
    my $data = shift;
    my $task_id = shift;
    my $tmp_gzip_file = "/tmp/task_$task_id.gz";
    open my $fh, '>:gzip', $tmp_gzip_file or die "[SERVER]> Can't create gzip file with result";
    print $fh $data;
    close $fh;
    open $fh, '<:raw', "/tmp/task_$task_id.gz" or die "[SERVER]> Can't open gzip file with result";
    my $gzipped_data = do { local $/; <$fh>; };
    close $fh;
    #unlink $tmp_gzip_file;
    return $gzipped_data;
}

sub _send_conn_error_response {
    my $error = shift;
    my $client = shift;
    warn $error;
    my $header_data = Local::TCP::Calc->pack_header(Local::TCP::Calc::TYPE_CONN_ERR(), 0);
    my $header_data_size = length $header_data;
    $client->syswrite($header_data, $header_data_size) == $header_data_size
        or do { warn "[SERVER]> Incorrect sent data size. $header_data_size expected"; };
    close $client;
}

sub _fail_with_error {
    my $error = shift;
    my $client = shift;
    close $client;
    confess $error;
}

1;
