#!/bin/bash
# Version             0.1.2
# Date                31.08.25
# Author              DerDanilo
# Contributors        aboutte, xmirakulix, bootsie123, phidauex, aroun01

###########################
# Configuration Variables #
###########################

# Permanent backups directory
DEFAULT_BACK_DIR="/mnt/pve/pve-backup"
BACK_DIR=${BACK_DIR:-$DEFAULT_BACK_DIR}

# Number of backups to keep
MAX_BACKUPS=5

_now=$(date +%Y-%m-%d.%H.%M.%S)

# Set to 'true' to backup /opt/* folder
BACKUP_OPT_FOLDER=false

# Healthchecks.io notification service
HEALTHCHECKS=0
HEALTHCHECKS_URL=https://hc-ping.com/your_uuid_here

###########################

# Set terminal to "dumb" for cron compatibility
export TERM=${TERM:-dumb}

# Always exit on error
set -e

# Set backup directory
_bdir=${BACK_DIR:-$DEFAULT_BACK_DIR}

# Check backup directory exists and is writable
if [[ ! -d "$_bdir" ]]; then
    echo "Aborting because backup target does not exist: $_bdir"
    exit 1
fi
if [[ ! -w "$_bdir" ]]; then
    echo "Aborting because backup target is not writable: $_bdir"
    exit 1
fi

LOG_FILE="$_bdir/backup-log-$_now.txt"
echo "Script started at $(date)" >> "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# Temporary storage directory
_tdir=${TMP_DIR:-/var/tmp}
_tdir=$(mktemp -d "$_tdir/proxmox-XXXXXXXX")
if [[ ! -w "$_tdir" ]]; then
    echo "Aborting because temporary directory is not writable: $_tdir"
    exit 1
fi

function clean_up {
    exit_code=$?
    echo "Cleaning up temporary directory: $_tdir"
    rm -rf "$_tdir"
    if [ $HEALTHCHECKS -eq 1 ]; then
        echo "Sending Healthchecks.io notification with exit code $exit_code"
        curl -fsS -m 10 --retry 5 -o /dev/null "$HEALTHCHECKS_URL/$exit_code"
    fi
}

# Register cleanup function
trap clean_up EXIT

_HOSTNAME=$(hostname)

# General information
pveversion > "$_tdir/pve-version.txt"
pveperf > "$_tdir/pve-performance.txt"
df -h > "$_tdir/disk-usage.txt"
free -h > "$_tdir/memory-info.txt"

# Network configuration
ip addr show > "$_tdir/network-interfaces-detailed.txt"
ip route show > "$_tdir/routing-table.txt"
cat /etc/hosts > "$_tdir/hosts-file.txt"

# Storage information
#pvesm status > "$_tdir/storage-status.txt"
#pvesm list > "$_tdir/storage-list.txt"

# Cluster configuration
pvecm status 2>/dev/null > "$_tdir/cluster-status.txt" || true
pvecm nodes 2>/dev/null > "$_tdir/cluster-nodes.txt" || true
cp /etc/pve/corosync.conf "$_tdir/" 2>/dev/null || true

# Hardware information
lspci > "$_tdir/hardware-pci.txt"
lsblk > "$_tdir/block-devices.txt"
lscpu > "$_tdir/cpu-info.txt"

# VM and container lists
qm list > "$_tdir/vm-list.txt"
pct list > "$_tdir/container-list.txt"

# Firewall rules
pve-firewall compile > "$_tdir/firewall-rules.txt"
cp /etc/pve/firewall/*.fw "$_tdir/" 2>/dev/null || true

# Subscription information
pvesubscription get > "$_tdir/subscription-info.txt" 2>/dev/null || true

# Repositories
cp /etc/apt/sources.list.d/* "$_tdir/" 2>/dev/null || true

# Logs
tail -1000 /var/log/syslog > "$_tdir/syslog-tail.txt"
journalctl -u pveproxy.service --no-pager > "$_tdir/pveproxy-log.txt"

# Other configs
cp /etc/pve/status.cfg "$_tdir/" 2>/dev/null || true
cp /etc/pve/ceph.conf "$_tdir/" 2>/dev/null || true
cp /etc/default/pveproxy "$_tdir/" 2>/dev/null || true

# Create summary file
echo "Proxmox VE Backup Report" > "$_tdir/backup-report.txt"
echo "Date: $(date)" >> "$_tdir/backup-report.txt"
echo "PVE Version: $(pveversion | cut -d'/' -f1)" >> "$_tdir/backup-report.txt"
echo "Backup size: $(du -h "$_filename_final" | cut -f1)" >> "$_tdir/backup-report.txt"
echo "Number of VMs: $(qm list | wc -l)" >> "$_tdir/backup-report.txt"
echo "Number of Containers: $(pct list | wc -l)" >> "$_tdir/backup-report.txt"

# Ceph checks
ceph version 2>/dev/null > "$_tdir/ceph-version.txt" || true
ceph status 2>/dev/null > "$_tdir/ceph-status.txt" || true
ceph osd tree 2>/dev/null > "$_tdir/ceph-osd-tree.txt" || true

_filename1="$_tdir/proxmoxetc.$_now.tar"
_filename2="$_tdir/proxmoxvarlibpve.$_now.tar"
_filename3="$_tdir/proxmoxroot.$_now.tar"
_filename4="$_tdir/proxmoxcron.$_now.tar"
_filename5="$_tdir/proxmoxvbios.$_now.tar"
_filename6="$_tdir/proxmoxpackages.$_now.list"
_filename7="$_tdir/proxmoxreport.$_now.txt"
_filename8="$_tdir/proxmoxlocalbin.$_now.tar"
_filename9="$_tdir/proxmoxetcpve.$_now.tar"
_filename10="$_tdir/proxmoxopt.$_now.tar"
_filename_final="$_tdir/pve_$_HOSTNAME_$_now.tar.gz"

function description {
    echo "Proxmox Server Config Backup"
    echo "Hostname: $_HOSTNAME"
    echo "Timestamp: $_now"
    echo "Backup target: $_bdir"
    if [[ -t 0 && -t 1 ]]; then
        clear
        files_to_be_saved="/etc/*, /var/lib/pve-cluster/*, /root/*, /var/spool/cron/*, /usr/share/kvm/*.vbios"
        if [ "$BACKUP_OPT_FOLDER" = true ]; then files_to_be_saved="${files_to_be_saved}, /opt/*"; fi
        cat <<EOF

        Files to be saved:
        "$files_to_be_saved"

        -----------------------------------------------------------------

        This script is supposed to backup your node config and not VM
        or LXC container data. To backup your instances please use the
        built in backup feature or a backup solution that runs within
        your instances.

        For questions or suggestions please contact me at
        https://github.com/aroun01/proxmox-backup-server/
        -----------------------------------------------------------------

        Hit return to proceed or CTRL-C to abort.
EOF
        echo "Sleep 5 and continue"
        sleep 5
        clear
    fi
}

function are-we-root-abort-if-not {
    if [[ ${EUID} -ne 0 ]]; then
        echo "Aborting because you are not root"
        exit 1
    fi
}

function check-num-backups {
    if [[ $(ls "${_bdir}"/*_${_HOSTNAME}_*.tar.gz | wc -l) -ge $MAX_BACKUPS ]]; then
        local oldbackups
        oldbackups=$(ls "${_bdir}"/*_${_HOSTNAME}_*.tar.gz -t | tail -n +$MAX_BACKUPS)
        echo "Removing old backups: $oldbackups"
        rm -f $oldbackups
    fi
}

function copyfilesystem {
    echo "Tar files"
    tar --warning='no-file-ignored' -cvPf "$_filename1" --one-file-system /etc/.
    tar --warning='no-file-ignored' -cvPf "$_filename9" --one-file-system /etc/pve/.
    tar --warning='no-file-ignored' -cvPf "$_filename2" /var/lib/pve-cluster/.
    tar --warning='no-file-ignored' -cvPf "$_filename3" --one-file-system /root/.
    tar --warning='no-file-ignored' -cvPf "$_filename4" /var/spool/cron/.
    if [ "$BACKUP_OPT_FOLDER" = true ]; then
        tar --warning='no-file-ignored' -cvPf "$_filename10" --one-file-system /opt/.
    fi
    if [ "$(ls -A /usr/local/bin 2>/dev/null)" ]; then
        tar --warning='no-file-ignored' -cvPf "$_filename8" /usr/local/bin/.
    fi
    if [ "$(ls /usr/share/kvm/*.vbios 2>/dev/null)" != "" ]; then
        echo "Backing up custom video bios..."
        tar --warning='no-file-ignored' -cvPf "$_filename5" /usr/share/kvm/*.vbios
    fi
    echo "Copying installed packages list from APT"
    apt-mark showmanual | tee "$_filename6"
    echo "Copying pvereport output"
    pvereport | tee "$_filename7"
}

function compressandarchive {
    echo "Compressing files"
    if ls "$_tdir"/*.{tar,list,txt} >/dev/null 2>&1; then
        tar -cvzPf "$_filename_final" "$_tdir"/*.{tar,list,txt}
        echo "Created archive: $_filename_final"
    else
        echo "Error: No files to archive in $_tdir"
        exit 1
    fi
    echo "Copying config archive to backup folder: $_bdir"
    cp "$_filename_final" "$_bdir/"
}

function stopservices {
    for i in pve-cluster pvedaemon vz qemu-server; do systemctl stop "$i"; done
    sleep 10s
}

function startservices {
    for i in qemu-server vz pvedaemon pve-cluster; do systemctl start "$i"; done
    qm startall
}

# Send a healthcheck.io start
if [ $HEALTHCHECKS -eq 1 ]; then
    curl -fsS -m 10 --retry 5 -o /dev/null "$HEALTHCHECKS_URL/start"
fi

description
are-we-root-abort-if-not
check-num-backups
copyfilesystem
compressandarchive
echo "Script completed at $(date)" >> "$LOG_FILE"
