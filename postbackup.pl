#!/usr/bin/perl -w

use strict;

my $phase = shift;

if ($phase eq 'backup-end') {

    my $mode = shift; # stop/suspend/snapshot

    my $vmid = shift;

    my $vmtype = $ENV{VMTYPE}; # openvz/qemu

    my $dumpdir = $ENV{DUMPDIR};

    my $storeid = $ENV{STOREID};

    my $hostname = $ENV{HOSTNAME};

    # tarfile is only available in phase 'backup-end'
    my $tarfile = $ENV{TARFILE};

    # logfile is only available in phase 'log-end'
    my $logfile = $ENV{LOGFILE}; 

    system("sleep 1");
    system("mkdir -p /root/VMIDS");
    system("echo \"$vmid;$dumpdir;$tarfile\" > /root/VMIDS/$vmid");

}

exit (0);
