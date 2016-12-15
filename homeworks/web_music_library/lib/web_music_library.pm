package web_music_library;
use Dancer2;
use utf8;
use Dancer2::Plugin::Database;
use HTML::Entities;
use Digest::MD5 'md5_hex';
use Encode;

our $VERSION = '0.1';

hook before => sub {
    if (request->dispatch_path =~ qr{^/(?:css|javascripts|images|uploads)/.*\.(?:css|html|js|jpg|ico|png)$}) {
        return;
    }
    if (!session('login') && request->dispatch_path !~ qr{^/(?:index|signin|signup)?$}) {
        forward '/signin', {
            requested_path => request->dispatch_path
        }
    }
    if (session('login') && request->dispatch_path =~ qr{^/(?:index|signin|signup)?$}) {
        redirect '/profile';
    }
};

hook before_template_render => sub {
    my $tokens = shift;
    $tokens->{self_url} = request->dispatch_path;
};

sub parse_table {
    my ($table) = @_;
    my @rows = split "\n", $table;
    @rows = map { $_ =~ s/\s*$//; $_ =~ s/^\s*//; $_; } @rows;
    my $data = [];
    my $err;
    for (my $i = 0; $i < @rows; ++$i) {
        next if $rows[$i] =~ /^.-/ || $rows[$i] =~ /^\s*$/;
        $rows[$i] =~ s/^\|//;
        $rows[$i] =~ s/\|$//;
        my @cols = split '\|', $rows[$i];
        return undef, "Неверный формат строки ${\do{$i + 1}}" unless @cols == 5;
        my ($group_name, $year, $album, $track, $format) = @cols;
        my $track_data = {
            group_name => $group_name,
            year => $year,
            album => $album,
            track => $track,
            format => $format
        };
        %$track_data = map {
            if (defined $track_data->{$_}) {
                $track_data->{$_} =~ s/^\s*//;
                $track_data->{$_} =~ s/\s*$//;
            }
            $track_data->{$_} ? ($_ => $track_data->{$_}) : return (undef, "Неверный формат строки ${\do{$i + 1}}");
        } keys %$track_data;
        return (undef, "Некорректный год в ${\do{$i + 1}} строке") if $track_data->{year} =~ /\D/;
        $track_data->{year} = 0+$track_data->{year};
        push @$data, $track_data;
    }
    return $data, $err;
}

get '/import_from_table' => sub {
    template 'import_from_table', {
        csrf_token => generate_csrf_token(session('secret'))
    };
};

post '/import_from_table' => sub {
    my $csrf_token = param('csrf_token');
    redirect '/profile' unless session('secret') && check_csrf_token($csrf_token, session('secret'));
    my $table = param('table');
    my @err;
    if (!$table) {
        push @err, 'Не введена табличка';
    }
    my ($parsed_tracks, $err_msg) = parse_table($table);
    if ($err_msg) {
        push @err, $err_msg;
    }
    if (@err) {
        $table = encode_entities($table, '<&"\'>');
        $table =~ s/ /&nbsp;/g;
        return template 'import_from_table', {
            csrf_token => generate_csrf_token(session('secret')),
            table => $table,
            err => \@err
        };
    }
    map {
        my $album_id;
        unless ($album_id = database->quick_lookup('album', {name => $_->{album}, year => $_->{year}, group_name => $_->{group_name}}, 'id')) {
            unless (database->quick_insert('album', {name => $_->{album}, year => $_->{year}, group_name => $_->{group_name}})) {
                die 'Ошибка БД';
            }
            $album_id = database->quick_lookup('album', {name => $_->{album}, year => $_->{year}, group_name => $_->{group_name}}, 'id');
        }
        unless (database->quick_select('users_to_albums', {user_id => session('user_id'), album_id => $album_id})) {
            unless (database->quick_insert('users_to_albums', {user_id => session('user_id'), album_id => $album_id})) {
                die 'Ошибка БД';
            }
        }
        unless (database->quick_select('track', {name => $_->{track}, format => $_->{format}, album_id => $album_id})) {
            unless (database->quick_insert('track', {name => $_->{track}, format => $_->{format}, album_id => $album_id})) {
                die 'Ошибка БД';
            }
        }
    } @$parsed_tracks;
    redirect '/profile';
};

post '/albums/:album_id/tracks/:track_id/edit' => sub {
    my $csrf_token = param('csrf_token');
    redirect '/profile' unless session('secret') && check_csrf_token($csrf_token, session('secret'));
    my $album_id = param('album_id');
    my $track_id = unpack 'Q', pack 'H*', param('track_id'); 
    my $back_to_album_link = "/albums/$album_id";
    $album_id = unpack 'Q', pack 'H*', $album_id;
    unless (database->quick_select('users_to_albums', {user_id => session('user_id'), album_id => $album_id})) {
        redirect '/profile';
    }
    my $sth = database->prepare('select name, format, image_src, image_file from track where id = ?;');
    unless ($sth->execute($track_id)) {
        die 'Ошибка БД';
    }
    my $track_info = $sth->fetchrow_hashref();
    my $name = param('name');
    my $format = param('format');
    my $image_src = param('image_src');
    my $delete_image_file = param('delete_image_file');
    my $image_file = $delete_image_file ? undef : request->upload('image_file');
    my @err;
    if ($image_file) {
        my $image_filename = $image_file->basename;
        my $public_dir = path(config->{appdir}, 'public');
        my $dir = path($public_dir, 'uploads');
        mkdir $dir unless -d $dir;
        my $filename_hash = '';
        my $try_count = 10;
        my $path = path($dir, $filename_hash);
        while (!$filename_hash or -f $path) {
            unless (--$try_count) {
                $filename_hash = undef;
                last;
            }
            $filename_hash = md5_hex("${\do{rand()}}".$filename_hash);
            $path = path($dir, $filename_hash);
        }
        if (!$filename_hash) {
            push @err, 'Не удалось сохранить файл с таким именем';
        }
        else {
            $image_file->link_to($path);
            $image_file = path(path('', 'uploads'), $filename_hash);
        }
    }
    elsif (!$delete_image_file) {
        $image_file = $track_info->{image_file};
    }
    if (!$name) {
        push @err, 'Не введено название трека';
    }
    if (!$format) {
        push @err, 'Не введён формат';
    }
    if (@err) {
        $back_to_album_link = encode_entities($back_to_album_link, '<&"\'>');
        $name = encode_entities($name, '<&"\'>');
        $format = encode_entities($format, '<&"\'>');
        $image_src = encode_entities($image_src, '<&"\'>') if $image_src;
        my $track_info = {
            name => $name,
            format => $format,
            $image_src ? (image_src => $image_src) : ()
        };
        return template 'edit_track', {
            csrf_token => generate_csrf_token(session('secret')),
            back_to_album_link => $back_to_album_link,
            track_info => $track_info,
            err => \@err,

        };
    }
    unless (database->quick_update('track', {id => $track_id}, {name => $name, format => $format, image_src => $image_src, image_file => $image_file})) {
        die 'Ошибка БД';
    }
    redirect $back_to_album_link;
};

get '/albums/:album_id/tracks/:track_id/edit' => sub {
    my $album_id = param('album_id');
    my $track_id = unpack 'Q', pack 'H*', param('track_id');
    my $back_to_album_link = "/albums/$album_id";
    $album_id = unpack 'Q', pack 'H*', $album_id;
    unless (database->quick_select('users_to_albums', {user_id => session('user_id'), album_id => $album_id})) {
        redirect '/profile';
    }
    my $sth = database->prepare('select name, format, image_src from track where id = ?;');
    unless ($sth->execute($track_id)) {
        die 'Ошибка БД';
    }
    my $track_info = $sth->fetchrow_hashref();
    %$track_info = map { ($_ => encode_entities($track_info->{$_}, '<&"\'>')) } keys %$track_info;
    $back_to_album_link = encode_entities($back_to_album_link, '<&"\'>');
    template 'edit_track', {
        csrf_token => generate_csrf_token(session('secret')),
        back_to_album_link => $back_to_album_link,
        $track_info ? (track_info => $track_info) : ()
    };
};

post '/albums/:album_id/edit' => sub {
    my $csrf_token = param('csrf_token');
    redirect '/profile' unless session('secret') && check_csrf_token($csrf_token, session('secret'));
    my $album_id = param('album_id');
    my $back_to_album_link = "/albums/$album_id";
    $album_id = unpack 'Q', pack 'H*', $album_id;
    unless (database->quick_select('users_to_albums', {user_id => session('user_id'), album_id => $album_id})) {
        redirect '/profile';
    }
    my $name = param('name');
    my $year = param('year');
    my $group_name = param('group_name');
    my @err;
    if (!$name) {
        push @err, 'Не введено название альбома';
    }
    if (!$year) {
        push @err, 'Не введён год';
    }
    if ($year =~ /\D/) {
        push @err, 'Введён некорректный год';
    }
    if (!$group_name) {
        push @err, 'Не введено название группы';
    }
    if (@err) {
        $name = encode_entities($name, '<&"\'>');
        $year = encode_entities($year, '<&"\'>');
        $group_name = encode_entities($group_name, '<&"\'>');
        $back_to_album_link = encode_entities($back_to_album_link, '<&"\'>');
        my $album_info = {
            name => $name,
            year => $year,
            group_name => $group_name
        };
        return template 'edit_album', {
            csrf_token => generate_csrf_token(session('secret')),
            back_to_album_link => $back_to_album_link,
            album_info => $album_info,
            err => \@err
        };
    }
    unless (database->quick_update('album', {id => $album_id}, {name => $name, year => 0+$year, group_name => $group_name})) {
        die 'Ошибка БД';
    }
    redirect $back_to_album_link;
};

get '/albums/:album_id/edit' => sub {
    my $album_id = param('album_id');
    my $back_to_album_link = "/albums/$album_id";
    $album_id = unpack 'Q', pack 'H*', $album_id;
    unless (database->quick_select('users_to_albums', {user_id => session('user_id'), album_id => $album_id})) {
        redirect '/profile';
    }
    my $sth = database->prepare('select name, year, group_name from album where id = ?;');
    unless ($sth->execute($album_id)) {
        die 'Ошибка БД';
    }
    my $album_info = $sth->fetchrow_hashref();
    %$album_info = map { ($_ => encode_entities($album_info->{$_}, '<&"\'>')) } keys %$album_info;
    $back_to_album_link = encode_entities($back_to_album_link, '<&"\'>');
    template 'edit_album', {
        csrf_token => generate_csrf_token(session('secret')),
        back_to_album_link => $back_to_album_link,
        $album_info ? (album_info => $album_info) : ()
    };
};

post '/albums/:album_id/tracks/delete' => sub {
    my $csrf_token = param('csrf_token');
    redirect '/profile' unless session('secret') && check_csrf_token($csrf_token, session('secret'));
    my $album_id = param('album_id');
    my $back_to_album_link = "/albums/$album_id";
    $album_id = unpack 'Q', pack 'H*', $album_id;
    unless (database->quick_select('users_to_albums', {user_id => session('user_id'), album_id => $album_id})) {
        redirect '/profile';
    }
    my $track_id = param('track_id');
    my @err;
    if (!$track_id) {
        push @err, 'Отсутствует id удаляемого трека';
    }
    if (@err) {
        redirect $back_to_album_link;
    }
    unless (database->quick_delete('track', {id => unpack 'Q', pack 'H*', $track_id })) {
        die "Ошибка БД";
    }
    redirect $back_to_album_link;
};

get '/albums/:album_id/tracks/add' => sub {
    my $album_id = param('album_id');
    my $back_to_album_link = "/albums/$album_id";
    $album_id = unpack 'Q', pack 'H*', $album_id;
    unless (database->quick_select('users_to_albums', {user_id => session('user_id'), album_id => $album_id})) {
        redirect '/profile';
    }
    $back_to_album_link = encode_entities($back_to_album_link, '<&"\'>');
    template 'add_track', { 
        back_to_album_link => $back_to_album_link,
        csrf_token => generate_csrf_token(session('secret'))
    };
};

post '/albums/:album_id/tracks/add' => sub {
    my $csrf_token = param('csrf_token');
    redirect '/profile' unless session('secret') && check_csrf_token($csrf_token, session('secret'));
    my $album_id = param('album_id');
    my $back_to_album_link = "/albums/$album_id";
    $album_id = unpack 'Q', pack 'H*', $album_id;
    unless (database->quick_select('users_to_albums', {user_id => session('user_id'), album_id => $album_id})) {
        redirect '/profile';
    }
    my $name = param('name');
    my $format = param('format');
    my $image_src = param('image_src');
    my $image_file = request->upload('image_file');
    my @err;
    if ($image_file) {
        my $image_filename = $image_file->basename;
        my $public_dir = path(config->{appdir}, 'public');
        my $dir = path($public_dir, 'uploads');
        mkdir $dir unless -d $dir;
        my $filename_hash = '';
        my $try_count = 10;
        my $path = path($dir, $filename_hash);
        while (!$filename_hash or -f $path) {
            unless (--$try_count) {
                $filename_hash = undef;
                last;
            }
            $filename_hash = md5_hex("${\do{rand()}}".$filename_hash);
            $path = path($dir, $filename_hash);
        }
        if (!$filename_hash) {
            push @err, 'Не удалось сохранить файл с таким именем';
        }
        else {
            $image_file->link_to($path);
            $image_file = path(path('', 'uploads'), $filename_hash);
        }
    }
    if (!$name) {
        push @err, 'Не введено название трека';
    }
    if (!$format) {
        push @err, 'Не введён формат трека';
    }
    if (@err) {
        $name = encode_entities($name, '<&"\'>');
        $format = encode_entities($format, '<&"\'>');
        $image_src = encode_entities($image_src, '<&"\'>');
        return template 'add_track', {
            back_to_album_link => $back_to_album_link,
            csrf_token => generate_csrf_token(session('secret')),
            name => $name,
            format => $format,
            image_src => $image_src,
            err => \@err
        };
    }
    unless (database->quick_insert('track', {name => $name, format => $format, album_id => $album_id, image_src => $image_src, image_file => $image_file })) {
        die "Ошибка БД";
    }
    redirect $back_to_album_link;
};

get '/albums/add' => sub {
    template 'add_album', { csrf_token => generate_csrf_token(session('secret')) };
};

post '/albums/add' => sub {
    my $csrf_token = param('csrf_token');
    redirect '/profile' unless session('secret') && check_csrf_token($csrf_token, session('secret'));
    my $name = param('name');
    my $year = param('year');
    my $group_name = param('group_name');
    my @err;
    if (!$name) {
        push @err, 'Не введено имя';
    }
    if (!$year) {
        push @err, 'Не введён год';
    }
    if ($year =~ /\D/) {
        push @err, 'Неправильно указан год';
    }
    if (!$group_name) {
        push @err, 'Не введена группа';
    }
    if (@err) {
        $name = encode_entities($name, '<>&"\'');
        $year = encode_entities($year, '<>&"\'');
        $group_name = encode_entities($group_name, '<>&"\'');
        return template 'add_album', { name => $name, year => $year, group_name => $group_name, err => \@err, csrf_token => generate_csrf_token(session('secret')) };
    }
    my $id = database->quick_lookup('album', {name => $name, year => 0+$year, group_name => $group_name}, 'id');
    if (!$id) {
        unless (database->quick_insert('album', { name => $name, year => 0+$year, group_name => $group_name })) {
            die 'Ошибка БД';
        }
        $id = database->quick_lookup('album', {name => $name, year => 0+$year, group_name => $group_name}, 'id');
    }
    if (!database->quick_select('users_to_albums', {user_id => session('user_id'), album_ud => $id})) {
        if (!database->quick_insert('users_to_albums', {user_id => session('user_id'), album_id => $id})) {
            die 'Ошибка БД';
        }
    }
    redirect '/profile';
};

get '/albums/:id' => sub {
    my $id = unpack 'Q', pack 'H*', param('id');
    my $sth = database->prepare('select users_to_albums.user_id as user_id, album.name as album_name, album.year as album_year, album.group_name as album_group_name, track.name as track_name, track.format as track_format, track.id as track_id, track.image_src as track_image_src, track.image_file as track_image_file from album left join track on album.id = track.album_id join users_to_albums on album.id = users_to_albums.album_id where album.id = ?;');
    unless ($sth->execute($id)) {
        die "DB error";
    }
    my $tracks_info = $sth->fetchall_arrayref({});
    my $album_info = @$tracks_info ? {
        album_name => $tracks_info->[0]->{album_name},
        album_year => $tracks_info->[0]->{album_year},
        album_group_name => $tracks_info->[0]->{album_group_name}
    } : {};
    my $user_has_permissions = (@$tracks_info ? defined $tracks_info->[0]->{user_id} && $tracks_info->[0]->{user_id} eq session('user_id') : 0);

    @$tracks_info = map { my $track_info = $_; %$track_info = map {
        $_ eq 'track_id' && defined $track_info->{$_} ?
            ($_ => unpack 'H*', pack 'Q', $track_info->{$_}) :
            ($_ =~ /^(?:track_name|track_format|track_image_file|track_image_src)$/ && defined $track_info->{$_} ?
                ($_ => encode_entities($track_info->{$_}, '<>&"\'')) :
                ())
        } keys %$track_info;
        keys %$track_info ? $track_info : (); } @$tracks_info;
    %$album_info = map { ($_ => encode_entities($album_info->{$_}, '<>&"\'')) } keys %$album_info;
    template 'album', {
                       user_has_permissions => $user_has_permissions,
                       csrf_token => generate_csrf_token(session('secret')),
                       keys %$album_info ? (album_info => $album_info) : (),
                       @$tracks_info ? (tracks_info => $tracks_info) : ()};
};

post '/logout' => sub {
    my $csrf_token = param('csrf_token');
    redirect '/profile' unless session('secret') && check_csrf_token($csrf_token, session('secret'));
    context->destroy_session;
    redirect '/';
};

post '/remove' => sub {
    my $csrf_token = param('csrf_token');
    redirect '/profile' unless session('secret') && check_csrf_token($csrf_token, session('secret'));
    database->quick_delete('user', {login => session('login')});
    context->destroy_session;
    redirect '/';
};

get '/users' => sub {
    redirect '/' unless session('login') eq 'admin';
    my @users = database->quick_select('user', {});
    @users = map { my $user = $_; %$user = map { ($_ => encode_entities($user->{$_}, '<>^"\'')) } keys %$user; $user; } @users;
    template 'users', {users => \@users};
};

get '/profile' => sub {
    my $sth = database->prepare('select album.id as album_id, album.name as album_name from album join users_to_albums on users_to_albums.album_id = album.id where users_to_albums.user_id = ?;');
    unless ($sth->execute(session('user_id'))) {
        die "Ошибка БД";
    }
    my $albums = $sth->fetchall_arrayref({});
    @$albums = map { my $album = $_; %$album = map { ($_ => encode_entities($album->{$_}, '<>&"\'')) } keys %$album; $album->{album_id} = unpack 'H*', pack 'Q', $album->{album_id}; $album; } @$albums;
    template 'profile', { login => encode_entities(session('login'), '<>&"\''),
                          csrf_token => generate_csrf_token(session('secret')),
                          @$albums ? (albums => $albums) : () };
};

get '/signup' => sub {
    template 'signup';
};

post '/signup' => sub {
    my $login = param('login');
    my $pass = param('pass');
    my @err;
    if (!$login) {
        push @err, 'Не введён логин';
    }
    if (!$pass) {
        push @err, 'Не введён пароль';
    }
    if (database->quick_select('user', { login => $login })) {
        push @err, 'Пользователь с таким логином уже существует';
    }
    if (@err) {
        $login = encode_entities($login, '<>&"\'');
        $pass = encode_entities($pass, '<>&"\'');
        return template 'signup' => {login => $login, pass => $pass, err => \@err};
    }
    my $safe_password = modify_pass($pass);
    if (database->quick_insert('user', { login => $login, pass => $safe_password })) {
        session('login' => $login);
        session('secret' => generate_random_seq(10));
        my $id = database->quick_lookup('user', {login => $login}, 'id');
        session('user_id' => $id);
        redirect '/profile';
    }
    else {
        die "Ошибка БД";
    }
};

get '/signin' => sub {
    template 'signin', {requested_path => param('requested_path')};
};

post '/signin' => sub {
    my $login = param('login');
    my $pass = param('pass');
    my $requested_path = param('requested_path');
    my @err;
    
    if (!$login) {
        push @err, 'Не введён логин';
    }
    if (!$pass) {
        push @err, 'Не введён пароль';
    }
    if (@err) {
        $login = encode_entities($login, '<>&"\'');
        $pass = encode_entities($pass, '<>&"\'');
        return template 'signin', {login => $login, pass => $pass, err => \@err};
    }
    my $real_pass = database->quick_lookup('user', { login => $login }, 'pass');
    unless ($real_pass && check_pass($pass, $real_pass)) {
        push @err, 'Неверные логин/пароль';
        $login = encode_entities($login, '<>&"\'');
        $pass = encode_entities($pass, '<>&"\'');
        return template 'signin', {login => $login, pass => $pass, err => \@err};
    }
    session('login' => $login);
    session('secret' => generate_random_seq(10));
    my $id = database->quick_lookup('user', {login => $login}, 'id');
    session('user_id' => $id);
    if ($requested_path) {
        redirect $requested_path;
    }
    else {
        redirect '/profile';
    }
};

get '/' => sub {
    template 'index';
};

{
    my $SALT = 'web_music_library';
    my $DEFAULT_VERSION = 2;

    my %CHECKERS = (
        1 => sub { $_[1] eq md5_hex(Encode::encode_utf8($_[0] . $SALT)) },
        2 => sub {
            my ($rand, $hash) = split '#', $_[1];
            return $hash eq md5_hex(Encode::encode_utf8($_[0] . $SALT . $rand));
        }
    );

    sub generate_csrf_token {
        my ($secret) = @_;
        my $rand = generate_random_seq(5);
        return sprintf('%s#%s', $rand, md5_hex(Encode::encode_utf8($rand . $secret)));
    }

    sub check_csrf_token {
        my ($token, $secret) = @_;
        my ($rand, $hash) = split '#', $token;
        return $hash eq md5_hex(Encode::encode_utf8($rand . $secret));
    }

    sub generate_random_seq {
        my ($len) = @_;
        my $rand = "";
        for (0..$len-1) {
            $rand .= chr(int(rand(40)) + 37);
        }
        return $rand;
    }

    sub modify_pass {
        my ($pass) = @_;
        if ($DEFAULT_VERSION == 1) {
            return md5_hex(Encode::encode_utf8($pass . $SALT));
        }
        elsif ($DEFAULT_VERSION == 2) {
            my $rand = generate_random_seq(5);
            return sprintf("#%d#%s#%s", $DEFAULT_VERSION, $rand, md5_hex(Encode::encode_utf8($pass . $SALT . $rand)));
        }
        else {
            die "Version $DEFAULT_VERSION not supported yet";
        }
    }

    sub check_pass {
        my ($pass, $real_pass) = @_;
        my $version = 1;
        if ($real_pass =~ /^#(\d+)#(.+)$/) {
            ($version, $real_pass) = ($1, $2);
            die "Unknown version" unless exists $CHECKERS{$version};
        }
        return $CHECKERS{$version}->($pass, $real_pass);
    }
}

true;
