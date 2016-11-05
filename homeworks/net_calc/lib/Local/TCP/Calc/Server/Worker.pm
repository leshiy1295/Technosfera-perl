package Local::TCP::Calc::Server::Worker;

use strict;
use warnings;

our $VERSION = v1.0;

use Mouse;
use Carp qw/confess cluck/;

use Local::TCP::Calc::Server::Queue ();
use Fcntl ':flock';
use POSIX qw(:sys_wait_h);

has cur_task_id => (is => 'rw', isa => 'Int', required => 1);
has forks       => (is => 'rw', isa => 'HashRef', default => sub {return {}});
has calc_ref    => (is => 'ro', isa => 'CodeRef', required => 1);
has max_forks   => (is => 'ro', isa => 'Int', required => 1);
has result_filename => (is => 'rw', isa => 'Str', required => 1);
has queue => (is => 'ro', isa => 'Local::TCP::Calc::Server::Queue', required => 1);

$SIG{ALRM} = sub { die 'Timeout on lock'; };

sub write_res {
    my $self = shift;
    my $task = shift;
    my $res = shift;
    my $fh;
    eval {
        open $fh, '>>:encoding(UTF-8)', $self->result_filename or die "Can't open result file: $!";
    };
    do { warn $@; $self->continue_with_err($@); return; } if $@;
    alarm(10);
    eval {
        flock($fh, LOCK_EX) or die "[WORKER]> can't flock (lock): $!";
    };
    do { warn $@; close $fh; return; } if $@;
    alarm(0);
    print $fh "$task == $res\n";
    alarm(10);
    eval {
        flock($fh, LOCK_UN) or die "[WORKER]> can't flock (unlock): $!";
    };
    alarm(0);
    close $fh;
}

sub continue_with_err {
    my $self = shift;
    my $status = shift;
    cluck "[WORKER][$$]> One of workers returned with bad status $status";
    my $successfully_killed = kill 'KILL', keys $self->forks;
    warn "[WORKER][$$]> Expected to kill ${\do{scalar keys $self->forks}} forks. $successfully_killed killed" unless $successfully_killed == keys $self->forks;
    $self->forks({});
    my $fh;
    eval {
        open $fh, '>:encoding(UTF-8)', $self->result_filename or die "Can't create result file: $!";
    };
    do { warn "[WORKER][$$]> $@"; $self->queue->to_error($self->cur_task_id); return; } if $@;
    print $fh "One of workers returned with bad status $status";
    close $fh;
    $self->queue->to_error($self->cur_task_id, $self->result_filename);
}

sub wait_for_child_exit {
    my $self = shift;
    while (keys $self->forks) {
        while ( my $pid = waitpid(-1, WNOHANG) ) {
            last if $pid == -1;
            next unless exists $self->forks->{$pid};

            warn "[WORKER][$$]> IN WORKER REAPER WITH PID $pid";
            if ( WIFEXITED($?) ) {
                my $status = $? >> 8;
                #warn "$pid exited with status $status";
                delete $self->forks->{$pid};
                $self->continue_with_err($status) unless $status == 0;
            }
            else {
                #warn "Process $pid sleeps";
            }
        }
    }
}

sub create_result_file {
    my $self = shift;
    my $fh;
    open $fh, '>:encoding(UTF-8)', $self->result_filename;
    close $fh;
}

sub start {
    my $self = shift;
    my $tasks = shift;
    warn "[WORKER][$$]> STARTED WORKING on task";
    use DDP;
    DDP::p $tasks;
    my $new_task_id = $self->cur_task_id;
    do {
        $self->cur_task_id($new_task_id);
        warn "[WORKER][$$]> TOOK $new_task_id";
        $self->create_result_file;
        my $tasks_per_fork = int(@$tasks / $self->max_forks);
        if (@$tasks % $self->max_forks != 0) {
            $tasks_per_fork += 1;
        }
        my $index = 0;
        my $workers_count = 0;
        my $child;
        do {
            $child = fork();
            do { $self->continue_with_err("Can't fork child task process"); last; } unless defined $child;
            if ($child) {
                $self->forks->{$child} = 1;
                warn "[WORKER][$$]> CREATED WORKER FOR SUBTASK $child";
                $index += $tasks_per_fork;
                ++$workers_count;
            }
        } while ($child && $index < @$tasks && $workers_count <= $self->max_forks);
        if ($child) {
            warn "[TASK_ID:$new_task_id: WORKER][$$]> CREATED $workers_count workers (@{[keys $self->forks]}) by $tasks_per_fork tasks for fork for task with ".@$tasks." subtasks";
            # Ожидаем в главном процессе окончания работы всех созданных воркеров
            $self->wait_for_child_exit();
            $self->queue->to_done($self->cur_task_id, $self->result_filename);
            warn "[TASK_ID:$new_task_id: WORKER][$$]> ENDED $new_task_id";
            ($new_task_id, $tasks) = $self->queue->get();
            warn "[WORKER][$$]> TRYING GET NEW TASK";
        }
        else {
            for (0..$tasks_per_fork - 1) {
                if ($index + $_ < @$tasks) {
                    warn "[TASK_ID:$new_task_id: WORKER][$$]> CALCULATING ".($index + $_);
                    my $result = $self->calc_ref->($tasks->[$index + $_]);
                    warn "[TASK_ID:$new_task_id: WORKER][$$]> TRYING TO SAVE RESULT ".($index + $_);
                    $self->write_res($tasks->[$index + $_], $result);
                    warn "[TASK_ID:$new_task_id: WORKER][$$]> SUCCESS ".($index + $_);
                }
            }
            warn "[TASK_ID:$new_task_id: WORKER][$$]> EXITING WITH OK";
            exit;
        }
    } while ($new_task_id);
    warn "[WORKER][$$]> FINISHED WORKING";
    exit;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
