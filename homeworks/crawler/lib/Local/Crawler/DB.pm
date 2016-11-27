use utf8;
package Local::Crawler::DB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2016-11-27 20:33:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qMG5GAfXTRvERXUDBdPL4w

use File::Spec;
use FindBin;
use Local::Crawler::Configuration;

sub new {
    my ($class) = @_;
    my $database_file = File::Spec->catfile("$FindBin::Bin", Local::Crawler::Configuration->get_option('database.file'));
    my $schema = $class->connect(
        "${\do{Local::Crawler::Configuration->get_option('database.dbi')}}:$database_file",
        Local::Crawler::Configuration->get_option('database.user'),
        Local::Crawler::Configuration->get_option('database.password'),
        { RaiseError => 1, sqlite_unicode => 1 }
    );

    if (not -e $database_file) {
        $schema->deploy;
    }

    return $schema;
}

sub get {
    my ($self, $url) = @_;
    my $site = $self->resultset('Site')->find({url => $url});
    return $site ? $site->to_hash : undef;
}

sub save {
    my ($self, $site) = @_;
    $self->resultset('Site')->create($site);
}

sub update {
    my ($self, $site) = @_;
    my $record = $self->resultset('Site')->find({url => $site->{url}});
    for my $key (keys $site) {
        $record->$key($site->{$key});
    }
    $record->update;
}

sub delete {
    my ($self, $url) = @_;
    $self->resultset('Site')->find({url => $url})->delete;
}

sub get_count {
    my ($self) = @_;
    return $self->resultset('Site')->count();
}

sub get_ready_count {
    my ($self) = @_;
    return $self->resultset('Site')->search({size => {'!=', undef}})->count();
}

sub get_top {
    my ($self, $top_count) = @_;
    my @records = $self->resultset('Site')->search({
        'size' => {'!=', undef}
    }, {
        order_by => { -desc => 'size' }
    })->slice(0, $top_count - 1);
    my @sites = map { $_->to_hash; } @records;
    return @sites;
}

sub get_overall_size {
    my ($self) = @_;
    my $rs = $self->resultset('Site')->search(undef, {
        select => [ { sum => 'size' } ],
        as => [ 'overall_size' ]
    });
    my $overall_size = $rs->first->get_column('overall_size');
    $overall_size //= 0;
    return $overall_size;
}
1;
