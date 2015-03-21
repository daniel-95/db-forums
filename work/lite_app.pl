#!usr/bin/perl
use Mojolicious::Lite;
use Mojo::JSON qw(encode_json decode_json);
use TechDBApi;

app->config(hypnotoad => {listen => ['http://*:3000']});

my %conf_info = readConf("database.conf");
mysql_connect($conf_info{database}, $conf_info{login}, $conf_info{password});

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

##### FUNCTIONS #####

sub readConf
{
	my $line;
	my $key;
	my $val;

	my $conf_file = shift;
	open(CONFIG, "< $conf_file") || die "No configuration file!";
	my @data = <CONFIG>;
	chomp(@data);

	my %c = ();

	for $line(@data)
	{
		($key, $val) = split('=', $line);
		chomp($key);
		chomp($val);

		$c{$key} = $val;
	}

	close(CONFIG);

	return %c;
}
