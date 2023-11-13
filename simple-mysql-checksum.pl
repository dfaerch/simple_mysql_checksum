#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use threads;
use Getopt::Long;
use Term::ReadKey;

#-- Handle command line options:

sub usage {
    my $text = shift;
    print "\n$text\n\n" and sleep 1 if $text;

    print "Usage: $0 hostA hostB [options] DatabaseName
Options:
    --user  mysql-username, with checksum privileges. Must be the same on both db-hosts
    --pass  Must be the same on both db-hosts

You need a mysql user & password, that will work on both hosts.
    CREATE USER 'checksum_user'\@'%' IDENTIFIED BY 'SuperSecretPassw0rt..';
    GRANT SELECT ON *.* TO 'checksum_user'\@'%';

To remove user when you're done:
    DROP USER 'checksum_user'\@'%';
\n";
    exit 1;
}

# Define defaults for optional parameters
my ($user, $password);

GetOptions(
    'user=s' => \$user,
    'pass=s' => \$password,
);

# Remaining arguments are hosts and the last one is the database
my $host_A = shift @ARGV;
my $host_B = shift @ARGV;
my $db     = pop @ARGV; # The last element should be the database

usage() unless $host_A && $host_B && $db;
usage("ERROR: host_A and B must be different!") if $host_A eq $host_B;

# Check for required parameters and prompt if necessary
unless ($user) {
    print "Enter username: ";
    $user = <STDIN>;
    chomp $user;
}

unless ($password) {
    print "Enter password: ";
    ReadMode('noecho'); # Do not echo input
    $password = ReadLine(0);
    chomp $password;
    ReadMode('restore'); # Restore typing mode
    print "\n";
}




#---




sub get_checksum {
    my ($host, $table) = @_;
    my $dsn = "DBI:mysql:database=$db;host=$host";
    my $dbh = DBI->connect($dsn, $user, $password, { RaiseError => 1, PrintError => 0, AutoCommit => 1 });

    my $sth = $dbh->prepare("CHECKSUM TABLE `$table`");
    $sth->execute();
    my $result = $sth->fetchrow_arrayref();
    $sth->finish();
    $dbh->disconnect();

    return $result->[1]; # return the checksum value
}

my $dsn = "DBI:mysql:database=$db;host=$host_A";
my $dbh = DBI->connect($dsn, $user, $password, { RaiseError => 1, PrintError => 0, AutoCommit => 1 });

my $sth = $dbh->prepare("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=?");
$sth->execute($db);

my $fail_count = 0;
my $count = 0;
while (my $ref = $sth->fetchrow_hashref()) {
    my $table = $ref->{'TABLE_NAME'};
    $count++;

    # Start checksum for both hosts in parallel
    my $thr_a = threads->create(\&get_checksum, $host_A, $table);
    my $thr_b = threads->create(\&get_checksum, $host_B, $table);

    # Get both results
    my $checksum_a = $thr_a->join();
    my $checksum_b = $thr_b->join();

    # Compare checksums
    if (defined $checksum_a && defined $checksum_b && $checksum_a eq $checksum_b) {
        print "OK  : $table ($checksum_a vs $checksum_b)\n";
    } elsif (!defined $checksum_a && !defined $checksum_b) {
        print "OK  : $table - Both were NULL\n";
    } else {
        print "FAIL: $table - Checksums do NOT match. A: $checksum_a, B: $checksum_b\n";
        $fail_count++;
    }
}

$sth->finish();
$dbh->disconnect();

print "\n$fail_count of $count tables are out of sync\n" if ($fail_count);

my $exit_code = ($fail_count) ? 2 : 0;
exit $exit_code;
