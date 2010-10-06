#!/bin/bash

##  Very non-portable. Works for one of my laptops.

root=/media/161461b1-f781-4a8a-819d-e576bb891417

perform_sync() {
  time $root/rsync-backup.sh --progress / "$root/one-time"
}


case "$1" in
  '')           set -e ; perform_sync ;;
  *)            (echo 'Incomprehensible args.') 2>&1 ; exit 2 ;;
esac

