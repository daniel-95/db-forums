#!usr/bin/perl
package TechDBApi;
use Mojo::JSON qw(encode_json);
use DBI;

BEGIN
{
	use Exporter ();
	@ISA = qw(Exporter);
	@EXPORT = qw(&status &clear &mysql_connect &create_user &create_forum &user_details);
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

	$result->{code} = 0;
	$result->{response} = $data_ref;

	return encode_json($result);
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
	return encode_json($result);
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
	$code = 0;

	my $email = shift;
	my $query = $dbh->prepare("select email, about, isAnonymous, id, name, username FROM user WHERE email = '$email';");
	$res = $query->execute;
	$response = $query->fetchrow_hashref;
	$query->finish;

	$result->{response} = $response;
	$result->{code} = 0;

	return encode_json($result);
}

sub user_follow
{

}

sub user_unfollow
{

}

sub user_list_followers
{

}

sub user_list_following
{

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
