#!usr/bin/perl
use Mojolicious::Lite;
use TechDBApi;

mysql_connect('db_forums', 'root', 'root');

get '/' => sub {
	my $c = shift;
	$c->render(text => 'Hello, World!');
};

get '/create_post' => sub {
	my $c = shift;
	$c->render(text => check());
};

get '/db/api/clear' => sub {
	my $c = shift;
	$c->render(text => clear());
};

app->start;
