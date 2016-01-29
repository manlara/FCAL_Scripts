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

# Global xmax and ymax
# Hall coordinate system with (0,0) at the center of FCAL
my $XMAX = 29;
my $YMAX = 29;

# Subroutines
sub getHorizontalStripes1;
sub getHorizontalStripes2;
sub getVerticalStripes1;
sub getVerticalStripes2;
sub getCheckerPattern1;
sub getCheckerPattern2;
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
# takes two arguments: x and y
sub isFcalCell{
  my $x = $_[0];
  my $y = $_[1];
  my $offset_y = $y+$YMAX;
  if ($offset_y<0) {return 0};
  if ($offset_y>2*$YMAX) {return 0};
  
  my @edges = (7, 10, 13, 14, 16, 17, 19, 20, 21, 22,
   23, 23, 24, 25, 25, 26, 27, 27, 27, 28, 
   28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 
   29, 29, 29, 29, 29, 29, 29, 28, 28, 28, 
   27, 27, 27, 26, 25, 25, 24, 23, 23, 22,
   21, 20, 19, 17, 16, 14, 13, 10, 7);
   
  if (abs($x)>$edges[$offset_y]) {return 0};
  if (abs($x)<2 && abs($y)<2) {return 0};
  
  return 1;
}

# every odd row is turned on
sub isHorizontalStripes1{
  my $x = $_[0];
  my $y = $_[1];
  
  if ($y%2==1) {return 1;}
  return 0;
}

# every even row is turned on
sub isHorizontalStripes2{
  my $x = $_[0];
  my $y = $_[1];
  
  if ($y%2==0) {return 1;}
  return 0;
}

# every odd column is turned on
sub isVerticalStripes1{
  my $x = $_[0];
  my $y = $_[1];
  
  if ($x%2==1) {return 1;}
  return 0;
}

# every even column is turned on
sub isVerticalStripes2{
  my $x = $_[0];
  my $y = $_[1];
  
  if ($x%2==0) {return 1;}
  return 0;
}

# every odd row and odd column is turned on
sub isCheckerPattern1{
  my $x = $_[0];
  my $y = $_[1];
  
  if ($x%2==1 && $y%2==1) {return 1;}
  return 0;
}

# every even row and even column is turned on
sub isCheckerPattern2{
  my $x = $_[0];
  my $y = $_[1];
  
  if ($x%2==0 && $y%2==0) {return 1;}
  return 0;
}

my $username = "manlara (Manuel Lara)";

writePattern("horizontal1");
writePattern("horizontal2");

writePattern("vertical1");
writePattern("vertical2");

writePattern("checker1");
writePattern("checker2");

sub writePattern{
  my $pattern = $_[0];
  #my $out_file_name = "horizontal1.snap";
  my $out_file_name = "$pattern.snap";

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

  for (my $i=-$XMAX; $i<=$XMAX; $i++){
    for (my $j=-$YMAX; $j<=$YMAX; $j++){
      my $isCell = isFcalCell($i, $j);
      if ($isCell) {
        my $isPattern;
        
        if ($pattern =~ m/horizontal1/){
          $isPattern = isHorizontalStripes1($i, $j);
        }
        
        if ($pattern =~ m/horizontal2/){
          $isPattern = isHorizontalStripes2($i, $j);
        }
        
        if ($pattern =~ m/vertical1/){
          $isPattern = isVerticalStripes1($i, $j);
        }
        
        if ($pattern =~ m/vertical2/){
          $isPattern = isVerticalStripes2($i, $j);
        }
        
        if ($pattern =~ m/checker1/){
          $isPattern = isCheckerPattern1($i, $j);
        }
        
        if ($pattern =~ m/checker2/){
          $isPattern = isCheckerPattern2($i, $j);
        }
        
        if ($isPattern){
          #print "FCAL:hv:$i:$j:v0set 1 1500\n";
          print OUTPUT "FCAL:hv:$i:$j:v0set 1 1500\n";
        } else{
          #print "FCAL:hv:$i:$j:v0set 1 0\n";
          print OUTPUT "FCAL:hv:$i:$j:v0set 1 0\n";
        }
      }
    }
  }
}

