#!/bin/bash 

OLD_ARCHIVE_DIR="/var/lib/mailman/archives/private";
ARCHIVE_DIR="/mail/list-archives/private";

lists=`ls $OLD_ARCHIVE_DIR | grep -v .mbox`

for list in $lists ; do
  mbox=$OLD_ARCHIVE_DIR/$list.mbox/$list.mbox 

  if /usr/lib/mailman/bin/config_list  -o - $list | grep "archive_private = 1" > /dev/null ; then
    private="--private"
  else
    private=""
  fi  

  echo "=== $list $private ==="

  if [ -f $mbox.tmp ] ; then
    if [ -f $mbox.old ] ; then  
      echo "Appending onto $mbox.old"
      cat $mbox.tmp >> $mbox.old
      rm $mbox.tmp 
    else 
      mv $mbox.tmp $mbox.old 
    fi
  fi

  if [ -f $mbox.old ] ; then
    if ! /home/admin/mhonarc/archive.pl $private --listname $list $mbox.old ; then
      echo FAILED!
    fi
  fi

  if [ -f $mbox ] ; then
    mv $mbox $mbox.tmp
    if ! /home/admin/mhonarc/archive.pl $private --listname $list $mbox.tmp ; then
      echo FAILED!
    else
      if [ -f $mbox.old ] ; then  
        echo "Appending onto $mbox.old"
        cat $mbox.tmp >> $mbox.old
        rm $mbox.tmp 
      else 
        mv $mbox.tmp $mbox.old 
      fi
    fi
    echo
  fi
done

