#!/bin/bash

##  Very non-portable. Works for one of my laptops.

root=/media/161461b1-f781-4a8a-819d-e576bb891417
snap=/media/snap

setup_snapshot() {
  lvm lvcreate --snapshot --name snap --size 10G /dev/alf/root
  mount /dev/alf/snap $snap
}

backups(){
  ls -d $root/????-??-??T??:??:??Z | sort
}

perform_sync() {
date=`date --utc +%FT%TZ`
latest=`backups | tail -n 1`
time $root/rsync-backup.sh \
  --link-dest="$latest" \
  --progress $snap/ "$root/$date"
}

retire_snapshot() {
  umount $snap
  lvm lvremove -f /dev/alf/snap 
}

case "$1" in
  '')           set -e ; setup_snapshot ; perform_sync ; retire_snapshot ;;
  snap+)        set -e ; setup_snapshot ;;
  snap-)        set -e ; retire_snapshot ;;
  *)            (echo 'Incomprehensible args.') 2>&1 ; exit 2 ;;
esac

