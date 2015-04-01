#!usr/bin/perl
use Mojolicious::Lite;
use Mojo::JSON qw(encode_json decode_json);
use TechDBApi;

my %conf_info = readConf("database.conf");
mysql_connect($conf_info{database}, $conf_info{login}, $conf_info{password});

get '/' => sub {
	my $c = shift;
	$c->render(text => "there is info: ".get_id_by_email('user777@mail.ru'));
};

get '/db/api/status' => sub {
	my $c = shift;
	$c->render(text => encode_json(status()));
};

get '/db/api/clear' => sub {
	my $c = shift;
	$c->render(text => encode_json(clear()));
};

get '/db/api/user/create' => sub {
	my $c = shift;
	$c->render(text => encode_json(create_user('username123', 'user777@mail.ru', 'about me', 'ivan')));
};

get '/db/api/user/details' => sub {
	my $c = shift;
	$c->render(text => encode_json(user_details('user777@mail.ru')));
};

get '/db/api/forum/create' => sub {
	my $c = shift;
	$c->render(text => encode_json(create_forum('Best Forum', 'bestforum', 1)));
};

get '/db/api/user/listFollowers' => sub {
	my $c = shift;
	my %params = ("since_id" => undef, "order" => "DESC", "limit" => 5);
	$c->render(text => encode_json(user_list_follow('follower', 'user777@mail.ru', \%params)));
};

get '/db/api/user/listFollowing' => sub {
	my $c = shift;
	my %params = ("since_id" => 0, "order" => "ASC", "limit" => undef);
	$c->render(text => encode_json(user_list_follow('followee', 'user777@mail.ru', \%params)));
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
