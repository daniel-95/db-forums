#!usr/bin/perl
package TechDBApi;
use DBI;

BEGIN
{
	use Exporter ();
	@ISA = qw(Exporter);
	@EXPORT = qw(&create_post);

	my $database = "djangodb";
	my $user = "djangouser";
	my $password = "djpasswd";

	$dbh = DBI->connect("DBI:mysql:$database", $user, $password);
}

sub create_post 
{
	$query = $dbh->prepare("select count(*) from ask_question;");
	$query->execute;
	my $result = "";

	while(my @data = $query->fetchrow_array)
	{
		$result .= join(", ", @data);
	}

	return $result;
}

1;

END {}
