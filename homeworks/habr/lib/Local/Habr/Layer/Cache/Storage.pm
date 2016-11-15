package Local::Habr::Layer::Cache::Storage;

use strict;
use warnings;
use Cache::Memcached::Fast ();
use feature 'fc';
use Local::Habr::Configuration ();

our $VERSION = v1.0;

my $memd;

sub init {
    use DDP;
    $memd = Cache::Memcached::Fast->new({
        servers => [{address => Local::Habr::Configuration->get_option('memcached.address')}],
        namespace => Local::Habr::Configuration->get_option('memcached.namespace')
    });
    p $memd;
}

sub get_result {
    my ($class, $command, $keys) = @_;
    return undef unless fc($command) eq 'user' && $keys->{name} && !$keys->{post};
    my $user = $memd->get("user--$keys->{name}");
    return undef unless $user;
    my $result = {
        user => $user
    };
    return $result;
}

sub save_result {
    my ($class, $result, $command, $keys) = @_;
    return unless fc($command) eq 'user';
    $memd->set("user--$result->{user}->{nickname}", $result->{user}, 60);
}

1;
