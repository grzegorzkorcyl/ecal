#!/usr/bin/perl
###########################################
# Script file to run the flow
#
###########################################
#
# Command line for synplify_pro
#


use Data::Dumper;

use warnings;
use strict;

my $lattice_path = '/d/sugar/lattice/ispLEVER8.0/isptools/';
#my $synplify_path = '/d/sugar/lattice/synplify/syn96L3/synplify_linux/';
my $synplify_path = '/d/sugar/lattice/synplify/fpga_c200906sp1';

use FileHandle;

$ENV{'SYNPLIFY'}=$synplify_path;
$ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
$ENV{'LM_LICENSE_FILE'}="27000\@localhost";


my $TOPNAME="shower_fpga3";

my $FAMILYNAME="LATTICEECP2M";
my $DEVICENAME="LFE2M50E";
my $PACKAGE="FPBGA900";
my $SPEEDGRADE="5";

#create full lpf file
system("cp ../trbnet/pinout/$TOPNAME.lpf workdir/$TOPNAME.lpf");
system("cat constraints_$TOPNAME.lpf >> workdir/$TOPNAME.lpf");

#set -e
#set -o errexit

#generate timestamp
my $t=time;
my $fh = new FileHandle(">version.vhd");
die "could not open file" if (! defined $fh);
print $fh <<EOF;

--## attention, automatically generated. Don't change by hand.
library ieee;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_ARITH.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;
use ieee.numeric_std.all;

package version is

    constant VERSION_NUMBER_TIME  : integer   := $t;

end package version;
EOF
$fh->close;

system("env| grep LM_");
my $r = "";
#my $c=$synplify_path."synplify_pro_oem -batch $TOPNAME".".prj";
#my $c="$synplify_path/bin/synplify_pro -Pro -prj $TOPNAME".".prj";
my $c="$synplify_path/bin/synplify_premier_dp -batch $TOPNAME".".prj";
#my $c="$synplify_path/bin/synpwrap -Pro -prj $TOPNAME".".prj";
$r=execute($c, "do_not_exit" );


chdir "workdir";
my $fh = new FileHandle("<$TOPNAME".".srr");
my @a = <$fh>;
$fh -> close;

#if ($r) {
#$c="cat  $TOPNAME.srr";
#system($c);
#exit 129;
#}

foreach (@a)
{
    if(/\@E:/)
    {
	$c="cat  $TOPNAME.srr";
	system($c);
        print "bdabdhsadbhjasdhasldhbas";
	exit 129;
    }
}
#if (0){

$ENV{'LM_LICENSE_FILE'}="1710\@cronos.e12.physik.tu-muenchen.de";

$c=qq| $lattice_path/ispfpga/bin/lin/edif2ngd  -l $FAMILYNAME -d $DEVICENAME "$TOPNAME.edf" "$TOPNAME.ngo" |;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/edfupdate   -t "$TOPNAME.tcy" -w "$TOPNAME.ngo" -m "$TOPNAME.ngo" "$TOPNAME.ngx"|;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/ngdbuild  -a $FAMILYNAME -d $DEVICENAME -p "$lattice_path/ispfpga/or5s00/data" -dt "$TOPNAME.ngo" "$TOPNAME.ngd"|;
execute($c);

my $tpmap = $TOPNAME . "_map" ;

$c=qq|$lattice_path/ispfpga/bin/lin/map  -retime -split_node -a $FAMILYNAME -p $DEVICENAME -t $PACKAGE -s $SPEEDGRADE "$TOPNAME.ngd" -o "$tpmap.ncd"  -mp "$TOPNAME.mrp" "$TOPNAME.lpf"|;
execute($c);


system("rm $TOPNAME.ncd");

#$c=qq|$lattice_path/ispfpga/bin/lin/par -w -y -l 4 -i 15 "$tpmap.ncd" "$TOPNAME.ncd" "$TOPNAME.prf" |;
#$c=qq|$lattice_path/ispfpga/bin/lin/par -f $TOPNAME.p2t  "$tpmap.ncd" "$TOPNAME.ncd" "$TOPNAME.prf" |;
$c=qq|$lattice_path/ispfpga/bin/lin/multipar -pr "$TOPNAME.prf" -o "mpar_$TOPNAME.rpt" -log "mpar_$TOPNAME.log" -p "$TOPNAME.p2t"  "$tpmap.ncd" "$TOPNAME.ncd"|;
execute($c);

# IOR IO Timing Report
#$c=qq|$lattice_path/ispfpga/bin/lin/iotiming -s "$TOPNAME.ncd" "$TOPNAME.prf"|;
#execute($c);

# TWR Timing Report
#$c=qq|$lattice_path/ispfpga/bin/lin/tg "$TOPNAME.ncd" "$TOPNAME.prf"|;
$c=qq|$lattice_path/ispfpga/bin/lin/trce -c -v 15 -o "$TOPNAME.twr.setup" "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/trce -hld -c -v 5 -o "$TOPNAME.twr.hold"  "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);


$c=qq|$lattice_path/ispfpga/bin/lin/bitgen  -w "$TOPNAME.ncd" -f "$TOPNAME.t2b" "$TOPNAME.prf"|;
execute($c);

chdir "..";


# $c=("$lattice_path/ispvmsystem/ispvm -infile $TOPNAME".".xcf -outfiletype -svf");
# execute($c);
# $c=("perl -i  -ne 'print unless(/^!/)' $TOPNAME".".svf");
# execute($c);
#$c=("impact -batch impact_batch.txt");
#execute($c);

#$c=("scp hub_chain.stapl hadaq\@hadeb05:/var/diskless/etrax_fs/");
#execute($c);

#}

#$c=("impact -batch impact_batch_hub.txt");

exit;

sub execute {
    my ($c, $op) = @_;
    #print "option: $op \n";
    $op = "" if(!$op);
    print "\n\ncommand to execute: $c \n";
    $r=system($c);
    if($r) {
	print "$!";
	if($op ne "do_not_exit") {
	    exit;
	}
    }

    return $r;

}
