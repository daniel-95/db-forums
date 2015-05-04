#!usr/bin/perl
package TechDBApi;
use DBI;
use utf8;

BEGIN
{
	use Exporter ();
	@ISA = qw(Exporter);
	@EXPORT = qw(&status 
				 &clear 

				 &mysql_connect 

				 &create_user 
				 &user_details
				 &user_list_posts
				 &user_update_profile
				 &user_follow
				 &user_unfollow
				 &user_list_follow

				 &create_forum 
				 &forum_details 
				 &forum_list_posts
				 &forum_list_users
				 &forum_list_threads

				 &create_thread 
				 &thread_details
				 &thread_list 
				 &thread_list_posts 
				 &thread_remove 
				 &thread_restore 
				 &thread_close 
				 &thread_open
				 &thread_update
				 &thread_vote
				 &thread_subscribe
				 &thread_unsubscribe

				 &create_post 
				 &post_details 
				 &post_list 
				 &post_remove 
				 &post_restore 
				 &post_update 
				 &post_vote 
				);
}

########## VARIABLES ##########
$dbh = 0;
######### /VARIABLES ##########

########## COMMON FUNC ##########
sub mysql_connect
{
	my $database = shift;
	my $user = shift;
	my $password = shift;

	$dbh = DBI->connect("DBI:mysql:$database", $user, $password,  { mysql_enable_utf8 => 1 });
}

sub status 
{
	@tables = qw(user forum thread post);
	my $result = {code => "", response => ""};
	my $response = {};
	my $k, $v;
	my $query = undef;
	my $code = 0;
	my $res = undef;

	foreach(@tables)
	{
		$query = $dbh->prepare("SELECT count(*) from $_;");
		$res = $query->execute;

		if($res ne "0E0")
		{
			my @data = $query->fetchrow_array;
			$data_ref->{$_} = $data[0] + 0;
		}
		else
		{
			$data_ref = {};
			$code= 4;
		}
	}
	$query->finish;

	$result->{code} = $code;
	$result->{response} = $data_ref;

	return $result;
}

sub clear
{
	my $result = {code => "", response => "OK"};
	$code = 0;
	my @tables = qw(user forum thread post subscription follow);

	$dbh->do("SET session foreign_key_checks = 0;");

	foreach(@tables)
	{
		my $query = $dbh->prepare("TRUNCATE TABLE `".$_."`;");
		$res = $query->execute;
		print $_.": ".$res."\n";
		$query->finish;

		if($res ne "0E0")
		{
			print $_." truncate: ".$dbh->strerr."\n";
			$code = 4;
			last;
		}
	}

	$dbh->do("SET session foreign_key_checks = 1;");

	$result->{code} = $code;
	return $result;
}

sub get_id_by_email
{
	my $email = shift;

	$query = $dbh->prepare("select id from user where email = '$email';");
	$res = $query->execute;
	@data = $query->fetchrow_array;
	$query->finish;

	return $data[0];
}

sub get_email_by_id
{
	my $id = shift;

	$query = $dbh->prepare("select email from user where id = $id;");
	$res = $query->execute;
	@data = $query->fetchrow_array;
	$query->finish;

	return $data[0];
}

sub get_id_by_entity {
	my $entity = shift;

	$query = $dbh->prepare("select id from $entity order by id desc limit 1;");
	$res = $query->execute;
	@data = $query->fetchrow_array;
	$query->finish;

	return $data[0];
}

sub change_posts_count {
	my $post_id = shift;
	my $action = shift;
	my $sign = "+";
	my $res = undef;

	if($action eq "inc") {
		$sign = "+";
	} elsif($action eq "dec") {
		$sign = "-";
	} else {
		return -1;
	}
	my $query_string = "select thread_id from post where id = $post_id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return -1;
	}

	@data = $query->fetchrow_array;

	$query_string = "update thread set posts = posts $sign 1 where id = $data[0];";
	$query = $dbh->prepare($query_string);
	$res = $query->execute;

	$query->finish;

	return 1;
}

sub do_request {

}

sub in_array {
  grep {$_ eq $_[0]} @{$_[1]};
}

######### /COMMON FUNC ##########

########## USER FUNC ##########

sub create_user # username, email, about = '', name = '',  %option
{
	my $result = {code => 0, response => {}};
	my $response = {};

	my $username = shift;
	my $email = shift;

	my $about = shift;
	my $name = shift;
	my $params = shift;

	my $query = $dbh->prepare("INSERT INTO `user`(`username`, `email`, `about`, `name`, `isAnonymous`) VALUES('$username', '$email', '$about', '$name', $params->{isAnonymous});");
	my $res = $query->execute;

	if($DBI::err == 1062)
	{
		$result->{code} = 5;
	}
	elsif ($res != 1)
	{
		$result->{code} = 4;
	}

	$query->finish;

	if($result->{code} == 0)
	{
		$response->{about} = $about;
		$response->{email} = $email;
		$response->{isAnonymous} = $params->{isAnonymous};
		$response->{name} = $name;
		$response->{username} = $username;
		$response->{id} = get_id_by_email($email) + 0;
	}

	$result->{response} = $response;

	return $result;
}

sub user_details
{
	my $result = {code => 0, response => {}};
	my $response = {};
	my $followee_ref = [];
	my $follower_ref = [];
	my $subscr_ref = [];

	#main info
	my $email = shift;
	my $query = $dbh->prepare("select email, about, isAnonymous, id, name, username FROM user WHERE email = '$email';");
	$res = $query->execute;
	$response = $query->fetchrow_hashref;
	$response->{isAnonymous} = $response->{isAnonymous} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;

	for(keys %$response) {
		$response->{$_} = undef if($response->{$_} eq "");
	}

	$response->{id} += 0;
	$query->finish;

	my $user_id = get_id_by_email($email);
	my $query = $dbh->prepare("SELECT follower FROM follow WHERE followee = '$email';");

	#followers
	if($user_id > 0)
	{
		$res = $query->execute;
	}
	else
	{
		$result->{code} = 2;
		return $result;
	}

	if($DBI::err == 1064)
	{
		$result->{response} = {};
		$result->{code} = 2;

		return $result;
	}

	while(($fol_id) = $query->fetchrow_array)
	{
		push @$follower_ref, $fol_id; 
	}

	$query->finish;

	#followees
	my $query = $dbh->prepare("SELECT followee FROM follow WHERE follower = '$email';");
	$res = $query->execute;

	while(($fol_id) = $query->fetchrow_array)
	{
		push @$followee_ref, $fol_id; 
	}

	$query->finish;

	#subscriptions
	my $query = $dbh->prepare("SELECT thread_id FROM subscription WHERE user = '$email';");
	$res = $query->execute;

	while($sub_id = $query->fetchrow_array)
	{
		push @$subscr_ref, ($sub_id + 0); 
	}

	$query->finish;

	$response->{followers} = $follower_ref;
	$response->{following} = $followee_ref;
	$response->{subscriptions} = $subscr_ref;
	$result->{response} = $response;
	$result->{code} = 0;

	return $result;
}

sub user_follow {
	my $follower = shift;
	my $followee = shift;

	$query = $dbh->prepare("INSERT INTO follow (follower, followee) VALUES ('$follower', '$followee');");
	$res = $query->execute;
	$query->finish;

	return user_details($follower);
}

sub user_unfollow {
	my $follower = shift;
	my $followee = shift;

	$query = $dbh->prepare("delete from follow where follower = '$follower' and followee = '$followee';");
	$res = $query->execute;
	$query->finish;

	return user_details($follower);
}

sub user_list_follow # type, email, %params {since_id = undef, order = ASC/DESC, limit} 
{
	my $type = shift;		#follower/followee
	my $user = shift;
	my $optional = shift || {};

	my $count = 0;
	my $base_ref = {};
	my $array_users = [];
	my $result = {code => 4, response => {}};

	unless($type eq "follower" || $type eq "followee") {
		$result->{code} = 3;
		return $result;
	}

	my $pair = $type eq "follower" ? "followee" : "follower";

	my $query_string = "select u.email from follow f JOIN user u ON u.email = f.$type where f.$pair = '$user'";

	if(defined $optional->{since_id}) {
		$query_string .= " and u.id >= $optional->{since_id}";
	}

	$query_string .= " order by u.name $optional->{order}";

	if(defined $optional->{limit}) {
		$query_string .= " limit $optional->{limit}";
	}

	$query_string .= ";";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	$result->{code} = 0;

	while($base_ref = $query->fetchrow_hashref) {
		$base_ref = user_details($base_ref->{email});
		push @$array_users, $base_ref->{response};
	}

	$result->{response} = $array_users;
	return $result;
}

sub user_list_posts { # user [, since, order, limit]
	my $user = shift;
	my $optional = shift || {};

	my $count = 0;
	my $base_ref = {};
	my $array_posts = [];
	my $result = {code => 4, response => {}};
	my $query_string = "select id from post where user = '$user'";

	if(defined $optional->{since}) {
		$query_string .= " and date >= '$optional->{since}'";
	}

	$query_string .= " order by date $optional->{order}";

	if(defined $optional->{limit}) {
		$query_string .= " limit $optional->{limit}";
	}

	$query_string .= ";";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	$result->{code} = 0;

	while($base_ref = $query->fetchrow_hashref) {
		$base_ref = post_details($base_ref->{id});
		push @$array_posts, $base_ref->{response};
	}

	$result->{response} = $array_posts;
	return $result;
}

sub user_update_profile { # user, name, about
	my $user = shift;	# user email
	my $name = shift;	# user name
	my $about = shift;	# some info about user

	my $result = {code => 4, response => {}};

	my $query_string = "update user set name = '$name', about = '$about' where email = '$user';";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	$result = user_details($user);
	$query->finish;

	return $result;
}

######### /USER FUNC ##########

########## FORUM FUNC ##########

sub create_forum # name, short_name, user
{
	my $name = shift;
	my $short_name = shift;
	my $user = shift;

	my $result = {code => 0, response => {}};
	my $response = {};

	my $user_id = get_id_by_email($user);

	my $query = $dbh->prepare("INSERT INTO `forum`(`name`, `short_name`, `user_id`) VALUES('$name', '$short_name', $user_id);");
	my $res = $query->execute;

	if($DBI::err == 1062)
	{
		$result = forum_details($short_name);
	}
	elsif ($res != 1)
	{
		$result->{code} = 4;
	}

	else
	{
		$result->{code} = 0;
		$response->{name} = $name;
		$response->{short_name} = $short_name;
		$response->{user} = $user;
		$response->{id} = get_id_by_entity("forum") + 0;

		$result->{response} = $response;
	}

	$query->finish;
	return $result;
}

sub forum_details #short_name, [related]
{
	my $result = {code => 4, response => {}};
	my $res = undef;

	my $short_name = shift;
	my $related = shift || "";
	my $query_string = "select * from forum where short_name = '$short_name';";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	if($res eq "0E0")
	{
		$result->{code} = 1;
		return $result;
	}

	my $base_ref = $query->fetchrow_hashref;
	$u_email = get_email_by_id($base_ref->{user_id});

	if($related eq "user")
	{
		my $details_ref = user_details($u_email);
		$u_email = $details_ref->{response};
	}

	delete $base_ref->{user_id};
	$base_ref->{user} = $u_email;
	$base_ref->{id} += 0;

	$result->{code} = 0;
	$result->{response} = $base_ref;

	return $result;
}

sub forum_list_posts { 
	my $forum = shift;
	my $optional = shift || {};
	my $related = shift;

	my $count = 0;
	my $base_ref = {};
	my $array_posts = [];
	my $result = {code => 4, response => {}};
	my $query_string = "select id from post where forum = '$forum'";

	my @rslt = grep {
  		my $t = $_;
  		! grep { $_ eq $t } ("forum", "user", "thread");
	} @$related;

	if(scalar keys @rslt) {
		$result->{code} = 3;
		return $result;
	}

	if(defined $optional->{since}) {
		$query_string .= " and date >= '$optional->{since}'";
	}

	$query_string .= " order by date $optional->{order}";

	if(defined $optional->{limit}) {
		$query_string .= " limit $optional->{limit}";
	}

	$query_string .= ";";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	$result->{code} = 0;

	while($base_ref = $query->fetchrow_hashref) {
		$base_ref = post_details($base_ref->{id}, $related);
		push @$array_posts, $base_ref->{response};
	}

	$result->{response} = $array_posts;
	return $result;
}

sub forum_list_users {
	my $forum = shift;
	my $optional = shift || {};

	my $count = 0;
	my $base_ref = {};
	my $array_users = [];
	my $result = {code => 4, response => {}};

	my $query_string = "select distinct u.email from post p JOIN user u ON u.email = p.user where forum = '$forum'";

	if(defined $optional->{since_id}) {
		$query_string .= " and u.id >= $optional->{since_id}";
	}

	$query_string .= " order by u.name $optional->{order}";

	if(defined $optional->{limit}) {
		$query_string .= " limit $optional->{limit}";
	}

	$query_string .= ";";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	$result->{code} = 0;

	while($base_ref = $query->fetchrow_hashref) {
		$base_ref = user_details($base_ref->{email});
		push @$array_users, $base_ref->{response};
	}

	$result->{response} = $array_users;
	return $result;
}

sub forum_list_threads { 
	my $forum = shift;
	my $optional = shift || {};
	my $related = shift;

	my $count = 0;
	my $base_ref = {};
	my $array_threads = [];
	my $result = {code => 4, response => {}};
	my $query_string = "select id from thread where forum = '$forum'";

	my @rslt = grep {
  		my $t = $_;
  		! grep { $_ eq $t } ("forum", "user");
	} @$related;

	if(scalar keys @rslt) {
		$result->{code} = 3;
		return $result;
	}

	if(defined $optional->{since}) {
		$query_string .= " and date >= '$optional->{since}'";
	}

	$query_string .= " order by date $optional->{order}";

	if(defined $optional->{limit}) {
		$query_string .= " limit $optional->{limit}";
	}

	$query_string .= ";";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	$result->{code} = 0;

	while($base_ref = $query->fetchrow_hashref) {
		$base_ref = thread_details($base_ref->{id}, $related);
		push @$array_threads, $base_ref->{response};
	}

	$result->{response} = $array_threads;
	return $result;
}

######### /FORUM FUNC ##########

######### POST FUNC #########

sub create_post # date, thread_id, message, user, forum_short, [options]
{
	my $date = shift || undef;
	my $thread_id = shift || undef;
	my $message = shift || undef;
	my $user = shift ||undef;
	my $forum_short = shift || undef;
	my $parent = undef;

	my $options = shift || undef;

	if(!defined $options->{parent}) {
		$parent = "null";
	}
	else {
		$parent = $options->{parent};
	}

	my $result = {code => 0, response => {}};

	my $query_string = "INSERT INTO `post`"
						."(`message`, `date`, `thread_id`, `user`, `forum`, `is_deleted`, `is_approved`, `is_highlighted`, `is_spam`, `is_edited`, `parent_id`) "
						."VALUES('$message', '$date', $thread_id, '$user', '$forum_short', $options->{isDeleted}, $options->{isApproved}, "
						."$options->{isHighlighted}, $options->{isSpam}, $options->{isEdited}, $parent);";

	my $query = $dbh->prepare($query_string);

	my $res = $query->execute;

	if ($res != 1)
	{
		$result->{code} = 4;
	}
	else
	{
		$result->{code} = 0;
		my $post_id = get_id_by_entity("post") + 0;

		change_posts_count($post_id, "inc");

		my $response->{date} = $date;
		$response->{message} = $message;
		$response->{forum} = $forum_short;
		$response->{user} = $user;
		$response->{isApproved} = $options->{isApproved};
		$response->{isEdited} = $options->{isEdited};
		$response->{isDeleted} = $options->{isDeleted};
		$response->{isHighlighted} = $options->{isHighlighted};
		$response->{isSpam} = $options->{isSpam};
		$response->{parent} = $options->{parent} + 0;
		$response->{thread} = $thread_id + 0;
		$response->{id} = $post_id;

		$result->{response} = $response;
	}

	$query->finish;
	return $result;
}

sub post_details # id [, related(user, forum, thread)]
{
	my $id = shift;
	my $related = shift;
	my $res = undef;
	my $details_ref = {};

	my $result = {code => 4, response => {}};
	my $query_string = "select * from post where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	my $base_ref = $query->fetchrow_hashref;

	if(scalar keys %$base_ref == 0) {
		$result->{code} = 1;
		return $result;
	}

	if(in_array("forum", $related))
	{
		$details_ref = forum_details($base_ref->{forum});
		$base_ref->{forum} = $details_ref->{response};
	}

	if(in_array("user", $related))
	{
		$details_ref = user_details($base_ref->{user});
		$base_ref->{user} = $details_ref->{response};
	}

	if(in_array("thread", $related))
	{
		$details_ref = thread_details($base_ref->{thread_id});
		$base_ref->{thread_id} = $details_ref->{response};
	}

	$base_ref->{isDeleted} = delete $base_ref->{is_deleted} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{isApproved} = delete $base_ref->{is_approved} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{isEdited} = delete $base_ref->{is_edited} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{isHighlighted} = delete $base_ref->{is_highlighted} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{isSpam} = delete $base_ref->{is_spam} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	
	$base_ref->{likes} += 0;
	$base_ref->{dislikes} += 0;
	$base_ref->{points} = $base_ref->{likes} - $base_ref->{dislikes};
	$base_ref->{parent} = delete $base_ref->{parent_id};
	$base_ref->{parent} += 0 if(defined $base_ref->{parent});

	$base_ref->{thread} = delete $base_ref->{thread_id};

	unless(in_array("thread", $related)) {
		$base_ref->{thread} += 0;
	}

	$base_ref->{id}  = $id + 0;

	$result->{code} = 0;
	$result->{response} = $base_ref;

	return $result;
}

sub post_list {	# entity, param [, since, limit, order]
	my $entity = shift || undef;
	my $param = shift || undef;
	my $optional = shift || {};

	my $count = 0;
	my $base_ref = {};
	my $array_posts = [];
	my $result = {code => 4, response => {}};
	my $query_string = "select id from post where $entity = $param";

	if(defined $optional->{since}) {
		$query_string .= " and date >= '$optional->{since}'";
	}

	$query_string .= " order by date $optional->{order}";

	if(defined $optional->{limit}) {
		$query_string .= " limit $optional->{limit}";
	}

	$query_string .= ";";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	$result->{code} = 0;

	while($base_ref = $query->fetchrow_hashref) {
		$base_ref = post_details($base_ref->{id});
		push @$array_posts, $base_ref->{response};
	}

	$result->{response} = $array_posts;
	return $result;
}

sub post_remove { # id
	my $id = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "select is_deleted from post where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	my ($is_del) = $query->fetchrow_array;
	$query->finish;

	if($is_del == 0) {
		$query_string = "update post set is_deleted = 1 where id = $id;";

		$query = $dbh->prepare($query_string);
		eval {
			$res = $query->execute;
		};
		if($@) {
			return $result;
		}
		change_posts_count($id, "dec");
	}

	$result->{code} = 0;
	$result->{response} = { post => $id };
	$query->finish;

	return $result;
}

sub post_restore { # id
	my $id = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "select is_deleted from post where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	my ($is_del) = $query->fetchrow_array;
	$query->finish;

	if($is_del == 1) {
		$query_string = "update post set is_deleted = 0 where id = $id;";

		$query = $dbh->prepare($query_string);
		eval {
			$res = $query->execute;
		};
		if($@) {
			return $result;
		}
		change_posts_count($id, "inc");
	}

	$result->{code} = 0;
	$result->{response} = { post => $id };
	$query->finish;

	return $result;
}

sub post_update { # id, message
	my $id = shift;
	my $message = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "update post set message = '$message' where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	$result = post_details($id);
	$query->finish;

	return $result;
}

sub post_vote { # id, vote
	my $id = shift;
	my $vote = shift;
	my $result = {code => 4, response => {}};
	my $entity = "likes";

	if($vote == -1) {
		$entity = "dislikes";
	}

	my $query_string = "update post set $entity = $entity + 1 where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	$result = post_details($id);
	$query->finish;

	return $result;
}

######### /POST FUNC #########

######### THREAD FUNC #########

sub create_thread #forum, title, is_closed, user, date, message, slug [, is_deleted]
{
	my $forum = shift || undef;
	my $title = shift || undef;
	my $user = shift || undef;
	my $date = shift ||undef;
	my $message = shift || undef;
	my $slug = shift || undef;


	my $options = shift ||undef;

	my $result = {code => 0, response => {}};

	my $query_string = "INSERT INTO `thread`"
						."(`title`, `date`, `message`, `forum`, `user`, `is_deleted`, `is_closed`, `slug`, `likes`, `dislikes`, `posts`) "
						."VALUES('$title', '$date', '$message', '$forum', '$user', $options->{isDeleted}, $options->{isClosed}, '$slug', "
						."0, 0, 0);";
	
	my $query = $dbh->prepare($query_string);

	my $res = $query->execute;

	if ($res != 1)
	{
		$result->{code} = 4;
	}
	else
	{
		$result->{code} = 0;
		my $response->{title} = $title;
		$response->{date} = $date;
		$response->{message} = $message;
		$response->{forum} = $forum;
		$response->{user} = $user;
		$response->{isDeleted} = $is_deleted;
		$response->{isClosed} = $options->{isClosed};
		$response->{slug} = $slug;
		$response->{likes} = $likes + 0;
		$response->{dislikes} = $dislikes + 0;
		$response->{posts} = $posts + 0;
		$response->{id} = get_id_by_entity("thread") + 0;

		$result->{response} = $response;
	}

	$query->finish;
	return $result;
}

sub thread_details #id, [, related(user, forum)]
{
	my $id = shift;
	my $related = shift;
	my $res = undef;
	my $details_ref = {};

	my $result = {code => 4, response => {}};
	my $query_string = "select * from thread where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	$base_ref = $query->fetchrow_hashref;

	if($res eq "0E0")
	{
		$result->{code} = 1;
		return $result;
	}

	my @rslt = grep {
  		my $t = $_;
  		! grep { $_ eq $t } ("forum", "user");
	} @$related;

	if(scalar keys @rslt) {
		$result->{code} = 3;
		return $result;
	}

	if(in_array("forum", $related))
	{
		$details_ref = forum_details($base_ref->{forum});
		$base_ref->{forum} = $details_ref->{response};
	}

	if(in_array("user", $related))
	{
		$details_ref = user_details($base_ref->{user});
		$base_ref->{user} = $details_ref->{response};
	}

	$base_ref->{isDeleted} = delete $base_ref->{is_deleted} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{isClosed} = delete $base_ref->{is_closed} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{likes} += 0;
	$base_ref->{dislikes} += 0;

	$base_ref->{points} = $base_ref->{likes} - $base_ref->{dislikes};
	$base_ref->{posts} += 0;
	$base_ref->{id}  = $id + 0;

	$result->{code} = 0;
	$result->{response} = $base_ref;

	return $result;
}

sub thread_list {	# entity, param [, since, limit, order]
	my $entity = shift || undef;
	my $param = shift || undef;
	my $optional = shift || {};

	my $count = 0;
	my $base_ref = {};
	my $array_threads = [];
	my $result = {code => 4, response => {}};
	my $query_string = "select id from thread where $entity = $param";

	if(defined $optional->{since}) {
		$query_string .= " and date >= '$optional->{since}'";
	}

	$query_string .= " order by date $optional->{order}";

	if(defined $optional->{limit}) {
		$query_string .= " limit $optional->{limit}";
	}

	$query_string .= ";";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	$result->{code} = 0;

	while($base_ref = $query->fetchrow_hashref) {
		$base_ref = thread_details($base_ref->{id});
		push @$array_threads, $base_ref->{response};
	}

	$result->{response} = $array_threads;
	return $result;
}

sub thread_list_posts {
	my $thread_id = shift;
	my $optional = shift || {};

	my $count = 0;
	my $base_ref = {};
	my $array_posts = [];
	my $result = {code => 4, response => {}};
	my $query_string = "select id from post where thread_id = $thread_id";

	if(defined $optional->{since}) {
		$query_string .= " and date >= '$optional->{since}'";
	}

	$query_string .= " order by date $optional->{order}";

	if(defined $optional->{limit}) {
		$query_string .= " limit $optional->{limit}";
	}

	$query_string .= ";";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@)
	{
		return $result;
	}

	$result->{code} = 0;

	while($base_ref = $query->fetchrow_hashref) {
		$base_ref = post_details($base_ref->{id});
		push @$array_posts, $base_ref->{response};
	}

	$result->{response} = $array_posts;
	return $result;
}

sub thread_remove {
	my $id = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "select is_deleted, posts from thread where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	my ($is_del, $posts) = $query->fetchrow_array;
	$query->finish;

	if($is_del == 0 || $posts > 0) {
		$query_string = "update thread set is_deleted = 1, posts = 0 where id = $id;";

		$query = $dbh->prepare($query_string);
		eval {
			$res = $query->execute;
		};
		if($@) {
			return $result;
		}

		$query_string = "update post set is_deleted = 1 where thread_id = $id;";

		$query = $dbh->prepare($query_string);
		eval {
			$res = $query->execute;
		};
		if($@) {
			return $result;
		}
	}

	$result->{code} = 0;
	$result->{response} = { post => $id };
	$query->finish;

	return $result;
}

sub thread_restore {
	my $id = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "select is_deleted from thread where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	my ($is_del) = $query->fetchrow_array;
	$query->finish;

	if($is_del == 1) {
		$query_string = "select count(*) from post where thread_id = $id;";

		$query = $dbh->prepare($query_string);
		eval {
			$res = $query->execute;
		};
		if($@) {
			return $result;
		}

		my ($count) = $query->fetchrow_array;

		$query_string = "update thread set is_deleted = 0, posts = $count where id = $id;";

		$query = $dbh->prepare($query_string);
		eval {
			$res = $query->execute;
		};
		if($@) {
			return $result;
		}

		$query_string = "update post set is_deleted = 0 where thread_id = $id;";

		$query = $dbh->prepare($query_string);
		eval {
			$res = $query->execute;
		};
		if($@) {
			return $result;
		}
	}

	$result->{code} = 0;
	$result->{response} = { post => $id };
	$query->finish;

	return $result;
}

sub thread_close {
	my $id = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "update thread set is_closed = 1 where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	$result->{code} = 0;
	$result->{response} = { post => $id };


	return $result;
}

sub thread_open {
	my $id = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "update thread set is_closed = 0 where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	$result->{code} = 0;
	$result->{response} = { post => $id };


	return $result;
}

sub thread_update {
	my $id = shift;
	my $message = shift;
	my $slug = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "update thread set message = '$message', slug = '$slug' where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	$result = thread_details($id);
	$query->finish;

	return $result;
}

sub thread_vote { # id, vote
	my $id = shift;
	my $vote = shift;
	my $result = {code => 4, response => {}};
	my $entity = "likes";

	if($vote == -1) {
		$entity = "dislikes";
	}

	my $query_string = "update thread set $entity = $entity + 1 where id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}

	$result = thread_details($id);
	$query->finish;

	return $result;
}

sub thread_subscribe { # id, user
	my $id = shift;
	my $user = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "insert into subscription(user, thread_id) "
						."values('$user', $id);";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}
	$query->finish;

	$result->{response} = { thread => $id, user => $user };

	return $result;
}

sub thread_unsubscribe { # id, user
	my $id = shift;
	my $user = shift;
	my $result = {code => 4, response => {}};

	my $query_string = "delete from subscription "
						."where user = '$user' and thread_id = $id;";

	my $query = $dbh->prepare($query_string);
	eval {
		$res = $query->execute;
	};
	if($@) {
		return $result;
	}
	$query->finish;

	$result->{response} = { thread => $id, user => $user };

	return $result;
}

######### /THREAD FUNC #########
1;

END
{
	$dbh->disconnect;
}
