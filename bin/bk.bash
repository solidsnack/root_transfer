#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

host=`hostname`

function working_area {
  mkdir -p "$host"
  mkdir -p "$host"/mnt
  mkdir -p "$host"/workspace
  (cd "$host" && pwd -P)
}

# Obtain lv listing.
function logical_volumes {
  lvm lvdisplay | sed -rn '/^  LV Name +([^ ]+)$/ { s//\1/ ; p }'
}

# Create snapshot.
function snapon {
  lvm lvcreate --extents '50%FREE' --snapshot --name snap "$1" > /dev/null
  lvm lvdisplay | sed -rn '/^  LV Name +([^ ]+\/snap)$/ { s//\1/ ; p }'
}

# Destroy snapshot.
function snapoff {
  lvm lvremove --force "$1"
}

function timestamp {
  date --utc +%FT%TZ
}

function log {
  echo "`timestamp` -bk- $host $1" 1>&2
}

function rsync_shim {
  time rsync --archive \
             --one-file-system \
             --hard-links \
             --human-readable \
             --inplace \
             --numeric-ids \
             --progress \
             "$@"
}

function latest_backup {
  [ -d "${arena}/latest/${1}" ] && cd "${arena}/latest/${1}" && pwd -P
}


arena=`working_area`
t=`timestamp`
to="${arena}/workspace/${t}"

log "Backing up all LVM logical volumes."
for lv in `logical_volumes`
do
  vg_lv=${lv#/dev/}
  log "${vg_lv} Creating and mounting snapshot."
  snap_device=`snapon "${lv}"`
  mount "$snap_device" "${arena}/mnt"
  mkdir -p "${to}/${vg_lv}"
  if latest=`latest_backup "$vg_lv"`
  then
    log "${vg_lv} Recycling previous backup \`${latest}'."
    log "${vg_lv} Starting \`rsync' run."
    rsync_shim --link-dest="$latest" "${arena}/mnt"/ "${to}/${vg_lv}"
  else
    log "${vg_lv} No previous backup to recycle."
    log "${vg_lv} Starting \`rsync' run."
    rsync_shim "${arena}/mnt"/ "${to}/${vg_lv}"
  fi
  log "${vg_lv} Run of \`rsync' complete."
  log "${vg_lv} Unmounting and destroying snapshot."
  umount "${arena}/mnt"
  snapoff "$snap_device"
  log "${vg_lv} Done."
done
log "Finished all copies; rewriting symlinks."

mv "$to" "${arena}/${t}"
[ -L "${arena}/latest" ] && rm "${arena}/latest"
ln -s "./${t}" "${arena}/latest"
log "Done."

