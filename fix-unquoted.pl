#!/usr/bin/perl -ni.bak

if (/^From / && 
   !/^From \s*[^\s]+\s+\w\w\w\s+\w\w\w\s+\d?\d\s+\d?\d:\d\d(:\d\d)?(\s+[^\s]+)?\s+\d\d\d\d\s*$/) {
    print ">", $_; 
} else {
    print;
}
