package Local::Habr;

use strict;
use warnings;

use DDP;
use feature 'fc';
use List::MoreUtils;

use Local::Habr::Layer::Network::Fetcher ();
use Local::Habr::Layer::DB::Handler ();
use Local::Habr::Layer::Cache::Storage ();

=encoding utf8

=head1 NAME

Local::Habr - habrahabr.ru crawler

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub execute_command {
    my ($class, $command, $keys) = @_;
    warn "Request: $command";
    p $keys;
    my $result;
    if (!$keys->{refresh} && fc($command) eq 'user' && $keys->{name} && !$keys->{post}) {
        warn 'Trying get result from cache';
        $result = Local::Habr::Layer::Cache::Storage->get_result($command, $keys) unless $keys->{refresh};
    }
    if (!$result) {
        if ( !$keys->{refresh} || $keys->{refresh} && List::MoreUtils::any { fc($command) eq $_; } qw(self_commentors desert_posts) )
        {
            warn 'Trying get result from DB';
            $result = Local::Habr::Layer::DB::Handler->get_result($command, $keys);
        }
        if (!$result && List::MoreUtils::none { fc($command) eq $_; } qw(self_commentors desert_posts)) {
            warn 'Trying get result from network';
            $result = Local::Habr::Layer::Network::Fetcher->get_result($command, $keys);
            return undef unless $result;
            warn 'Saving result to DB';
            Local::Habr::Layer::DB::Handler->save_result($result, $command, $keys);
        }
        if (fc($command) eq 'user') {
            warn 'Saving result to cache';
            Local::Habr::Layer::Cache::Storage->save_result($result, $command, $keys);
        }
    }
    p $result;
    return undef unless $result;
    if (fc($command) eq 'user') {
        return $result->{user};
    }
    elsif (fc($command) eq 'commenters') {
        return $result->{commenters};
    }
    elsif (fc($command) eq 'post') {
        return $result->{post};
    }
    elsif (fc($command) eq 'self_commentors') {
        return $result->{self_commentors};
    }
    elsif (fc($command) eq 'desert_posts') {
        return $result->{desert_posts};
    }
    else {
        die 'Unknown command';
    }
    return $result;
}

sub init {
    my ($class) = @_;
    Local::Habr::Layer::DB::Handler->init;
    Local::Habr::Layer::Cache::Storage->init;
}

1;
