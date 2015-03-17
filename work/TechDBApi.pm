#!usr/bin/perl
package TechDBApi;
use DBI;

BEGIN
{
	use Exporter ();
	@ISA = qw(Exporter);
	@EXPORT = qw(&create_post);

	my $database = "db_forums";
	my $user = "root";
	my $password = "PwD73HDa";

	$dbh = DBI->connect("DBI:mysql:$database", $user, $password);
}

sub create_post 
{
	$query = $dbh->prepare("select count(*) from forum;");
	$query->execute;
	my $result = "";

	while(my @data = $query->fetchrow_array)
	{
		$result .= join(", ", @data);
	}

	$query->finish;
	return $result;
}

1;

END
{
	$dbh->disconnect;
}
