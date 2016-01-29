#!/usr/bin/perl -w
#
# This script will upload PMT gain constants to the JInventory DB
#
# The input file is a tab separated list of PMT_ID PMT_A PMT_B
# Run the script like this
#  ./csv2db.pl pmt_data.tab
#
#
#  SP, 06-Jun-2013

use strict;
use warnings;

use DBI;
use Env;

# Subroutines
sub getBases;


my $database        = "JInventory";
my $hostname        = "halldweb1";
my $dbh;
my $sth;
my $nrow;
my $checker;
my $sql_cmd;
my @row;

my $out_file_name = "BaseInfo.txt";

#  connect to database
print "$database:$hostname\n";
($dbh = DBI->connect("DBI:mysql:$database:$hostname;mysql_read_default_file=./.my.cnf",undef,undef)) or die "Failed to connect to MySQL database\n";


open OUTPUT, ">$out_file_name";



sub getBasesAndPmts{
  
}