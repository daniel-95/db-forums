#!usr/bin/perl
use Mojolicious::Lite;
use Mojo::JSON qw(encode_json decode_json);
use TechDBApi;

app->config(hypnotoad => {listen => ['http://*:3000']});

mysql_connect('db_forums', 'root', 'PwD73HDa');

get '/' => sub {
	my $c = shift;
	$c->render(text => 'Hello, World!');
};

get '/check' => sub {
	my $c = shift;
	$c->render(text => check());
};

get '/db/api/clear' => sub {
	my $c = shift;
	$c->render(text => clear());
};

get '/db/api/user/create' => sub {
	my $c = shift;
	$c->render(text => create_user('username123', 'user777@mail.ru', 'about me', 'ivan'));
};

get '/db/api/forum/create' => sub {
	my $c = shift;
	$c->render(text => create_forum('Best Forum', 'bestforum', 1));
};

app->start;