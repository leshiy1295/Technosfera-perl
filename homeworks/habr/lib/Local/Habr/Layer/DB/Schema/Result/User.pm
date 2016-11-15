use utf8;
package Local::Habr::Layer::DB::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Local::Habr::Layer::DB::Schema::Result::User

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  size: '255'
  is_nullable: 1

=head2 nickname

  data_type: 'varchar'
  size: '255'
  is_nullable: 0

=head2 karma

  data_type: 'float'
  is_nullable: 1

=head2 rating

  data_type: 'float'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", size => "255", is_nullable => 1 },
  "nickname",
  { data_type => "varchar", size => "255", is_nullable => 0 },
  "karma",
  { data_type => "float", is_nullable => 1 },
  "rating",
  { data_type => "float", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
    unique_nickname => [ 'nickname' ]
);

=head1 RELATIONS

=head2 comments

Type: has_many

Related object: L<Local::Habr::Layer::DB::Schema::Result::Comment>

=cut

__PACKAGE__->has_many(
  "comments",
  "Local::Habr::Layer::DB::Schema::Result::Comment",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 posts_2s

Type: has_many

Related object: L<Local::Habr::Layer::DB::Schema::Result::Post>

=cut

__PACKAGE__->has_many(
  "posts",
  "Local::Habr::Layer::DB::Schema::Result::Post",
  { "foreign.author_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 posts

Type: many_to_many

Composing rels: L</comments> -> post

=cut

__PACKAGE__->many_to_many("commented_posts", "comments", "post");


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2016-11-18 15:26:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IYyHC7SwsvKJ3NaPC7MVUg


sub to_hash {
    my ($self) = @_;
    my $result = {};
    $result->{name} = $self->name if defined $self->name;
    $result->{nickname} = $self->nickname if defined $self->nickname;
    $result->{rating} = $self->rating if defined $self->rating;
    $result->{karma} = $self->karma if defined $self->karma;
    return $result;
}
1;
