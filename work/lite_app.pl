#!usr/bin/perl
use utf8;
use Mojolicious::Lite;
use Mojo::JSON qw(to_json from_json);
use TechDBApi;

my %conf_info = readConf("database.conf");
mysql_connect($conf_info{database}, $conf_info{login}, $conf_info{password});

########## COMMON ##########

get '/db/api/status' => sub {
	my $c = shift;
	$c->render(text => to_json(status()));
};

post '/db/api/clear' => sub {
	my $c = shift;
	$c->render(text => to_json(clear()));
};

########## USER ##########

post '/db/api/user/create' => sub {
	my $c = shift;
	my $json_data = {};
	my $code = 0;
	my $answer = {};
	my %option = ("isAnonymous" => 0);
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$code = 2;
	}

	if($code == 0)
	{
		if(defined $json_data->{isAnonymous}) {
			$option{isAnonymous} = $json_data->{isAnonymous};
		}
		$answer = create_user($json_data->{username}, $json_data->{email}, $json_data->{about}, $json_data->{name}, \%option);
	}
	else
	{
		$answer->{code} = $code;
		$answer->{response} = {};
	}

	my $str = to_json($answer);

	$c->render(text => $str);
};

get '/db/api/user/details' => sub {
	my $c = shift;
	my $email = $c->param("user");
	$c->render(text => to_json(user_details($email)));
};

get '/db/api/user/listFollowers' => sub {
	my $c = shift;
	my %params = ("since_id" => undef, "order" => "DESC", "limit" => 5);
	$c->render(text => to_json(user_list_follow('follower', 'user777@mail.ru', \%params)));
};

get '/db/api/user/listFollowing' => sub {
	my $c = shift;
	my %params = ("since_id" => 0, "order" => "ASC", "limit" => undef);
	$c->render(text => to_json(user_list_follow('followee', 'user777@mail.ru', \%params)));
};

########## FORUM ##########

post '/db/api/forum/create' => sub {
	my $c = shift;
	my $json_data = {};
	my $error = 0;
	my $code = 0;
	my $answer = {};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$code = 2;
	}

	if($code == 0)
	{
		$answer = create_forum($json_data->{name}, $json_data->{short_name}, $json_data->{user});
	}
	else
	{
		$answer->{code} = $code;
		$answer->{response} = {};
	}

	$c->render(text => to_json($answer));
};

get '/db/api/forum/details' => sub {
	my $c = shift;
	my $forum = $c->param("forum");						#short_name
	my $related = $c->param("related") || undef;		#related
	$c->render(text => to_json(forum_details($forum, $related)));
};

########## THREAD ##########

post '/db/api/thread/create' => sub {
	my $c = shift;
	my $json_data = {};
	my $error = 0;
	my $code = 0;
	my $answer = {};
	my %optional = (isDeleted => 0, isClosed => 0);
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$code = 2;
	}

	if($code == 0)
	{
		if(defined $json_data->{isDeleted}) {
			$optional{isDeleted} = $json_data->{isDeleted};
		}
		if(defined $json_data->{isClosed}) {
			$optional{isClosed} = $json_data->{isClosed};
		}

		$answer = create_thread($json_data->{forum}, $json_data->{title}, $json_data->{user},
			$json_data->{date}, $json_data->{message}, $json_data->{slug}, \%optional);
	}
	else
	{
		$answer->{code} = $code;
		$answer->{response} = {};
	}

	$c->render(text => to_json($answer));
};

get '/db/api/thread/details' => sub {
	my $c = shift;
	my $id = $c->param("thread");						#id
	my $related = $c->req->params->every_param("related") || undef;		#related
	$c->render(text => to_json(thread_details($id, $related)));
};

########## POST ##########

post '/db/api/post/create' => sub {
	my $c = shift;
	my $json_data = {};
	my $error = 0;
	my $code = 0;
	my $answer = {};
	my %optional = (isDeleted => 0, isApproved => 0, isHighlighted => 0, isEdited => 0, isSpam => 0, parent => undef);
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$code = 2;
	}

	if($code == 0)
	{
		if(defined $json_data->{isDeleted}) {
			$optional{isDeleted} = $json_data->{isDeleted};
		}
		if(defined $json_data->{isApproved}) {
			$optional{isApproved} = $json_data->{isApproved};
		}
		if(defined $json_data->{isHighlighted}) {
			$optional{isHighlighted} = $json_data->{isHighlighted};
		}
		if(defined $json_data->{isEdited}) {
			$optional{isEdited} = $json_data->{isEdited};
		}
		if(defined $json_data->{isSpam}) {
			$optional{isSpam} = $json_data->{isSpam};
		}
		if(defined $json_data->{parent}) {
			$optional{parent} = $json_data->{parent};
		}
		else {
			$optional{parent} = undef;
		}

		$answer = create_post($json_data->{date}, $json_data->{thread}, $json_data->{message},
			$json_data->{user}, $json_data->{forum}, \%optional);
	}
	else
	{
		$answer->{code} = $code;
		$answer->{response} = {};
	}

	$c->render(text => to_json($answer));
};

get '/db/api/post/details' => sub {
	my $c = shift;
	my $id = $c->param("post");						#id
	my $related = $c->req->params->every_param("related") || undef;		#related
	$c->render(text => to_json(post_details($id, $related)));
};

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

app->start;