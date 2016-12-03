package Local::Stats;

use 5.018000;
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Local::Stats ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Local::Stats::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Local::Stats', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Local::Stats - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Local::Stats;
  blah blah blah

=head1 DESCRIPTION

Perl implementation

sub new {
   my ($class, $coderef) = @_;
   my $self = bless {}, $class;
   $self->{get_settings} = $coderef;
   $self->{stats} = {};
   return $self;
}

sub add {
    my ($self, $name, $value) = @_;
    if (!exists $self->{stats}->{$name}) {
        my @stats = $self->{get_settings}->($name);
        $self->{stats}->{$name} = {map { ($_ => undef) } @stats};
    }
    if (exists $self->{stats}->{$name}->{avg}) {
        # Для пересчёта необходимо хранить количество измерений. Сбрасываем показатель, если avg ещё не менялся (или был сброшен)
        $self->{_stats}->{$name}->{cnt} = defined $self->{stats}->{$name}->{avg} ? $self->{_stats}->{$name}->{cnt} + 1 : 1;
        $self->{stats}->{$name}->{avg} = defined $self->{stats}->{$name}->{avg} ?
            ( $self->{stats}->{$name}->{avg} * ($self->{_stats}->{$name}->{cnt} - 1) + $value ) / $self->{_stats}->{$name}->{cnt} :
            $value;
    }
    if (exists $self->{stats}->{$name}->{cnt}) {
        ++$self->{stats}->{$name}->{cnt};
    }
    if (exists $self->{stats}->{$name}->{max}) {
        $self->{stats}->{$name}->{max} = $value if !defined $self->{stats}->{$name}->{max} || $value > $self->{stats}->{$name}->{max};
    }
    if (exists $self->{stats}->{$name}->{min}) {
        $self->{stats}->{$name}->{min} = $value if !defined $self->{stats}->{$name}->{min} || $value < $self->{stats}->{$name}->{min};
    }
    if (exists $self->{stats}->{$name}->{sum}) {
        $self->{stats}->{$name}->{sum} += $value;
    }
}

sub stat {
    my ($self) = @_;
    my $stats;
    for my $metric (keys %{$self->{stats}}) {
        my $stat = $self->{stats}->{$metric};
        my $key_count = 0;
        my $buf_metric_stat = {};
        for my $metric_stat (keys %$stat) {
            ++$key_count;
            $buf_metric_stat->{$metric_stat} = $stat->{$metric_stat};
            # Если просто присвоить undef, то останется числовой. Ожидается, что будет NULL тип.
            delete $self->{stats}->{$metric}->{$metric_stat};
            $self->{stats}->{$metric}->{$metric_stat} = undef;
        }
        $stats->{$metric} = $buf_metric_stat if $key_count > 0;
    }
    return $stats;
}

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Alexey Khalaydzhi, E<lt>leshiy1295@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Alexey Khalaydzhi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
