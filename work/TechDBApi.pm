#!usr/bin/perl
package TechDBApi;
use DBI;

BEGIN
{
	use Exporter ();
	@ISA = qw(Exporter);
	@EXPORT = qw(&status &clear &mysql_connect &create_user &create_forum &user_details &user_list_follow &get_id_by_email);
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

	$dbh = DBI->connect("DBI:mysql:$database", $user, $password);
}

sub status 
{
	@tables = qw(user forum thread post);
	my $result = {code => "", response => ""};
	my $response = {};
	my $k, $v;

	foreach(@tables)
	{
		my $query = $dbh->prepare("SELECT count(*) from $_;");
		$res = $query->execute;
		my @data = $query->fetchrow_array;
		$data_ref->{$_} = $data[0];
	}
	$query->finish;

	$result->{code} = 0;
	$result->{response} = $data_ref;

	$result;
}

sub clear
{
	my $result = {code => "", response => ""};
	my $response = {};
	$code = 0;
	my @tables = qw(user forum thread post subscription follow);

	$dbh->do("SET session foreign_key_checks = 0;");

	foreach(@tables)
	{
		my $query = $dbh->prepare("TRUNCATE TABLE `".$_."`;");
		$res = $query->execute;
		print $_.": ".$res."\n";
		$query->finish;

		if($res != "0E0")
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

######### /COMMON FUNC ##########

########## USER FUNC ##########

sub create_user # username, email, about = '', name = '',  is_anon = 0
{
	my $username = shift;
	my $email = shift;

	my $about = shift || '';
	my $name = shift || '';
	my $is_anon = shift || 0;

	return 3 unless ($username and $email);

	my $query = $dbh->prepare("INSERT INTO `user`(`username`, `email`, `about`, `name`, `isAnonymous`) VALUES('$username', '$email', '$about', '$name', $is_anon);");
	my $res = $query->execute;

	return 4 if ($res != 1);

	$query->finish;
	return 0;
}

sub user_details
{
	my $result = {code => "", response => ""};
	my $response = {};
	my $followee_ref = [];
	my $following_ref = [];
	my $subscr_ref = [];
	$code = 0;

	#main info
	my $email = shift;
	my $query = $dbh->prepare("select email, about, isAnonymous, id, name, username FROM user WHERE email = '$email';");
	$res = $query->execute;
	$response = $query->fetchrow_hashref;
	$query->finish;

	my $user_id = get_id_by_email($email);

	#followers
	my $query = $dbh->prepare("SELECT follower_id FROM follow WHERE followee_id = $user_id;");
	$res = $query->execute;

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

sub create_forum # name, short_name, user_id
{
	my $name = shift;
	my $short_name = shift;
	my $user_id = shift;

	return 3 unless ($name and $short_name and $user_id);

	my $query = $dbh->prepare("INSERT INTO `forum`(`name`, `short_name`, `user_id`) VALUES('$name', '$short_name', $user_id);");
	my $res = $query->execute;

	return 4 if ($res != 1);

	$query->finish;
	return 0;
}

######### /FORUM FUNC ##########

1;

END
{
	$dbh->disconnect;
}
