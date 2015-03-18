#!usr/bin/perl
use Mojolicious::Lite;
use TechDBApi;

mysql_connect('db_forums', 'root', 'root');

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

app->start;
