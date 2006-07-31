#!/bin/bash 

OLD_ARCHIVE_DIR="/var/lib/mailman/archives/private";
ARCHIVE_DIR="/mail/list-archives/private";

lists=`ls $ARCHIVE_DIR`
#lists=gnome-announce-list
daterange="--start-time=2006-06-01 --end-time=2006-06-30"
monthlyname="2006-June"

for list in $lists ; do
  mbox=$OLD_ARCHIVE_DIR/$list.mbox/$list.mbox 

  if /usr/lib/mailman/bin/config_list  -o - $list | grep "archive_private = 1" > /dev/null ; then
    private="--private"
  else
    private=""
  fi  

  echo "=== $list $private ==="

  if [ -d $ARCHIVE_DIR/$list/$monthlyname ] ; then
    echo "Clearing up broken monthly archive directory..."
    rm -rf $ARCHIVE_DIR/$list/$monthlyname
  fi
  if [ -d $ARCHIVE_DIR/$list/$monthlyname.txt.gz ] ; then
    echo "Clearing up broken monthly archive file..."
    rm -f $ARCHIVE_DIR/$list/$monthlyname.txt.gz
  fi
  if [ -f $mbox ] ; then
    echo "Sanitizing mbox (stripping malformed UTF-8)..."
    iconv -f ISO-8859-1 -t UTF-8 $mbox >/tmp/mbox

    echo "Processing mbox file..."
    if ! /home/admin/mhonarc/archive.pl $daterange $private --listname $list /tmp/mbox ; then
      echo FAILED!
    fi
    echo
  fi
done

