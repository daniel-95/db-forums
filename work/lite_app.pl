#!usr/bin/perl
use Mojolicious::Lite;
use TechDBApi;

get '/' => sub {
	my $c = shift;
	$c->render(text => 'Hello, World!');
};

get '/create_post' => sub {
	my $c = shift;
	$c->render(text => create_post());
};

app->start;
