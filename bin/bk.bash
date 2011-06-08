#!/bin/bash
set -o errexit -o nounset -o pipefail
function usage {
cat <<USAGE
 USAGE: bk.bash <backup dir>

  Backs up all LVM logical volumes to the backup directory.

USAGE
}

host=$(hostname)

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
  echo "$(timestamp) -bk- $host $1" 1>&2
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

function backup {
  local lv=$1
  local vg_lv=${lv#/dev/}
  log "${vg_lv} Trying to backup."
  log "${vg_lv} Creating snapshot."
  if snap_device=$(snapon "${lv}")
  then
    log "${vg_lv} Mounting snapshot."
    if mount "$snap_device" "${arena}/mnt"
    then
      mkdir -p "${to}/${vg_lv}"
      if latest=$(latest_backup "$vg_lv")
      then
        log "${vg_lv} Recycling previous backup \`${latest}'."
        log "${vg_lv} Starting \`rsync' run."
        if rsync_shim --link-dest="$latest" "${arena}/mnt"/ "${to}/${vg_lv}"
        then
          log "${vg_lv} Run of \`rsync' complete."
        else
          log "${vg_lv} Run of \`rsync' failed."
        fi
      else
        log "${vg_lv} No previous backup to recycle."
        log "${vg_lv} Starting \`rsync' run."
        if rsync_shim "${arena}/mnt"/ "${to}/${vg_lv}"
        then
          log "${vg_lv} Run of \`rsync' complete."
        else
          log "${vg_lv} Run of \`rsync' failed."
        fi
      fi
      log "${vg_lv} Unmounting snapshot."
      umount "${arena}/mnt"
    else
      log "${vg_lv} Can not mount."
    fi
    log "${vg_lv} Destroying snapshot."
    snapoff "$snap_device"
  else
    log "${vg_lv} Can not snapshot."
  fi
  log "${vg_lv} Done trying."
}

case "${1:-}" in
  -h|'-?'|--help|help) usage ; exit 0 ;;
  *)                   cd "$1" ;;
  '')                  echo $'Please specify backup dir.' 1>&2 ; exit 1 ;;
esac

log "Backing up all LVM logical volumes in $(pwd -P)."

volumes=$(logical_volumes)
if egrep -q '/snap$' <<<"$volumes"
then
  log "Found snapshot volume already, aborting."
  exit 2
fi

arena=$(working_area)
t=$(timestamp)
to="${arena}/workspace/${t}"
log "Backup timestamp is ${t}."
for lv in $volumes
do
  backup "$lv"
done
log "Done trying."

log "Moving backup out of workspace."
mv "$to" "${arena}/${t}"
log "Pointing \`latest' symlink at backup."
[ -L "${arena}/latest" ] && rm "${arena}/latest"
ln -s "./${t}" "${arena}/latest"

log "Backup ${t} complete."

