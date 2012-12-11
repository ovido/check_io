#!/usr/bin/perl -w
# nagios: -epn

#######################################################
#                                                     #
#  Name:    check_io                                  #
#                                                     #
#  Version: 0.1                                       #
#  Created: 2012-12-13                                #
#  License: GPL - http://www.gnu.org/licenses         #
#  Copyright: (c)2012 ovido gmbh, http://www.ovido.at #
#  Author:  Rene Koch <r.koch@ovido.at>               #
#  Credits: s IT Solutions AT Spardat GmbH            #
#  URL: https://labs.ovido.at/monitoring              #
#                                                     #
#######################################################

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use Getopt::Long;

# Configuration


# create performance data
# 0 ... disabled
# 1 ... enabled
my $perfdata	= 1;

# Variables
my $prog	= "check_io";
my $version	= "0.1";
my $projecturl  = "https://labs.ovido.at/monitoring/wiki/check_io";

my $o_verbose	= undef;	# verbosity
my $o_help	= undef;	# help
my $o_version	= undef;	# version
my $o_runs	= 5;		# iostat runs
my $o_interval	= 1;		# iostat interval
my @o_exclude	= ();		# exclude disks
my $o_errors	= undef;	# error detection
my $o_max	= undef;	# get max values
my $o_average	= undef;	# get average values
my @o_warn	= ();		# warning
my @o_crit	= ();		# critical

my %status	= ( ok => "OK", warning => "WARNING", critical => "CRITICAL", unknown => "UNKNOWN");
my %ERRORS	= ( "OK" => 0, "WARNING" => 1, "CRITICAL" => 2, "UNKNOWN" => 3);

#***************************************************#
#  Function: parse_options                          #
#---------------------------------------------------#
#  parse command line parameters                    #
#                                                   #
#***************************************************#
sub parse_options(){
  Getopt::Long::Configure ("bundling");
  GetOptions(
	'v+'	=> \$o_verbose,		'verbose+'	=> \$o_verbose,
	'h'	=> \$o_help,		'help'		=> \$o_help,
	'V'	=> \$o_version,		'version'	=> \$o_version,
	'r:i'	=> \$o_runs,		'runs:i'	=> \$o_runs,
	'i:i'	=> \$o_interval,	'interval:i'	=> \$o_interval,
	'e:s'	=> \@o_exclude,		'exclude:s'	=> \@o_exclude,
	'E'	=> \$o_errors,		'errors'	=> \$o_errors,
	'm'	=> \$o_max,		'max'		=> \$o_max,
	'a'	=> \$o_average,		'average'	=> \$o_average,
	'w:s'	=> \@o_warn,		'warning:s'	=> \@o_warn,
	'c:s'	=> \@o_crit,		'critical:s'	=> \@o_crit
  );

  # process options
  print_help()		if defined $o_help;
  print_version()	if defined $o_version;

  # can't use max and average
  if (defined $o_max && defined $o_average){
    print "Can't use max and average at the same time!\n";
    print_usage();
    exit $ERRORS{$status{'unknown'}};
  }

}


#***************************************************#
#  Function: print_usage                            #
#---------------------------------------------------#
#  print usage information                          #
#                                                   #
#***************************************************#
sub print_usage(){
  print "Usage: $0 [-v] -H <hostname> [-p <port>] -a <auth> [-A <api>] [-t <timeout>] \n";
  print "       -D <data center> | -C <cluster> | -R <rhev host> | -S <storage domain> -M <vm> | -P <vmpool> \n";
  print "       [-w <warn>] [-c <critical>] [-V] [-l <check>] [-s <subcheck>]\n"; 
}


#***************************************************#
#  Function: print_help                             #
#---------------------------------------------------#
#  print help text                                  #
#                                                   #
#***************************************************#
sub print_help(){
  print "\nRed Hat Enterprise Virtualization checks for Icinga/Nagios version $version\n";
  print "GPL license, (c)2012 - Rene Koch <r.koch\@ovido.at>\n\n";
  print_usage();
  print <<EOT;

Options:
 -h, --help
    Print detailed help screen
 -V, --version
    Print version information
 -H, --hostname
    Host name or IP Address of RHEV Manager
 -a, --authorization=AUTH_PAIR
    Username\@domain:password required for login to REST-API
 -D, --dc
    RHEV data center name
 -C, --cluster
    RHEV cluster name
 -R, --host
    RHEV Hypervisor name
 -S, --storage
    RHEV Storage domain name
 -M, --vm
    RHEV virtual machine name
 -P, --vmpool
    RHEV vm pool
 -l, --check
    DC/Cluster/Hypervisor/VM/Storage Pool Check
    see $projecturl or README for details
 -s, --subcheck
    DC/Cluster/Hypervisor/VM/Storage Pool Subcheck
    see $projecturl or README for details
 -w, --warning=DOUBLE
    Value to result in warning status
 -c, --critical=DOUBLE
    Value to result in critical status
 -v, --verbose
    Show details for command-line debugging
    (Icinga/Nagios may truncate output)

Send email to r.koch\@ovido.at if you have questions regarding use
of this software. To submit patches of suggest improvements, send
email to r.koch\@ovido.at
EOT

exit $ERRORS{$status{'unknown'}};
}



#***************************************************#
#  Function: print_version                          #
#---------------------------------------------------#
#  Display version of plugin and exit.              #
#                                                   #
#***************************************************#

sub print_version{
  print "$prog $version\n";
  exit $ERRORS{$status{'unknown'}};
}


#***************************************************#
#  Function: main                                   #
#---------------------------------------------------#
#  The main program starts here.                    #
#                                                   #
#***************************************************#

# parse command line options
parse_options();

# get operating system
my $kernel_name = `uname -s`;
my $kernel_release = `uname -r | cut -d- -f1`;
chomp $kernel_name;
chomp $kernel_release;

if ($kernel_name eq "Linux"){
#  # iostat on RHEL 5 is a little bit different to RHEL 6, so we check for kernel version
#  # RHEL 5 includes partitions on devices, RHEL 6 doesn't
#  # RHEL 5: can't use -x and -p at the same time
#  if ($kernel_release =~ /2.6.18/){
#    # RHEL 5
#
#  }else{
#    # RHEL 6
#    # get list of devices
    my $devices = "";
    my @tmp = `iostat -d`;
    for (my $i=0;$i<=$#tmp;$i++){
      next if $tmp[$i] =~ /^$/;
      next if $tmp[$i] =~ /^Linux/;
      next if $tmp[$i] =~ /^Device:/;
      chomp $tmp[$i];
      my @dev = split / /, $tmp[$i];

      # match devs with exclude list
      my $match = 0;
      for (my $x=0;$x<=$#o_exclude;$x++){
	$match = 1 if $dev[0] =~ /$o_exclude[$x]/;
      }

      # exclude cd drives
      if (-e "/dev/cdrom"){
	my $cdrom = `ls -l /dev/cdrom | tr -s ' ' ' ' | cut -d' ' -f11`;
        chomp $cdrom;
	next if $dev[0] eq $cdrom;
      }

      $devices .= " -p " . $dev[0] if $match != 1;

    }
    my $cmd = "iostat -dkx" . $devices . " " . $o_interval . " " . $o_runs;
    print "CMD: $cmd \n";
#  }

}elsif ($kernel_name eq "SunOS"){

    my $devices = "";
    my @tmp = `iostat -xn`;
    for (my $i=0;$i<=$#tmp;$i++){
      next if $tmp[$i] =~ /^$/;
      next if $tmp[$i] =~ /^(\s+)extended(\s)device(\s)statistics/;
      next if $tmp[$i] =~ /^(\s+)r\/s(\s+)w\/s(\s+)kr\/s/;
      chomp $tmp[$i];
      $tmp[$i] =~ s/\s+/ /g;
      my @dev = split / /, $tmp[$i];

      # match devs with exclude list
      my $match = 0;
      for (my $x=0;$x<=$#o_exclude;$x++){
	$match = 1 if $dev[11] =~ /$o_exclude[$x]/;
      }

      # exclude cd drives
      if (-e "/dev/sr0"){
	my $cdrom = `ls -l /dev/sr0 | tr -s ' ' ' ' | cut -d' ' -f11 | cut -d/ -f2`;
        chop $cdrom;
        chop $cdrom;
        chop $cdrom;
	next if $dev[11] eq $cdrom;
      }

      # skip automount devices
      next if $dev[11] =~ /vold\(pid\d+\)/;

      $devices .= " -p " . $dev[11] if $match != 1;

    }
    my $cmd = "iostat -dnx" . $devices . " " . $o_interval . " " . $o_runs;
    print "CMD: $cmd \n";

}else{
  exit_plugin ("unknown", "Operating system $kernel_name isn't supported, yet.");
}


#***************************************************#
#  Function exit_plugin                             #
#---------------------------------------------------#
#  Prints plugin output and exits with exit code.   #
#  ARG1: status code (ok|warning|cirtical|unknown)  #
#  ARG2: additional information                     #
#***************************************************#

sub exit_plugin{
  print "I/O $status{$_[0]}: $_[1]\n";
  exit $ERRORS{$status{$_[0]}};
}


exit $ERRORS{$status{'unknown'}};

