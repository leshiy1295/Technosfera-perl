package Local::Habr::Layer::Network::Parser;

use strict;
use warnings;
use feature 'fc';

use parent 'HTML::Parser';
use utf8;
use List::MoreUtils;

our $VERSION = v1.0;

sub start {
    my ($self, $tagname, $attr) = @_;

    $attr->{class} //= '';

    if (grep /^user$/, @{$self->{extract_fields}}) {
        if (fc($tagname) eq 'a' && fc($attr->{class}) eq 'author-info__name') {
            $self->{author_name} = 1;
        }
        elsif (fc($tagname) eq 'a' && fc($attr->{class}) eq 'author-info__nickname') {
            $self->{author_nickname} = 1;
        }
        elsif (fc($tagname) eq 'div' && fc($attr->{class}) eq 'voting-wjt__counter-score js-karma_num') {
            $self->{author_karma} = 1;
        }
        elsif (fc($tagname) eq 'div' && fc($attr->{class}) eq 'statistic__value statistic__value_magenta') {
            $self->{author_rating} = 1;
        }
        elsif (fc($tagname) eq 'a' && fc($attr->{class}) eq 'post-type__value post-type__value_author') {
            $self->{should_retry_author} = 1;
        }
        elsif (fc($tagname) eq 'span' && fc($attr->{class}) eq 'user-rating__value') {
            $self->{author_rating} = 1;
        }
    }

    if (grep /^post$/, @{$self->{extract_fields}}) {
        if (fc($tagname) eq 'h1' && fc($attr->{class}) eq 'post__title') {
            $self->{inside_title_h} = 1;
        }
        elsif (fc($tagname) eq 'span' && !$attr->{class} && $self->{inside_title_h}) {
            $self->{post_title} = 1;
            delete $self->{inside_title_h};
        }
        elsif (fc($tagname) eq 'div' && fc($attr->{class}) eq 'voting-wjt voting-wjt_infopanel js-voting  ') {
            $self->{inside_post_rating} = 1;
        }
        elsif (fc($tagname) eq 'span' && $self->{inside_post_rating} && fc($attr->{class}) eq 'voting-wjt__counter-score js-score') {
            $self->{post_rating} = 1;
            delete $self->{inside_post_rating};
        }
        elsif (fc($tagname) eq 'div' && fc($attr->{class}) eq 'views-count_post') {
            $self->{post_read_count} = 1;
        }
        elsif (fc($tagname) eq 'span' && fc($attr->{class}) eq 'favorite-wjt__counter js-favs_count') {
            $self->{post_stars_count} = 1;
        }
    }

    if (grep /^commenters$/, @{$self->{extract_fields}}) {
        if (fc($tagname) eq 'span' && fc($attr->{class}) eq 'comment-item__user-info') {
            push @{$self->{commenters}}, $attr->{'data-user-login'};
        }
    }
}

sub text {
    my ($self, $text) = @_;

    if (grep /^user$/, @{$self->{extract_fields}}) {
        if ($self->{author_name}) {
            $self->{user}->{name} = $text;
            delete $self->{author_name};
        }
        elsif ($self->{author_nickname}) {
            $text =~ s/@//;
            $self->{user}->{nickname} = $text;
            delete $self->{author_nickname};
        }
        elsif ($self->{author_karma}) {
            $self->{user}->{karma} = $self->_convert_to_number($text);
            delete $self->{author_karma};
        }
        elsif ($self->{author_rating}) {
            $self->{user}->{rating} = $self->_convert_to_number($text);
            delete $self->{author_rating};
        }
        elsif ($self->{should_retry_author}) {
            $text =~ s/@//;
            $self->{user} = {
                nickname => $text,
                should_retry => 1
            };
            delete $self->{should_retry_author};
        }
    }

    if (grep /^post$/, @{$self->{extract_fields}}) {
        if ($self->{post_title}) {
            $self->{post}->{title} = $text;
            delete $self->{post_title};
        }
        elsif ($self->{post_rating}) {
            $self->{post}->{rating} = $self->_convert_to_number($text);
            delete $self->{post_rating};
        }
        elsif ($self->{post_read_count}) {
            $self->{post}->{read_count} = $self->_convert_to_number($text);
            delete $self->{post_read_count};
        }
        elsif ($self->{post_stars_count}) {
            $self->{post}->{stars_count} = $self->_convert_to_number($text);
            delete $self->{post_stars_count};
        }
    }
}

sub end {
    my ($self, $tagname) = @_;
    if (grep /^post$/, @{$self->{extract_fields}}) {
        if (fc($tagname) eq 'h1' && $self->{inside_title_h}) {
            delete $self->{inside_title_h};
        }
        elsif (fc($tagname) eq 'div' && $self->{inside_post_rating}) {
            delete $self->{inside_post_rating};
        }
    }
}

my $parser = __PACKAGE__->new;

sub parse_html {
    my ($class, $html, $extract_fields) = @_;
    my $result;
    $parser->{user} = {};
    $parser->{post} = {};
    $parser->{commenters} = [];
    $parser->{extract_fields} = $extract_fields;
    $parser->parse($html);
    delete $parser->{user} unless keys %{$parser->{user}};
    delete $parser->{post} unless keys %{$parser->{post}};
    delete $parser->{commenters} unless @{$parser->{commenters}};
    return undef unless exists $parser->{user} || exists $parser->{post} || exists $parser->{commenters};
    %$result = map { my $field = $_; ( $field => $parser->{$_} ) if List::MoreUtils::any { $field eq $_ } @$extract_fields; } @$extract_fields;
    return $result;
}

sub _convert_to_number {
    my ($self, $string) = @_;
    my $c = 1;
    $string =~ s/\+//;
    $c = -1 if $string =~ s/\x{2013}//;
    $string =~ s/,/./;
    $string =~ s/k/e3/;
    return $c * $string;
}

1;
