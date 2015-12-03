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
sub getPMTB;
sub getInitialVoltages;
sub getGains;
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };
sub calcDateTime{
  my @abbr = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my @days = qw(Sun Mon Tue Wed Thu Fri Sat);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  $year = 1900+$year;
  my $Date = "$days[$wday] $abbr[$mon] $mday $year";
  my $Time = sprintf("%02d:%02d:%02d",$hour,$min,$sec);
  return "$Date $Time";
}


my $database        = "JInventory";
my $hostname        = "halldweb1";
my $dbh;
my $sth;
my $nrow;
my $checker;
my $sql_cmd;
my @row;

#  connect to database
print "$database:$hostname\n";
($dbh = DBI->connect("DBI:mysql:$database:$hostname;mysql_read_default_file=./.my.cnf",undef,undef)) or die "Failed to connect to MySQL database\n";

my $initial_voltages_file = "CommissioningVoltages.snap";
my $gains_file = "mode7_gains.txt";
my $username = "manlara (Manuel Lara)";
my $out_file_name = "newVoltages.snap";

# create new BURT file
# seed the top of new file with the header information in headerBURT.txt
open OUTPUT, ">$out_file_name";
open HEADER_FILE, "headerBURT.txt" or die $!;
while (my $line = <HEADER_FILE>) {
  if ($line =~ /{user}/){
    $line =~ s/{user}/$username/;
  }
  if ($line =~ /{time}/){ 
    my $datetime = calcDateTime();
    $line =~ s/{datetime}/$datetime/;
  }
  print $line;
  print OUTPUT $line;
}

my %pmtB = getPMTB();
my %initV = getInitialVoltages($initial_voltages_file);
my %gains = getGains($gains_file);

my $size_V = keys %initV;
my $size_G = keys %gains;

print "Size of voltage file: $size_V\nSize of gain file: $size_G\n";
if ($size_V != $size_G){
  print "Why do the initial voltage and gains files have unequal number of channels??\nWon't continue\n"
} else{
  # loop through initial voltage hash and get the new voltage
  while (my ($key, $value)=each(%initV)){
    my $initialVoltage = $value;
    my $gain = $gains{$key};
    my $pmtB = $pmtB{$key};
    my $finalVoltage = 0;
    if ($pmtB eq "0") {$finalVoltage = $initialVoltage;}
    if ($gain < 0) {$finalVoltage = $initialVoltage;}
    else{
      $finalVoltage = $initialVoltage * $gain**(1/$pmtB);
    }
    print "Init Voltage: $initialVoltage, gain: $gain, B: $pmtB, Fini Voltage: $finalVoltage\n";
    my $xy = $key;
    $xy =~ s/_/:/g; # convert X_Y to X:Y
    print OUTPUT "FCAL:hv:$xy:v0set 1 $finalVoltage\n"
  }
}

# close file
close OUTPUT;

sub getInitialVoltages{
  my %pmt_cell_voltages;
  open InitVoltages_FILE, "$_[0]" or die $!;
  while (my $line = <InitVoltages_FILE>){
    chomp $line;
    next if $line =~ /^\s*$/;
    next if $line =~ /^---/;
    my @data = split(/\s+/, $line);
    next if $data[0] !~ /FCAL/;
    
    my @channel = split(":", $data[0]);
    my $xy = join("_", $channel[2], $channel[3]);
    $pmt_cell_voltages{$xy} = $data[2];
    #print "$xy, $data[2]\n";
  }
  return %pmt_cell_voltages;
}

sub getGains{
  my %pmt_cell_gains;
  open Gains_FILE, "$_[0]" or die $!;
  while (my $line = <Gains_FILE>){
    chomp $line;
    next if $line =~ /^\s*$/;
    my @data = split(/\s+/, $line);
    
    my $xy = join("_", $data[0], $data[1]);
    $pmt_cell_gains{$xy} = $data[2];
    #print "$xy, $data[2]\n";
  }
  return %pmt_cell_gains;
}

sub getPMTB{
  $sql_cmd = "SELECT a.ITM_PropertyTag, b.ITM_History FROM Item a, Item b WHERE a.ITM_ID=b.ITM_HousingParent AND b.ITM_Description='FCAL PMT' AND a.ITM_Description='The (x,y) coordinate of the FCAL base-PMT-lead glass module'";
  print "$sql_cmd\n";
  
  ($sth=$dbh->prepare($sql_cmd)) || die "Can't prepare $sql_cmd: $dbh->errstr\n";
  ($sth->execute)                || die "Can't execute the query: $sth->errstr\n";
  
  my %pmt_cell_B;
  
  $nrow = $sth->rows();
  my @fields;
  print "There are $nrow rows\n";
  for (my $i=0; $i<$nrow; $i++){
    my @record = $sth->fetchrow_array();
    my $itm_cell = $record[0] || ""; # FCAL_05_29
    my $itm_history = $record[1] || "";
    chomp $itm_cell; chomp $itm_history;
    $itm_cell =~ s/FCAL_//g;# get X_Y
    my @itm_xy = split("_",$itm_cell);
    my $itm_x = int($itm_xy[0]);
    my $itm_y = int($itm_xy[1]);
    my $xy = join("_", $itm_x, $itm_y);
    
    # Get PMT_B from the history field
    my $itm_B = "0";
    for my $item ($itm_history =~ /#>.+/g){
      my ($pmt, $val) = split ":", $item;
      chomp $pmt; chomp $val;
      if ($pmt =~ /PMT_B/){
        $itm_B = $val;
      }
    }
    
    $itm_cell = trim($itm_cell);
    $itm_B = trim($itm_B);
    $pmt_cell_B{$xy} = $itm_B;
    #print "Cell: $xy, B: $pmt_cell_B{$xy}\n";
  }
  return %pmt_cell_B;
}