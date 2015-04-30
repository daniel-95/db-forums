#!usr/bin/perl
package TechDBApi;
use DBI;
use utf8;

BEGIN
{
	use Exporter ();
	@ISA = qw(Exporter);
	@EXPORT = qw(&status &clear &mysql_connect &create_user &create_forum &user_details &user_list_follow &get_id_by_email &forum_details &create_thread &thread_details &create_post &post_details);
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
	my $following_ref = [];
	my $subscr_ref = [];

	#main info
	my $email = shift;
	my $query = $dbh->prepare("select email, about, isAnonymous, id, name, username FROM user WHERE email = '$email';");
	$res = $query->execute;
	$response = $query->fetchrow_hashref;
	$response->{isAnonymous} = $response->{isAnonymous} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	for(keys %$response)
	{
		$response->{$_} = undef if($response->{$_} eq "");
	}

	$response->{id} += 0;
	$query->finish;

	my $user_id = get_id_by_email($email);
	my $query = $dbh->prepare("SELECT follower_id FROM follow WHERE followee_id = $user_id;");

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

	while($fol_id = $query->fetchrow_array)
	{
		push @$follower_ref, get_email_by_id($fol_id); 
	}

	$query->finish;

	#followees
	my $query = $dbh->prepare("SELECT followee_id FROM follow WHERE follower_id = $user_id;");
	$res = $query->execute;

	while($fol_id = $query->fetchrow_array)
	{
		push @$followee_ref, get_email_by_id($fol_id); 
	}

	$query->finish;

	#subscriptions
	my $query = $dbh->prepare("SELECT thread_id FROM subscription WHERE user_id = $user_id;");
	$res = $query->execute;

	while($sub_id = $query->fetchrow_array)
	{
		push @$subscr_ref, $sub_id; 
	}

	$query->finish;

	$response->{followers} = $followee_ref;
	$response->{following} = $following_ref;
	$response->{subscriptions} = $subscr_ref;
	$result->{response} = $response;
	$result->{code} = 0;

	return $result;
}

sub user_follow
{
	my $user_id1 = shift;
	my $user_id2 = shift;

	my $email1 = get_email_by_id($user_id1);
	my $email2 = get_email_by_id($user_id2);

	$query = $dbh->prepare("INSERT INTO follow (follower_id, followee_id) VALUES ($user_id1, $user_id2);");
	$res = $query->execute;
	$query->finish;

	return user_details($email1);
}

sub user_unfollow
{
	my $user_id1 = shift;
	my $user_id2 = shift;

	my $email1 = get_email_by_id($user_id1);
	my $email2 = get_email_by_id($user_id2);

	$query = $dbh->prepare("DELETE FROM follow where follower_id = $user_id1 and followee_id = $user_id2;");
	$res = $query->execute;
	$query->finish;

	return user_details($email1);
}

sub user_list_follow #type = follower/followee, email, %params {since_id = undef, order = ASC/DESC, limit} 
{
	my $type = shift;
	my $email = shift;
	my $params = shift;
	my $result = {code => "", response => ""};
	my $id = get_id_by_email($email) || undef;
	my $ids = [];

	$params->{order} = "DESC" unless defined $params->{order};

	my $where = $type eq "follower" ? "followee" : "follower";

	my $query_str = "SELECT u.email from follow f JOIN user u on u.id = f.$type"."_id"." where $where"."_id"." = $id";

	$query_str .= " and $type"."_id >= $params->{since_id}" if defined $params->{since_id};
	$query_str .= " order by u.name $params->{order}";
	$query_str .= " LIMIT $params->{limit}" if defined $params->{limit};

	$query_str .= ";";

	my $query = $dbh->prepare($query_str);
	$res = $query->execute;

	while($fol_id = $query->fetchrow_array)
	{
		push @$ids, user_details($fol_id);
	}
	$result->{code} = 0;
	$result->{response} = $ids;

	return $result;
}

sub user_list_posts
{

}

sub user_update
{
	
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

	my $query = $dbh->prepare("select * from forum where short_name = '$short_name';");
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
	print "===debug output: ".$query_string."\n";
	my $query = $dbh->prepare($query_string);

	my $res = $query->execute;

	if ($res != 1)
	{
		$result->{code} = 4;
	}
	else
	{
		$result->{code} = 0;

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
		$response->{id} = get_id_by_entity("post") + 0;

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
	$query_string = "select * from post order by id DESC limit 1;" if($id == -1);

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
		$details_ref = thread_details($base_ref->{thread});
		$base_ref->{thread} = $details_ref->{response};
	}

	$base_ref->{isDeleted} = delete $base_ref->{is_deleted} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{isApproved} = delete $base_ref->{is_approved} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{isEdited} = delete $base_ref->{is_edited} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{isHighlighted} = delete $base_ref->{is_highlighted} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	$base_ref->{isSpam} = delete $base_ref->{is_spam} eq "0" ? Mojo::JSON->false : Mojo::JSON->true;
	
	$base_ref->{likes} += 0;
	$base_ref->{dislikes} += 0;
	$base_ref->{points} += 0;
	$base_ref->{parent} = delete $base_ref->{parent_id};
	$base_ref->{parent} += 0 if(defined $base_ref->{parent});
	$base_ref->{thread} = delete $base_ref->{thread_id};
	$base_ref->{thread} += 0;
	$base_ref->{id}  = $id + 0;

	$result->{code} = 0;
	$result->{response} = $base_ref;

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
	$query_string = "select * from thread order by id DESC limit 1;" if($id == -1);

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
  		! grep { $_ eq $t } ("forum", "user"); # важно: для строк использовать eq
	} @$related;

	if(scalar keys @rslt > 0) {
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
	$base_ref->{posts} += 0;
	$base_ref->{id}  = $id + 0;

	$result->{code} = 0;
	$result->{response} = $base_ref;

	return $result;
}

######### /THREAD FUNC #########
1;

END
{
	$dbh->disconnect;
}
