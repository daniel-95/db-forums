#!usr/bin/perl
package TechDBApi;
use DBI;

BEGIN
{
	use Exporter ();
	@ISA = qw(Exporter);
	@EXPORT = qw(&check &clear &mysql_connect &create_user &create_forum);
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

sub check 
{
	my $query = $dbh->prepare("select count(*) from user;");
	$query->execute;
	my $result = "";

	while(my @data = $query->fetchrow_array)
	{
		$result .= join(", ", @data);
	}

	$query->finish;
	return $result;
}

sub clear
{
	@tables = qw(user forum thread post subscription follow);
	$dbh->do("SET session foreign_key_checks = 0;");

	foreach(@tables)
	{
		my $query = $dbh->prepare("TRUNCATE TABLE `".$_."`;");
		$res = $query->execute;
		print $_.": ".$res."\n";
		$query->finish;

		if($res != "0E0")
		{
			$dbh->do("SET session foreign_key_checks = 1;");
			print $_." truncate: ".$dbh->strerr."\n";
			return 4; 
		}
	}

	$dbh->do("SET session foreign_key_checks = 1;");

	return 0;
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
