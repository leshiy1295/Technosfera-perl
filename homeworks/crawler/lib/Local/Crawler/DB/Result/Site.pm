use utf8;
package Local::Crawler::DB::Result::Site;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Local::Crawler::DB::Result::Site

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<site>

=cut

__PACKAGE__->table("site");

=head1 ACCESSORS

=head2 url

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 size

  data_type: 'integer'
  is_nullable: 1

=head2 body

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "url",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "size",
  { data_type => "integer", is_nullable => 1 },
  "body",
  { data_type => "text", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("url");


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2016-11-27 20:33:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PtZEYUlZt36hErgFznekdA

sub to_hash {
    my ($self) = @_;
    my $hash = {};
    $hash->{url} = $self->url if $self->url;
    $hash->{size} = $self->size if $self->size;
    $hash->{body} = $self->body if $self->body;
    return $hash;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
