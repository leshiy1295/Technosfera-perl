use utf8;
package Local::Habr::Layer::DB::Schema::Result::Comment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Local::Habr::Layer::DB::Schema::Result::Comment

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<comments>

=cut

__PACKAGE__->table("comments");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 post_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "post_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</user_id>

=item * L</post_id>

=back

=cut

__PACKAGE__->set_primary_key("user_id", "post_id");

=head1 RELATIONS

=head2 post

Type: belongs_to

Related object: L<Local::Habr::Layer::DB::Schema::Result::Post>

=cut

__PACKAGE__->belongs_to(
  "post",
  "Local::Habr::Layer::DB::Schema::Result::Post",
  { id => "post_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 user

Type: belongs_to

Related object: L<Local::Habr::Layer::DB::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Local::Habr::Layer::DB::Schema::Result::User",
  { id => "user_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2016-11-18 15:26:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8yJKn8aX5Bt1v+XKWfLCfw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
