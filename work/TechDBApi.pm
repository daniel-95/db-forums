#!usr/bin/perl
package TechDBApi;
use DBI;

BEGIN
{
	use Exporter ();
	@ISA = qw(Exporter);
	@EXPORT = qw(&check &clear &mysql_connect);
}

#db handler
$dbh = 0;

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

1;

END
{
	$dbh->disconnect;
}
