#!/usr/bin/env perl
use strict;
use warnings;

use lib './mojo/lib';
use Mojo::Template;
use DBI;
use Env;

sub checkDB;

my $database        = "JInventory";
my $hostname        = "halldweb1";
my $dbh;
my $sth;
my $nrow;
my $sql_cmd;

#  init common
require "init_csv2db.pl";


#  connect to database
#print "$database:$hostname\n";
($dbh = DBI->connect("DBI:mysql:$database:$hostname;mysql_read_default_file=./.my.cnf",undef,undef)) or die "Failed to connect to MySQL database\n";

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };
sub  createHash {
  my %hash; 
  foreach (@_){
    #print "$_\n";
    my @key_val=split('=>',trim($_)); 
    #$hash{trim($key_val[0])} = trim($key_val[1]);
    $hash{$key_val[0]} = $key_val[1];
    #print "$key_val[0] and $key_val[1]\n";
  } 
  return %hash; 
};
sub checkDB{
  $sql_cmd = $_[0];
  #print "$sql_cmd\n";

  ($sth=$dbh->prepare($sql_cmd)) || die "Can't prepare $sql_cmd: $dbh->errstr\n";
  ($sth->execute)                || die "Can't execute the query: $sth->errstr\n";
  $nrow = $sth->rows();
  #print "rows: $nrow\n";
  my @_ids;
  if ($nrow>0){
    for (my $i=0; $i<$nrow; $i++){
      my @row = $sth->fetchrow_array;
      push (@_ids, $row[0]);
      #print "ID: $row[0]\n";
    }
    return @_ids;
  }
  #print "Not in DB\n";
  return @_ids;
}

sub convertHexToDec{
  my $num = $_[0];
  my $dec_num = sprintf("%d", hex($num));
  #print "$dec_num\n";
  return $dec_num;
}

# open the IU db file (Exported_FCAL_DB.tab) and get the base, can, and board id
# File is organized as follows:
# baseid x y canid pmtid A B
# my %IUdb;
# open TAB_FILE, "Exported_FCAL_DB.tab" or die "Exported_FCAL_DB.tab not found!!";
# while (<TAB_FILE>) {
#   #my $line = <TAB_FILE>;
#   #if ($line eq "") {next;}
#   #$line = trim($line);
#   my @data = split("\t");
#   $data[0] = trim($data[0]);
#   $data[1] = trim($data[1]);
#   $data[2] = trim($data[2]);
#   $data[3] = trim($data[3]);
#   $data[4] = trim($data[4]);
#   $IUdb{"F_$data[0]"} = "baseid";
#   my $x = $data[1];
#   my $y = $data[2];
#   $IUdb{"($x,$y)"} = "coordinate";
#   $IUdb{"$data[3]"} = "canid";
#   $IUdb{"F_$data[4]"} = "pmtid";
#   #print "IU DB: baseid: F_$data[0], coord: ($data[1],$data[2]), canid: F_$data[3], pmtid: F_$data[4]\n";
# }

my @edges = (7, 10, 13, 14, 16, 17, 19, 20, 21, 22, 23, 23, 24, 25, 25, 26, 27, 27, 27, 28, 28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 28, 28, 28, 27, 27, 27, 26, 25, 25, 24, 23, 23, 22, 21, 20, 19, 17, 16, 14, 13, 10, 7);
my @cell_children;
for my $row (0..58) {
  for my $col (-29..29) {
    my $x = $col;
    my $y = $row-29;
    if ($col>=-1*$edges[$row] and $col<=$edges[$row] and !(abs($row-29)<=1 and abs($col)<=1)){
      #print "($x,$y)\n";
      my $longx = "$x";
      my $longy = "$y";
      if (abs($x)<10 and $x>=0){ $longx = "0"."$x";}
      elsif (abs($x)<10 and $x<0){ my $tx = abs($x); $longx = "-0"."$tx";}
      if (abs($y)<10 and $y>=0){ $longy = "0"."$y";}
      elsif (abs($y)<10 and $y<0){ my $ty = abs($y); $longy = "-0"."$ty";}
      #print "longx: $longx, longy: $longy\n";
      my $cell_name = "FCAL_"."$longx"."_"."$longy";
      $sql_cmd = "SELECT c.ITM_PropertyTag FROM Item c, Item p WHERE c.ITM_HousingParent = p.ITM_ID and p.ITM_PropertyTag='$cell_name' ";
      my @ids = checkDB($sql_cmd);
      my $num_ids = scalar(@ids);


      my $pmtID; my $baseID; my $canID = "";
      my $t_length = length("$ids[0]");
      my $t_substr = substr("$ids[0]", 0, 3);
      #print "Length: $t_length, substring: $t_substr\n";
      if (length("$ids[0]")==7 and substr("$ids[0]", 0, 3)eq"F_2"){
        $baseID = $ids[0];
        $pmtID  = $ids[1];
      } else{
        $baseID = $ids[1];
        $pmtID  = $ids[0];
      }

      # $error_level=0 => base or pmt missing
      # $error_level=1 => boards in base are missing
      # $error_level=2 => all boards and canid found
      # $error_level=3 => can id is missing from comm board
      # $error_level=4 => board ids are missing for comm board
      # $error_level=5 => there are too many boards in base
      my $error_level = "";

      if ($num_ids==2){
        # query for the number of boards associated to a base
        $sql_cmd = "SELECT c.ITM_PropertyTag FROM Item c, Item p WHERE c.ITM_HousingParent = p.ITM_ID and p.ITM_PropertyTag='$baseID' ";
        my @board_ids = checkDB($sql_cmd);
        my $num_board_ids = scalar(@board_ids);


        my $commboardID = "";
        foreach (@board_ids){
          my $board_id = trim($_);
          my $t_length2 = length("$board_id");
          my $t_substr2 = substr("$board_id", 0, 3);
          #print "Length: $t_length2, substring: $t_substr2\n";
          if (length("$board_id")==7 and substr("$board_id", 0, 3)eq"F_3"){
            $commboardID = $_;
            #print "commboardID: $commboardID\n";
          }
          elsif (substr("$board_id", 0, 3)eq"F_U"){
            $error_level = "4";
          }
        }
        
        
        if ($num_board_ids!=4){
          $error_level = "1"; # boards in base are missing or there are too many
        } 
        elsif ($commboardID ne ""){
          $sql_cmd = "SELECT ITM_SerialNum FROM Item WHERE ITM_PropertyTag='$commboardID' ";
          my @can_ids = checkDB($sql_cmd);
          if (scalar(@can_ids)==0){
            $error_level = "3"; # no can id for comm board
          }
          else{
            $canID = $can_ids[0];
            $error_level = "2"; # all boards and canid found
          }
        }

        # check if the base, pmt, and can ids match up with IU db
        # if ($error_level eq "2"){
        #   #convert hex to decimal
        #   if ("$canID" =~ m/0x[0-9a-f]+/){
        #     $canID = convertHexToDec($canID);
        #   }
        #   if (!exists $IUdb{"$baseID"} or !exists $IUdb{"$pmtID"} or !exists $IUdb{"$canID"}){
        #     $error_level = "5"; # all boards and canid found BUT mismatch between IU and JInventory
        #   }
        # }

      } # end $num_ids==2
      else{
        $error_level = "0"; # number of first-level children of cell is not 2. A base or pmt is missing
      }
      #print "($x,$y)=>$error_level\n";
      push (@cell_children, "($x,$y)=>$error_level");
    }
  }
}


# turn arrays into a scalar
my $edges_str = join(",", @edges);
my $cell_children_str = join(";", @cell_children);
#print "Long: $cell_children_str\n";
#my $t_children_size = scalar(@cell_children);
#print "Size of list: $t_children_size\n";
#my @cell_children_arr = split(';',trim($cell_children_str));
#my $t_children_size2 = scalar(@cell_children_arr);
#print "Size of list2: $t_children_size2\n";
#my %h = createHash(@cell_children_arr);
#print "$_ $h{$_}\n" for (keys %h);

my $mt = Mojo::Template->new;


#print $mt->render_file( 'index.html', 'Title text', 'Header text' );
my $filename = 'fcalmain.html';
open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
print $fh $mt->render_file( 'fcal-main_template.html', 'FCAL', 'FCAL Looking Upstream', $edges_str, $cell_children_str );
close $fh;
print "done\n";