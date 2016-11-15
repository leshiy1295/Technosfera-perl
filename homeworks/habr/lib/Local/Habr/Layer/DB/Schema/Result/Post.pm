use utf8;
package Local::Habr::Layer::DB::Schema::Result::Post;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Local::Habr::Layer::DB::Schema::Result::Post

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<post>

=cut

__PACKAGE__->table("post");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_nullable: 0

=head2 author_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 title

  data_type: 'varchar'
  size: '255'
  is_nullable: 0

=head2 rating

  data_type: 'integer'
  is_nullable: 1

=head2 read_count

  data_type: 'integer'
  is_nullable: 1

=head2 stars_count

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "author_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "title",
  { data_type => "varchar", size => "255", is_nullable => 0 },
  "rating",
  { data_type => "integer", is_nullable => 1 },
  "read_count",
  { data_type => "integer", is_nullable => 1 },
  "stars_count",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 author

Type: belongs_to

Related object: L<Local::Habr::Layer::DB::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "author",
  "Local::Habr::Layer::DB::Schema::Result::User",
  { id => "author_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 comments

Type: has_many

Related object: L<Local::Habr::Layer::DB::Schema::Result::Comment>

=cut

__PACKAGE__->has_many(
  "comments",
  "Local::Habr::Layer::DB::Schema::Result::Comment",
  { "foreign.post_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 users

Type: many_to_many

Composing rels: L</comments> -> user_id

=cut

__PACKAGE__->many_to_many("commenters", "comments", "user");


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2016-11-18 15:26:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uG53cifpEME0JnvGM1yxJg


sub to_hash {
    my ($self) = @_;
    my $result = {};
    $result->{id} = $self->id;
    $result->{title} = $self->title if defined $self->title;
    $result->{rating} = $self->rating if defined $self->rating;
    $result->{read_count} = $self->read_count if defined $self->read_count;
    $result->{stars_count} = $self->stars_count if defined $self->stars_count;
    return $result;
}

1;
