package Local::TCP::Calc::Server::Queue;

use strict;
use warnings;

our $VERSION = v1.0;

use Mouse;
use Local::TCP::Calc ();
use Fcntl ':flock';

has f_handle       => (is => 'rw', isa => 'FileHandle');
has queue_filename => (is => 'ro', isa => 'Str', default => '/tmp/local_queue.log');
has max_task       => (is => 'rw', isa => 'Int', default => 0);

$SIG{ALRM} = sub { die '[QUEUE]> Timeout on lock'; };

sub init {
    my $self = shift;
    # Проверяем наличие файла (он мог остаться от предыдущего запуска сервера)
    if ( !-e $self->queue_filename ) {
        $self->open('+>:encoding(UTF-8)');
        $self->close([], 0);
    }
}

sub open {
    my $self = shift;
    my $open_type = shift() // '+<:encoding(UTF-8)';

    my $fh;
    eval {
        open($fh, $open_type, $self->queue_filename) or die "[QUEUE]> Can't open file $self->queue_filename: $!";
    };
    do { warn $@ if $@; return []; } if $@;
    $self->f_handle($fh);
    alarm(10);
    eval {
        flock($fh, LOCK_EX) or die "[QUEUE]> can't flock (lock): $!";
    };
    do { warn $@ if $@; return []; } if $@;
    alarm(0);
    my $struct = [];
    my $last_id = <$fh>;
    chomp $last_id if $last_id;
    while ( my $line = <$fh> ) {
        chomp $line;
        $line =~ /^(?<task_id>\d+) (?<task_status>\d) (?<task_tasks>\[.+\])(?: \"(?<task_result_filename>.+)\")?$/;
        my $task = { %+ };
        my $task_string = do { $task->{task_tasks} =~ /^\[(.*)\]$/; $1; };
        $task->{task_tasks} = [split ",", $task_string];
        push $struct, $task;
    }
    return ($last_id, $struct);
}

sub close {
    my $self = shift;
    my $struct = shift;
    my $last_id = shift;

    my $fh = $self->f_handle;
    seek($fh, 0, 0);
    if ($last_id) {
        print $fh "$last_id\n";
    }
    else {
        <$fh>; # Пропускаем первую строку
    }
    if ($struct) {
        for (@$struct) {
           print $fh qq/$_->{task_id} $_->{task_status}/;
           print $fh " [", join( ',', @{$_->{task_tasks}} ), "]";
           print $fh qq/ "$_->{task_result_filename}"/ if defined $_->{task_result_filename};
           print $fh "\n";
        }
        truncate($fh, tell($fh));
    }

    alarm(10);
    eval {
        flock($fh, LOCK_UN) or die "[QUEUE]> can't flock (unlock): $!";
    };
    warn $@ if $@;
    alarm(0);
    close $fh;
}

sub to_done {
    my $self = shift;
    my $task_id = shift;
    my $filename = shift;
    $self->_update_status($task_id, Local::TCP::Calc::STATUS_DONE(), $filename);
}

sub to_error {
    my $self = shift;
    my $task_id = shift;
    my $filename = shift;
    $self->_update_status($task_id, Local::TCP::Calc::STATUS_ERROR(), $filename);
}

sub get_status {
    my $self = shift;
    my $id = shift;
    my ($last_id, $tasks) = $self->open;
    my ($task) = grep { $_->{task_id} == $id; } @$tasks;
    $self->close;
    do { warn "[QUEUE]> No task with id $id was found"; return undef; } unless $task;
    if ($task->{task_status} == Local::TCP::Calc::STATUS_DONE() || $task->{task_status} == Local::TCP::Calc::STATUS_ERROR()) {
        $self->delete($id, $task->{task_status});
    }
    return $task->{task_status} == Local::TCP::Calc::STATUS_DONE() || Local::TCP::Calc::STATUS_ERROR() ?
                                      ($task->{task_status}, $task->{task_result_filename}) :
                                      $task->{task_status};
}

sub delete {
    my $self = shift;
    my $id = shift;
    my $status = shift;
    my ($last_id, $tasks) = $self->open;
    my @updated_tasks = map { $_->{task_id} == $id && $_->{task_status} == $status ? () : $_; } @$tasks;
    do { $self->close; warn "[QUEUE]> No task with id $id and status $status was found"; return; } if @updated_tasks == @$tasks;
    $self->close(\@updated_tasks);
}

sub get {
    my $self = shift;
    my ($last_id, $tasks) = $self->open;
    do { $self->close; return undef; } unless @$tasks;
    my $first = undef;
    @$tasks = map { !defined $first && $_->{task_status} == Local::TCP::Calc::STATUS_NEW() ?
                        do { $first //= $_; $_->{task_status} = Local::TCP::Calc::STATUS_WORK(); $_; } :
                        $_
                  } @$tasks;
    do { $self->close; return undef } unless defined $first;
    $self->close($tasks);
    return ($first->{task_id}, $first->{task_tasks});
}

sub check {
    my $self = shift;
    my ($last_id, $tasks) = $self->open;
    $self->close;
    return undef unless @$tasks;
    my ($first) = grep { $_->{task_status} == Local::TCP::Calc::STATUS_NEW(); } @$tasks;
    return $first;
}

sub add {
    my $self = shift;
    my $new_work = shift;
    my ($last_id, $tasks) = $self->open;
    return 0 if @$tasks >= $self->max_task;
    my $task_id = ++$last_id;
    push @$tasks, {
        task_id => $task_id,
        task_status => Local::TCP::Calc::STATUS_NEW(),
        task_tasks => $new_work
    };
    $self->close($tasks, $last_id);
    return $task_id;
}

sub _update_status {
    my $self = shift;
    my $task_id = shift;
    my $status = shift;
    my $filename = shift;
    my ($last_id, $tasks) = $self->open;
    my $found = 0;
    @$tasks = map { $_->{task_id} == $task_id ?
                      do { $found = 1; $_->{task_result_filename} = $filename if defined $filename; $_->{task_status} = $status; $_;} :
                      $_;
                  } @$tasks;
    do { $self->close; warn "[QUEUE]> No task with id $task_id was found"; return; } unless $found;
    $self->close($tasks);
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
