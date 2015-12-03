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
sub checkDB;
sub getPMTs;
sub getData;
sub updateDB;
sub getOriginalInfo;
sub updateGains;
sub getA;
sub getB;
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

#my $database        = "SP_JInventory";
my $database        = "JInventory";
my $hostname        = "halldweb1";
my $dbh;
my $sth;
my $nrow;
my $checker;
my $sql_cmd;
my @row;

#  init common
#require "init_csv2db.pl";


#  decode command line args
if ($#ARGV != 0) {
    die "\n Usage:  fcal2db.pl  tab_file\n \"tab_file\" - tab file converted from FileMaker Pro\n\n";
}
my $tab_file = $ARGV[0];


#  connect to database
print "$database:$hostname\n";
($dbh = DBI->connect("DBI:mysql:$database:$hostname;mysql_read_default_file=./.my.cnf",undef,undef)) or die "Failed to connect to MySQL database\n";


#  open TAB_FILE
open TAB_FILE, "$tab_file" or die $!;

# key: F_PmtID, value: original info about PMT
my %pmt_db_original = getOriginalInfo();
#getHousings(1689);

# key: F_PmtID
my %pmt_data_hashmap = getData();
while (my ($key, $value)=each(%pmt_data_hashmap)){
  #print "ID: $key, History: $value\n";
}

# key: F_PmtID
# Loop over PMTs in JInventory DB
# Any PMT not in the database but in the tab separated file will NOT be added
my %pmt_db_hashmap = getPMTs();
while (my ($key, $value)=each(%pmt_db_hashmap)){
  my $history = $value;
  my $history2 = $pmt_data_hashmap{$key} || "";
  
  if ($key eq "F_0153"){
    $history2 = $pmt_data_hashmap{"F_153"} || "";
  }
  
  if ($history =~ /#### PMT Gain Constants ####/){ # update A and B coeficients if they have already been defined
    print "Updating...\n";
    my $pmtA = trim(getA($history2));
    my $pmtB = trim(getB($history2));
    if ($pmtA eq "0" || $pmtB eq "0"){
      print "Could not extract pmt gains...$key: $history2\n";
    } else{
      $history = updateGains($history, $pmtA, $pmtB);
      #print "$history\n";
    }
  }
  elsif ($history eq "") {$history = $history2;}
  elsif ($history2 ne "") {$history = "$history\n$history2";}
  
  my $original_history = $pmt_db_original{$key};
  #print "$original_history\n";
  if ($original_history ne "") {$history = "$original_history\n$history";}
  
  $history = "$history\n";
  print "$history";
  $checker = checkDB("SELECT ITM_PropertyTag FROM Item WHERE ITM_PropertyTag='$key'");
  if ($checker eq "Failed"){
    print "Failed!! Could not find...\n";
  }
  else{
    updateDB("Update Item Set ITM_History='$history' WHERE ITM_PropertyTag='$key'");
  }
  if ($key eq "F_0153"){
    #updateDB("Update Item Set ITM_History='$history' WHERE ITM_PropertyTag='$key'");
    #print "yo man\n$key, history: $history\nhistory2: $history2";
  }
}


sub getA{
  my $string = $_[0];
  for my $item ($string =~ /#>.+/g){
    my ($pmt, $val) = split ":", $item;
    $pmt = trim($pmt);
    $val = trim($val);
    if ($pmt =~ /PMT_A/){return $val;}
  }
  return "0";
}

sub getB{
  my $string = $_[0];
  for my $item ($string =~ /#>.+/g){
    my ($pmt, $val) = split ":", $item;
    $pmt = trim($pmt);
    $val = trim($val);
    if ($pmt =~ /PMT_B/){return $val;}
  }
  return "0";
}

# parse through history field for A and B and update
sub updateGains{
  my $string = $_[0];
  my $new_pmtA = "#> PMT_A: $_[1]";
  my $new_pmtB = "#> PMT_B: $_[2]";
  my $old_pmtA;
  my $old_pmtB;
  
  if ($string =~ /#### PMT Gain Constants ####/){
    
    for my $item ($string =~ /#>.+/g){
      my ($pmt, $val) = split ":", $item;
      $pmt = trim($pmt);
      $val = trim($val);
      if ($pmt =~ /PMT_A/){$old_pmtA = "$pmt: $val";}
      if ($pmt =~ /PMT_B/){$old_pmtB = "$pmt: $val";}
    }
    # search and replace PMT_A and PMT_B
    $string =~ s/$old_pmtA/$new_pmtA/;
    $string =~ s/$old_pmtB/$new_pmtB/;
    
  }
  return $string;
}

# TAB_FILE must be in the following format
# PmtID A B
sub getData{
  my %pmt_data_hashmap;
  while (my $line = <TAB_FILE>) {
    chomp $line;
    next if $line =~ /^\s*$/;
    my @data = split(/\s+/, $line);
    # value: #### PMT Gain Constants ####
    # ===== 2015-11-29 12:25:45 added by manlara =====
    # #> PMT_A: A
    # #> PMT_B: B
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    $year = 1900+$year;
    $mon = $mon+1;
    my $Date = sprintf("%02d-%02d-%02d",$year,$mon,$mday);
    my $Time = sprintf("%02d:%02d:%02d",$hour,$min,$sec);
    chomp $data[0];
    #my $pmtid = sprintf("%04d", $data[0]);
    my $pmtid = trim($data[0]);
    chomp $data[1];
    chomp $data[2];
    my $pmt_info = "#### PMT Gain Constants ####\n===== $Date $Time added by manlara =====\n#> PMT_A: $data[1]\n#> PMT_B: $data[2]";
    $pmt_data_hashmap{"F_$pmtid"} = "$pmt_info";
  }
  return %pmt_data_hashmap;
}

# Get all PMTs from DB
sub getPMTs{ 
  my %pmt_id_history;
  $sql_cmd = "SELECT ITM_PropertyTag, ITM_History FROM Item WHERE ITM_Description='FCAL PMT'";
  print "$sql_cmd\n";
  ($sth=$dbh->prepare($sql_cmd)) || die "Can't prepare $sql_cmd: $dbh->errstr\n";
  ($sth->execute)                || die "Can't execute the query: $sth->errstr\n";
  $nrow = $sth->rows();
  my @fields;
  print "There are $nrow rows\n";
  for (my $i=0; $i<$nrow; $i++){
    my @record = $sth->fetchrow_array();
    my $itm_id = $record[0] || "";
    my $itm_history = $record[1] || "";
    chomp $itm_id;
    chomp $itm_history;
    $pmt_id_history{$itm_id} = $itm_history;
    #print "ID: $itm_id, History: $itm_history\n";
  }
  return %pmt_id_history;
}

# key: PmtID
# value: string of original information needed to be prepended to gains
sub getOriginalInfo{
  # ----- Original Information -----
  # > Property Tag: F_0153
  # > Short Name: FCAL Pmt 0153
  # > Description: FCAL PMT
  # > Brand-Format-Model: IU-FEU-PMT-84-3
  # > Housing Parent: | Hall-D Counting House (3)
  # > Custodian: Adesh Subedi
  # > Replacer: Manuel Lara
  # > OnSite Eval: Adesh Subedi
  # > OffSite Repair: IU
  # > State: Normal
  # > Status: Operational
  # > Inserted Date: 2015-09-29 14:04:59
  my %pmt_id_original;
  
  $sql_cmd = "SELECT ITM_PropertyTag, ITM_ShortName, ITM_Description, ITM_HousingParent, ITM_InsertDate FROM Item WHERE ITM_Description='FCAL PMT'";
  
  print "$sql_cmd\n";
  ($sth=$dbh->prepare($sql_cmd)) || die "Can't prepare $sql_cmd: $dbh->errstr\n";
  ($sth->execute)                || die "Can't execute the query: $sth->errstr\n";
  $nrow = $sth->rows();
  print "There are $nrow rows\n";
  for (my $i=0; $i<$nrow; $i++){
    my @record = $sth->fetchrow_array();
    my $itm_property_tag = $record[0] || "";
    my $itm_short_name = $record[1] || "";
    my $itm_description = $record[2] || "";
    my $itm_housing_parent_id = $record[3] || "";
    my $itm_housing_parent = getHousings($itm_housing_parent_id);
    my $itm_insert_date = $record[4] || "";
    
    chomp $itm_property_tag;
    my $itm_original = "----- Original Information -----\n> Property Tag: $itm_property_tag\n> Short Name: $itm_short_name\n> Description: $itm_description\n> Brand-Format-Model: IU-FEU-PMT-84-3\n> Housing Parent: | $itm_housing_parent\n> Custodian: Adesh Subedi\n> Replacer: Manuel Lara\n> OnSite Eval: Adesh Subedi\n> OffSite Repair: IU\n> State: Normal\n> Status: Operational\n> Inserted Date: $itm_insert_date";
    $pmt_id_original{$itm_property_tag} = $itm_original;
    #print "ID: $itm_property_tag, History: $itm_original\n";
  }
  return %pmt_id_original;
}

# Get all housing
sub getHousings{
  my $cellid = $_[0];
  my $m_sql_cmd = "SELECT ParentID, level FROM HousingClosure WHERE ID=$cellid";
  #print "$m_sql_cmd\n";
  
  my $m_sth;
  ($m_sth=$dbh->prepare($m_sql_cmd)) || die "Can't prepare $m_sql_cmd: $dbh->errstr\n";
  ($m_sth->execute)                || die "Can't execute the query: $m_sth->errstr\n";
  my $m_nrow = $m_sth->rows();
  #print "There are $m_nrow rows\n";
  my $location = "";
  for (my $i=0; $i<$m_nrow; $i++){
    my @record = $m_sth->fetchrow_array();
    my $housing_parentid = $record[0] || "";
    my $housing_level = $record[1] || "";
    my $result = checkDB("SELECT ITM_ShortName FROM Item WHERE ITM_ID=$housing_parentid");
    $location .= "$result";
    if ($i != $m_nrow-1) {$location .= " > ";}
  }
  #print "$location\n";
  return $location;
}

# The following subroutine will check if an item exists
# Arguments = sql query as a string
# Return = id of item
sub checkDB{
  my $m_sql_cmd = $_[0];
  #print "$m_sql_cmd\n";
  
  my $m_sth;
  ($m_sth=$dbh->prepare($m_sql_cmd)) || die "Can't prepare $m_sql_cmd: $dbh->errstr\n";
  ($m_sth->execute)                || die "Can't execute the query: $m_sth->errstr\n";
  my $m_nrow = $m_sth->rows();
  if ($m_nrow>0){
    my @m_row = $m_sth->fetchrow_array;
    #print "ID: $m_row[0]\n";
    return "$m_row[0]"; # need to find and use what's already stored in db or create one
  }
  print "Not in DB\n";
  return "Failed";
}

# Update DB
sub updateDB{
  #$sql_cmd = "Update Item Set ITM_History='' WHERE ITM_PropertyTag=''";
  $sql_cmd = $_[0];
  print "$sql_cmd\n";
  
  ($sth=$dbh->prepare($sql_cmd)) || die "Can't prepare $sql_cmd: $dbh->errstr\n";
  ($sth->execute)                || die "Can't execute the query: $sth->errstr\n";
}

