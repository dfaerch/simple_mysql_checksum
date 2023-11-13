# simple_mysql_checksum
A tool that checksums all tables of a database on two different database hosts, comparing them to verify if they are identical.

This tool serves as an alternative to `pt-table-checksum` for situations where `pt-table-checksum` is not viable, yet you need to ensure your replicated data is consistent.

**Important Note:**
During the run of this tool, if there are concurrent modifications (like write operations) on the master table, it might result in differing checksums on the hosts. If such discrepancies occur, rerun the tool. Consistent results in subsequent runs generally indicate that the replication is synchronized.
If the master database is consistently busy with write operations, this tool may not be suitable.

## Usage

    ./simple-mysql-checksum.pl host_A host_B [options] DatabaseName

Output is one line per table, and begins with its status (OK if checksums are equal):
 - OK  : table_name ...
 - FAIL: table_name - Checksums do NOT match ... 
 - FAIL: table_name - Both were NULL ...

The last one occurs if the tool didn't have permission to read. Note that this is not taken as a failure.

Exit code is:
 - 0 if all are OK.
 - 2 if there is at least one FAIL.

#### Example usage:
    ./simple-mysql-checksum.pl mysql-a.example.com mysql-b.example.com --user checksum_user wordpress

In this example, we omitted `--pass`, so the `simple-mysql-checksum` will ask for it.

### Options:
The following options are available for use with the tool:
- `--user`:  MySQL username with checksum privileges (must be identical on both hosts).
- `--pass`:  MySQL password (must be identical on both hosts).

`simple-mysql-checksum` will prompt you for either of these if they are not defined on the command line.

### Setup:
Ensure you have a MySQL user with the necessary permissions on both hosts:

    CREATE USER 'checksum_user'@'%' IDENTIFIED BY 'SuperSecretPassw0rt..';
    GRANT SELECT ON *.* TO 'checksum_user'@'%';

### Cleanup:
To remove the user after you're done:

    DROP USER 'checksum_user'@'%';
