package Local::Habr::Layer::DB::Handler;

use strict;
use warnings;
use feature 'fc';

use Local::Habr::Layer::DB::Schema ();
use Local::Habr::Configuration ();
use FindBin ();
use File::Spec;

our $VERSION = v1.0;

my $schema;

sub init {
    my $database_file = File::Spec->catfile("$FindBin::Bin", Local::Habr::Configuration->get_option('database.file'));
    $schema = Local::Habr::Layer::DB::Schema->connect(
        "${\do{Local::Habr::Configuration->get_option('database.dbi')}}:$database_file",
        Local::Habr::Configuration->get_option('database.user'),
        Local::Habr::Configuration->get_option('database.password'),
        { RaiseError => 1, sqlite_unicode => 1 }
    );

    use DDP;
    p $schema;

    if (not -e $database_file) {
        $schema->deploy;
    }
}

sub get_result {
    my ($class, $command, $keys) = @_;
    my $result;

    if (fc($command) eq 'user') {
        if ($keys->{name}) {
            my $user = $schema->resultset('User')->find({nickname => $keys->{name}});
            if ($user) {
                $result->{user} = $user->to_hash;
            }
        }
        elsif ($keys->{post}) {
            my $post = $schema->resultset('Post')->find($keys->{post});
            return unless $post && $post->author;
            my $user = $post->author;
            if (!$user) {
                warn 'Foreign key error!!!';
                return;
            }

            $result->{user} = $user->to_hash;
        }
        else {
            warn q(Incorrect keys for 'user' command);
            return;
        }
    }
    elsif (fc($command) eq 'commenters') {
        if ($keys->{post}) {
            my $post = $schema->resultset('Post')->find($keys->{post});
            return unless $post;
            $result->{commenters} = [];
            my @users = $post->commenters->all();
            for my $user (@users) {
                push @{$result->{commenters}}, $user->to_hash;
            }
        }
        else {
            warn q(Incorrect keys for 'commenters' command);
            return;
        }
    }
    elsif (fc($command) eq 'post') {
        if ($keys->{id}) {
            my $post = $schema->resultset('Post')->find($keys->{id});
            $result->{post} = $post->to_hash if $post;
        }
        else {
            warn q(Incorrect keys for 'post' command);
            return;
        }
    }
    elsif (fc($command) eq 'self_commentors') {
        my @users = $schema->resultset('User')->search({
            'me.id' => \'=post.author_id'
        }, {
            join => { 'comments' => 'post' },
            group_by => ['me.id']
        });
        $result->{self_commentors} = [map { $_->to_hash; } @users];
    }
    elsif (fc($command) eq 'desert_posts') {
        if ($keys->{n}) {
            my $count = 0+$keys->{n};
            # Не используем having из документации, поскольку есть баг https://rt.cpan.org/Public/Bug/Display.html?id=17818
            my @posts = $schema->resultset('Post')->search(undef, {
                join => 'comments',
                group_by => ['comments.post_id'],
                having => \[ "count(comments.user_id) < $count" ]
            });
            $result->{desert_posts} = [map { $_->to_hash; } @posts];
        }
        else {
            warn q(Incorrect keys for 'desert_posts' command);
            return;
        }
    }

    return $result;
}

sub save_result {
    my ($class, $result, $command, $keys) = @_;
    if (fc($command) eq 'user') {
        if ($keys->{name}) {
            $class->_create_or_update_user($result->{user});
            return;
        }
        elsif ($keys->{post}) {
            my $post = { %{$result->{post}} };
            $class->_create_or_update_post_from_author($post, $result->{user});
            return;
        }
        else {
            warn q(Incorrect keys for 'user' command);
            return;
        }
    }
    elsif (fc($command) eq 'commenters') {
        if ($keys->{post}) {
            my $post = { %{$result->{post}} };
            $class->_create_or_update_post_from_author($post, $result->{user});
            $class->_update_commenters_for_post($result->{commenters}, $post);
            return;
        }
        else {
            warn q(Incorrect keys for 'commenters' command);
            return;
        }
    }
    elsif (fc($command) eq 'post') {
        if ($keys->{id}) {
            my $post = { %{$result->{post}} };
            $class->_create_or_update_post_from_author($post, $result->{user});
            $class->_update_commenters_for_post($result->{commenters}, $post);
            return;
        }
        else {
            warn q(Incorrect keys for 'post' command);
            return;
        }
    }
    else {
        warn 'Unknown command';
        return;
    }
}

sub _create_or_update_post_from_author {
    my ($class, $post, $user) = @_;
    my $user_id = $class->_create_or_update_user($user);
    $post->{author_id} = $user_id;
    $class->_create_or_update_post($post);
}

sub _update_commenters_for_post {
    my ($class, $commenters, $post) = @_;
    for my $commenter (@$commenters) {
        my $commenter_record = $schema->resultset('User')->find({nickname => $commenter->{nickname}});
        if (!$commenter_record) {
            $schema->resultset('Post')->find($post->{id})->add_to_commenters($commenter);
        }
        else {
            $class->_create_or_update_user($commenter);
            $class->_add_to_comments($post->{id}, $commenter_record->id);
        }
    }
}

sub _create_or_update_user {
    my ($class, $user) = @_;
    my $id;
    my $record = $schema->resultset('User')->find({nickname => $user->{nickname}});
    if (!$record) {
        $schema->resultset('User')->create($user);
        $id = $schema->resultset('User')->find($user)->id;
    }
    else {
        for my $key (keys $user) {
            $record->$key($user->{$key});
        }
        $record->update;
        $id = $record->id;
    }
    return $id;
}

sub _create_or_update_post {
    my ($class, $post) = @_;
    my $record = $schema->resultset('Post')->find($post->{id});
    if (!$record) {
        $schema->resultset('Post')->create($post);
    }
    else {
        for my $key (keys $post) {
            $record->$key($post->{$key});
        }
        $record->update;
    }
    return $post->{id};
}

sub _add_to_comments {
    my ($class, $post_id, $user_id) = @_;
    my $comment = {
        post_id => $post_id,
        user_id => $user_id
    };
    my $record = $schema->resultset('Comment')->find($comment);
    if (!$record) {
        $schema->resultset('Comment')->create($comment);
    }
}

1;
