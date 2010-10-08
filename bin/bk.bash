#!/bin/bash

set -e

host=`hostname`

function working_area {
  mkdir -p "$host"
  mkdir -p "$host"/mnt
  mkdir -p "$host"/workspace
  (cd "$host" && pwd --physical)
}

# Obtain lv listing.
function logical_volumes {
  lvm lvdisplay | sed -rn '/^  LV Name +([^ ]+)$/ { s//\1/ ; p }'
}

# Create snapshot.
function snapon {
  lvm lvcreate --size '50%FREE' --snapshot --name snap "$1"
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
  echo -n "`timestamp` -bk- ${host} " 1>&2
  echo "$1" 1>&2
}

function rsync_shim {
  time rsync --archive \
             --one-file-system \
             --hard-links \
             --human-readable \
             --inplace \
             --numeric-ids \
             --progress \
             "$@" ;;
}

function latest_backup {
  (cd "${arena}/${1}/latest/" && pwd --physical)
}


arena=`working_area`
t=`timestamp`
to="${arena}/workspace/${t}"

log "Backing up all LVM logical volumes."
for lv in `logical_volumes`
do
  local vg_lv=${lv#/dev/}
  log "${vg_lv} Creating and mounting snapshot."
  local snap_device=`snapon "${lv}"`
  mount "$snap_device" "${arena}/mnt"
  mkdir -p "${to}/${vg_lv}"
  if latest=`latest_backup "$vg_lv"`
  then
    log "${vg_lv} Recycling previous backup \`${latest}'."
    log "${vg_lv} Starting \`rsync' run."
    run_rsync --link-dest="$latest" "$from"/ "${to}/${vg_lv}"
  else
    log "${vg_lv} No previous backup to recycle."
    log "${vg_lv} Starting \`rsync' run."
    run_rsync "$from"/ "${to}/${vg_lv}"
  fi
  log "${vg_lv} Run of \`rsync' complete."
  log "${vg_lv} Unmounting and destroying snapshot."
  umount "${arena}/mnt"
  snapoff "$snap_device"
  log "${vg_lv} Done."
done
log "Finished all copies; rewriting symlinks."

mv "$to" "${arena}/${t}"
[ -l "${arena}/latest" ] && rm "${arena}/latest"
ln -s "./${t}" "${arena}/latest"
log "Done."

