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

get 'db/api/user/listPosts' => sub {
	my $c = shift;
	my $order = "desc";
	my $answer = {code => 0, response => {}};
	my %optional = (since => undef, limit => undef, order => "desc");

	my $user = $c->param("user");

	unless(defined $user) {
		$answer->{code} = 3;
	}

	$optional{since} = $c->param("since");
	$optional{limit} = $c->param("limit");

	if(defined $c->param("order")) {
		$order = $c->param("order");

		if(lc $order ne "asc" && lc $order ne "desc") {
			$answer->{code} = 3;
		} else {
			$optional{order} = $order;
		}
	}

	if($answer->{code} == 0) {
		$answer = user_list_posts($user, \%optional);
	}

	$c->render(text => to_json($answer));
};

post 'db/api/user/updateProfile' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{about} && defined $json_data->{user} && defined $json_data->{name}) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = user_update_profile($json_data->{user}, $json_data->{name}, $json_data->{about});
	}

	$c->render(text => to_json($answer));
};

post 'db/api/user/follow' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{follower} && defined $json_data->{followee}) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = user_follow($json_data->{follower}, $json_data->{followee});
	}

	$c->render(text => to_json($answer));
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

get 'db/api/thread/list' => sub {
	my $c = shift;
	my $code = 0;
	my $answer = {code => 0, response => {}};
	my %optional = (since => undef, limit => undef, order => "desc");
	my $entity = "forum";
	my $param = undef;
	my $order = "";

	my $forum = $c->param("forum");
	my $user = $c->param("user");

	if(defined $forum) {
		$entity = "forum";
		$param = "'".$forum."'";
	} elsif(defined $user) {
		$entity = "user";
		$param = "'".$user."'";
	} else {
		$answer->{code} = 3;
	}

	$optional{since} = $c->param("since");
	$optional{limit} = $c->param("limit");

	if(defined $c->param("order")) {
		$order = $c->param("order");

		if(lc $order ne "asc" && lc $order ne "desc") {
			$answer->{code} = 3;
		} else {
			$optional{order} = $order;
		}
	}

	if($answer->{code} == 0) {
		$answer = thread_list($entity, $param, \%optional);
	}

	$c->render(text => to_json($answer));
};

get '/db/api/thread/listPosts' => sub {
	my $c = shift;
	my $code = 0;
	my $answer = {code => 0, response => {}};
	my %optional = (since => undef, limit => undef, order => "desc", sort => "flat");
	my $thread_id = $c->param("thread");
	my $order = "";
	my $sort= "";

	$optional{since} = $c->param("since");
	$optional{limit} = $c->param("limit");

	if(defined $c->param("order")) {
		$order = $c->param("order");

		if(lc $order ne "asc" && lc $order ne "desc") {
			$answer->{code} = 3;
		} else {
			$optional{order} = $order;
		}
	}

	if(defined $c->param("sort")) {
		$sort = $c->param("sort");

		if(lc $sort ne "flat" && lc $sort ne "tree" && lc $sort ne "parent_tree") {
			$answer->{code} = 3;
		} else {
			$optional{sort} = $sort;
		}
	}

	if($answer->{code} == 0) {
		$answer = thread_list_posts($thread_id, \%optional);
	}

	$c->render(text => to_json($answer));
};

post 'db/api/thread/remove' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{thread} && $json_data->{thread} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = thread_remove($json_data->{thread});
	}

	$c->render(text => to_json($answer));
};

post 'db/api/thread/restore' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{thread} && $json_data->{thread} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = thread_restore($json_data->{thread});
	}

	$c->render(text => to_json($answer));
};

post 'db/api/thread/close' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{thread} && $json_data->{thread} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = thread_close($json_data->{thread});
	}

	$c->render(text => to_json($answer));
};

post 'db/api/thread/open' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{thread} && $json_data->{thread} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = thread_open($json_data->{thread});
	}

	$c->render(text => to_json($answer));
};

post 'db/api/thread/update' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{thread} && $json_data->{thread} =~ m/^\d+/) {
		$answer->{code} = 3;
	}
	unless(defined $json_data->{message} && defined $json_data->{slug}) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = thread_update($json_data->{thread}, $json_data->{message}, $json_data->{slug});
	}

	$c->render(text => to_json($answer));
};

post '/db/api/thread/vote' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{thread} && $json_data->{thread} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	unless(defined $json_data->{vote} && $json_data->{vote} =~ m/-?1/) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = thread_vote($json_data->{thread}, $json_data->{vote});
	}

	$c->render(text => to_json($answer));
};

post 'db/api/thread/subscribe' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{thread} && $json_data->{thread} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	unless(defined $json_data->{user}) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = thread_subscribe($json_data->{thread}, $json_data->{user});
	}

	$c->render(text => to_json($answer));
};

post 'db/api/thread/unsubscribe' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{thread} && $json_data->{thread} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	unless(defined $json_data->{user}) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = thread_unsubscribe($json_data->{thread}, $json_data->{user});
	}

	$c->render(text => to_json($answer));
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

get 'db/api/post/list' => sub {
	my $c = shift;
	my $code = 0;
	my $answer = {code => 0, response => {}};
	my %optional = (since => undef, limit => undef, order => "desc");
	my $entity = "forum";
	my $param = undef;
	my $order = "";

	my $forum = $c->param("forum");
	my $thread = $c->param("thread");

	if(defined $forum) {
		$entity = "forum";
		$param = "'".$forum."'";
	} elsif(defined $thread) {
		$entity = "thread_id";
		$param = $thread;
	} else {
		$answer->{code} = 3;
	}

	$optional{since} = $c->param("since");
	$optional{limit} = $c->param("limit");

	if(defined $c->param("order")) {
		$order = $c->param("order");

		if(lc $order ne "asc" && lc $order ne "desc") {
			$answer->{code} = 3;
		} else {
			$optional{order} = $order;
		}
	}

	if($answer->{code} == 0) {
		$answer = post_list($entity, $param, \%optional);
	}

	$c->render(text => to_json($answer));
};

post 'db/api/post/remove' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{post} && $json_data->{post} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = post_remove($json_data->{post});
	}

	$c->render(text => to_json($answer));
};

post 'db/api/post/restore' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{post} && $json_data->{post} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = post_restore($json_data->{post});
	}

	$c->render(text => to_json($answer));
};

post 'db/api/post/update' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{post} && $json_data->{post} =~ m/^\d+/) {
		$answer->{code} = 3;
	}
	unless(defined $json_data->{message}) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = post_update($json_data->{post}, $json_data->{message});
	}

	$c->render(text => to_json($answer));
};

post '/db/api/post/vote' => sub {
	my $c = shift;
	my $json_data = {};
	my $answer = {code => 0, response => {}};
	my $body = $c->req->body;

	eval {
	 	$json_data = from_json($body);
	};
	if ($@) {
	 	$answer->{code} = 2;
	}

	unless(defined $json_data->{post} && $json_data->{post} =~ m/^\d+/) {
		$answer->{code} = 3;
	}

	unless(defined $json_data->{vote} && $json_data->{vote} =~ m/-?1/) {
		$answer->{code} = 3;
	}

	if($answer->{code} == 0) {
		$answer = post_vote($json_data->{post}, $json_data->{vote});
	}

	$c->render(text => to_json($answer));
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