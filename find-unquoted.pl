#!/usr/bin/perl -w 

while (<>) {
    if (/^From / && 
	!/^From \s*[^\s]+\s+\w\w\w\s+\w\w\w\s+\d?\d\s+\d?\d:\d\d(:\d\d)?(\s+[^\s]+)?\s+\d\d\d\d\s*$/) {
	print; 
	exit 0;
    }
}

exit 1;
