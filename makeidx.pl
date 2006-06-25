#!/usr/bin/perl -w

$ARCHIVE_DIR = "/mail/list-archives/private";
$PUBLIC_ARCHIVE_DIR = "/mail/list-archives/public";
#$PUBLIC_RCFILE = "/home/admin/mhonarc/public-rc/base.rc";
#$PRIVATE_RCFILE = "/home/admin/mhonarc/private-rc/base.rc";

my @lists;

my $privateonly = 0;
my $publiconly = 0;

for $arg (@ARGV) {
    if ($arg eq "--privateonly") {
	$privateonly = 1;
    } elsif ($arg eq "--publiconly") {
	$publiconly = 1;
    } else {
	push @lists, $arg;
    }
}

if (@lists == 0) {
    opendir DH, $ARCHIVE_DIR || die "Cannot open $ARCHIVE_DIR for indexing: $!\n";
    @lists = sort grep { -d "$ARCHIVE_DIR/$_" && !/^\./ } readdir DH;
    close DH;
}

for $list (@lists) {
    $dirname = "$ARCHIVE_DIR/$list";
    
    opendir DH, $dirname || die "Cannot open $dirname for indexing: $!\n";
    my @archives = grep { /^(\d+)-(\w+)$/ } readdir DH;
    closedir DH;

    $private = ! -l "$PUBLIC_ARCHIVE_DIR/$list";

    next if ($publiconly && $private);
    next if ($privateonly && !$private);

    $privateopt = $private ? "--private" : "";

    system ("/home/admin/mhonarc/archive.pl --listname $list --makeindex $privateopt");
} 


