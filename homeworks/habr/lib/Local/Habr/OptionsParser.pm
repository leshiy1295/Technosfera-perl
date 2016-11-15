package Local::Habr::OptionsParser;

use strict;
use warnings;

our $VERSION = v1.0;

use Getopt::Long ();
use List::MoreUtils;

sub parse_options {
    my ($class, $args) = @_;
    die 'At least one argument expected - command', "\n" unless @$args;
    my $command = shift @$args;
    die 'Unknown command', "\n" unless List::MoreUtils::any { $command eq $_; } qw(user commenters post self_commentors desert_posts);
    my $keys = {};
    my $format = 'json';
    my $refresh = 0;

    Getopt::Long::GetOptionsFromArray(
        $args,
        'format=s' => sub {
            my (undef, $opt_value) = @_;
            die 'Unknown format' unless List::MoreUtils::any { $opt_value eq $_ } qw(json jsonl);
            $format = $opt_value;
        },
        'refresh' => \$refresh,
        'name=s' => \$keys->{name},
        'post=i' => \$keys->{post},
        'id=i' => \$keys->{id},
        'n=i' => \$keys->{n}
    ) or die 'Error in command arguments', "\n";

    my $active_options_count = 0+grep { defined $keys->{$_} } keys $keys;
    # Check correct keys to commands mapping
    if ($command eq 'user') {
        die q(Incorrect keys for 'user' command. Possible keys: --name XXX or --post XXX) if $active_options_count != 1 ||
                                                                                              !defined $keys->{name} && !defined $keys->{post};
    }
    elsif ($command eq 'commenters') {
        die q(Incorrect keys for 'commenters' command. Possible keys: --post XXX) if !$active_options_count || !defined $keys->{post};
    }
    elsif ($command eq 'post') {
        die q(Incorrect keys for 'post' command. Possible keys: --id XXX) if $active_options_count != 1 || !defined $keys->{id};
    }
    elsif ($command eq 'self_commentors') {
        die q(Incorrect keys for 'self_commentors' command. No keys expected) if $active_options_count;
    }
    elsif ($command eq 'desert_posts') {
        die q(Incorrect keys for 'desert_posts' command. Possible keys: --n XXX) if $active_options_count != 1 || !defined $keys->{n};
    }

    $keys->{refresh} = $refresh if $refresh;
    %$keys = map { defined $keys->{$_} ? ( $_ => $keys->{$_} ) : (); } keys %$keys;

    return ($command, $keys, $format);
}

1;
