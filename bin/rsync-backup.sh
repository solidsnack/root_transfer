#!/bin/sh

usage() {
cat <<USAGE
 USAGE: rsync-backup.sh <rsync options> <source> <dest>

  Passes arguments and options on to \`rsync' with some options pre-set. Some
  options you might want to add:

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

  This script and discussion of options was lifted from:

    http://www.sanitarium.net/golug/rsync_backups_2010.html

USAGE
}

case "$1" in
  -h|'-?'|--help) usage ; exit 0 ;;
  *)              rsync --archive \
                        --one-file-system \
                        --hard-links \
                        --human-readable \
                        --inplace \
                        --numeric-ids \
                        --delete \
                        "$@" ;;
esac


