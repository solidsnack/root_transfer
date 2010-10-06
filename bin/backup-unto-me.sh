#!/bin/sh

usage() {
cat <<USAGE
 USAGE: backup-unto-me.sh stat
 USAGE: backup-unto-me.sh auto <rsync options> <source>
 USAGE: backup-unto-me.sh rsync+ <rsync options> <source> <dest>

  In the first form, prints diagnostic information -- where the script thinks
  it is, what the state of links is, whether a backup might be in progress
  interrupted.

  In the second form, manages links in its own directory, calling \`rsync' to
  perform an incremental backup.  In the third form, simply passes arguments
  and options to \`rsync' with some options pre-set. In either form, the
  argument vector is simply passed to \`rsync' with the first element removed.
  Some options you might want to add:

    --delete-excluded: This tells rsync that it can delete stuff from a
                       previous backup that is now within the excluded list.

    --exclude-from=<some file>: This is a plain text file with a list of paths
                                that I do not want backed up. The format of
                                the file is simply one path per line. I tend
                                to add things that will always be changing but
                                are unimportant such as unimportant log and
                                temp files. If you have a ~/.gvfs entry you
                                should add it too as it will cause a non-fatal
                                error.

    --link-dest=<some other backup>: This is the most recent complete backup
                                     that was current when we started. We are
                                     telling rsync to link to this backup for
                                     any files that have not changed.

    --verbose: This causes rsync to list each file that it touches.

    --progress: This adds to the verbosity and tells rsync to print out a
                %completion and transfer speed while transferring each file.

    --itemize-changes: This adds to the file list a string of characters that
                       explains why rsync believes each file needs to be
                       touched. See the man page for the explanation of the
                       characters.

  The approach taken in this script is drawn from:

    http://www.sanitarium.net/golug/rsync_backups_2010.html

  Discussion of the command line options is drawn verbatim from that page.

USAGE
}


toor=`dirname $0`


last() {
  readlink "last"
}

working() {
  readlink "working"
}

link_check() {
  if [ -L "last" ] && [ -L "working" ]
  then
    if [ `last` != `working` ]
    then
      echo "Backup interrupted or in progress?" 1>&2
      exit 2
    else
      echo "Links okay for backup." 1>&2
    fi
  else
    echo "Links don't exist." 1>&2
    exit 2
  fi
}

stat() {
  echo "Paths: root, last link target, working link target:" 1>&2
  echo "$toor"
  last
  working
  link_check
}

ready_new_links() {
  link_check
  date=`date --utc +%FT%TZ`
  new="$date"
  mkdir "$new"
  rm "working" 
  ln -s $new "working"
}

auto() {
  set -e
  ready_new_links
  rsync_plus --link-dest=./`last` "$@"/ ./`working`
  rm "last"
  ln -s `working` "last"
}

rsync_print() {
  echo 'Command to run:'
  echo 'rsync --archive \\'
  echo '      --sparse \\'
  echo '      --one-file-system \\'
  echo '      --hard-links \\'
  echo '      --human-readable \\'
  echo '      --numeric-ids \\'
  echo '      --delete \\'
  for arg in "$@"
  do
  echo "      ${arg} \\"
  done
}

rsync_plus() {
  rsync --archive --one-file-system --hard-links --human-readable \
        --sparse --numeric-ids --delete "$@"
}

case "$1" in
  -h|'-?'|--help) usage ; exit 0 ;;
  'rsync+')       shift ; rsync_plus "$@" ;;
  auto)           shift ; cd $toor ; auto "$@" ;;
  stat)           shift ; cd $toor ; stat ;;
  *)              (echo 'Argument error.' ; usage) 1>&2 ; exit 4 ;;
esac

