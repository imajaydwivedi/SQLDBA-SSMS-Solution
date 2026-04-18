#!/usr/bin/env bash
# vss-backup.sh — KVM VSS snapshot + SqlPoc restore orchestrator
#
# Usage:
#   ./vss-backup.sh [OPTIONS]
#
# Options:
#   -d "DB1,DB2"        Databases to backup/restore (default: CDCDemo,Db2,Facebook)
#   -r "SRC:TGT,..."    Rename map for restore  (e.g. "CDCDemo:CDCDemo_Restored")
#   -n                  Dry-run: print commands, do not execute
#   -h                  Show help
#
# Environment:
#   SUDO_PASS           sudo password for ryzen9 (optional, if sudoers not passwordless)
#
# Runs on: ryzen9 (Ubuntu KVM host)
# Requires: python3 pywinrm, virsh, qemu-agent on AgHost-1A

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────
VM_SOURCE="AgHost-1A"
VM_TARGET="SqlPoc"
DISK_TARGET="vdc"       # E:\ on AgHost-1A
BACKUP_STORE="/vm-storage-02/libvirt-images"
SOURCE_DISK="/vm-storage-01/AgHost-1A_E_Drive.qcow2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER_PY="$SCRIPT_DIR/winrm_helper.py"

# Load lab credentials from .venv/config.env (see vss-venv/ for a template).
ENV_FILE="$SCRIPT_DIR/.venv/config.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found. Copy $SCRIPT_DIR/vss-venv/ to $SCRIPT_DIR/.venv/ and edit values." >&2
    exit 1
fi
# shellcheck disable=SC1090
set -a; . "$ENV_FILE"; set +a

AG_IP="${AGHOST_IP}"
POC_IP="${SQLPOC_IP}"
AG_USER="${AGHOST_USER}"
POC_USER="${SQLPOC_USER}"
SQL_PASS="${SA_PWD}"

# ── Defaults ──────────────────────────────────────────────────────────────
DATABASES="CDCDemo,Db2,Facebook"
RENAME_MAP=""
DRY_RUN=0

usage() { grep '^#' "$0" | sed 's/^# \{0,2\}//'; exit 0; }
log()   { echo "[$(date +'%H:%M:%S')] $*"; }
run()   { if [[ $DRY_RUN -eq 1 ]]; then echo "DRY: $*"; else eval "$@"; fi; }

while getopts "d:r:nh" opt; do
    case $opt in
        d) DATABASES="$OPTARG" ;;
        r) RENAME_MAP="$OPTARG" ;;
        n) DRY_RUN=1; log "DRY-RUN mode — no changes will be made" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Convert comma-separated DBs to PS array string: 'CDCDemo','Db2'
ps_db_array() { echo "$DATABASES" | sed "s/,/','/g" | sed "s/^/'/" | sed "s/$/'/" ; }

# Convert rename map "SRC:TGT,SRC2:TGT2" to PS hashtable: @{SRC='TGT';SRC2='TGT2'}
ps_rename_map() {
    if [[ -z "$RENAME_MAP" ]]; then echo "@{}"; return; fi
    local pairs; pairs=$(echo "$RENAME_MAP" | tr ',' '\n')
    local ht="@{"
    while IFS=: read -r src tgt; do ht+="${src}='${tgt}';"; done <<< "$pairs"
    echo "${ht}}"
}

# ── Helper: run PowerShell on a Windows VM via pywinrm ───────────────────
winrm_ps() {
    local HOST_KEY="$1"; local SCRIPT="$2"
    python3 - "$HOST_KEY" <<PYEOF
import sys, winrm
h = {"AgHost-1A": ("$AG_IP","$AG_USER","$SQL_PASS"), "SqlPoc": ("$POC_IP","$POC_USER","$SQL_PASS")}
ip, user, pwd = h[sys.argv[1]]
s = winrm.Session(f"http://{ip}:5985/wsman", auth=(user, pwd), transport="ntlm",
                  read_timeout_sec=300, operation_timeout_sec=290)
r = s.run_ps("""$SCRIPT""")
if r.std_out: print(r.std_out.decode("utf-8","replace"))
if r.std_err: print("STDERR:", r.std_err.decode("utf-8","replace")[:500], file=sys.stderr)
sys.exit(r.status_code)
PYEOF
}

log "=== VSS Backup + Restore Orchestrator ==="
log "Databases : $DATABASES"
log "RenameMap : ${RENAME_MAP:-none}"
log "DryRun    : $DRY_RUN"
echo ""

# ── Phase 1a: Pre-snapshot full backup on AgHost-1A ──────────────────────
log "PHASE 1: Pre-snapshot BACKUP DATABASE on AgHost-1A"
DB_ARRAY=$(ps_db_array)
BACKUP_TS=$(winrm_ps AgHost-1A "
\$ErrorActionPreference='Stop'
\$dbs = @($DB_ARRAY)
\$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
if (-not (Test-Path 'E:\\Backups')) { New-Item -ItemType Directory 'E:\\Backups' | Out-Null }
if (-not (Test-Path 'E:\\TLogBackups')) { New-Item -ItemType Directory 'E:\\TLogBackups' | Out-Null }
foreach (\$db in \$dbs) {
    \$bak = \"E:\\\\Backups\\\\\${db}_\${ts}.bak\"
    Write-Host \"[\$db] Backing up -> \$bak\"
    Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password '$SQL_PASS' -QueryTimeout 600 `
        -Query \"BACKUP DATABASE [\$db] TO DISK = N'\$bak' WITH COMPRESSION, CHECKSUM, STATS=10;\"
    Write-Host \"[\$db] Done\"
}
Write-Host \"BackupTimestamp=\$ts\"
\$ts
" 2>&1 | grep -E '^[0-9]{8}_[0-9]{6}$' | tail -1)

if [[ -z "$BACKUP_TS" ]]; then
    log "ERROR: Could not determine backup timestamp. Check AgHost-1A logs."; exit 1
fi
log "Backup timestamp: $BACKUP_TS"

# ── Phase 1b: VSS snapshot of E:\ (vdc) ──────────────────────────────────
log "PHASE 2: VSS Snapshot of $VM_SOURCE E:\\"
SNAP_NAME="${VM_SOURCE}-edrv-$(date +%Y%m%d-%H%M%S)"
run sudo virsh snapshot-create-as "$VM_SOURCE" \
    --name "$SNAP_NAME" \
    --description "E-drive VSS snapshot pre-restore $SNAP_NAME" \
    --diskspec vda,snapshot=no \
    --diskspec vdb,snapshot=no \
    --diskspec "$DISK_TARGET,snapshot=external" \
    --disk-only --quiesce --atomic
log "Snapshot created: $SNAP_NAME"

# ── Phase 2: rsync qcow2 to backup storage ───────────────────────────────
log "PHASE 3: rsync qcow2 to $BACKUP_STORE"
BACKUP_QCOW2="$BACKUP_STORE/${VM_SOURCE}_E_Drive-${SNAP_NAME}.qcow2"
run sudo rsync -avhP "$SOURCE_DISK" "$BACKUP_QCOW2"
run sudo qemu-img check "$BACKUP_QCOW2" && log "qcow2 integrity OK"

# blockcommit overlay back into base (AgHost-1A already running on overlay)
run sudo virsh blockcommit "$VM_SOURCE" "$DISK_TARGET" --active --pivot
OVERLAY="${SOURCE_DISK%.*}.${SNAP_NAME}"
run sudo virsh snapshot-delete "$VM_SOURCE" --snapshotname "$SNAP_NAME" --metadata 2>/dev/null || true
run sudo rm -f "$OVERLAY" 2>/dev/null || true
log "Blockcommit complete — $VM_SOURCE back to base disk"

# ── Phase 3: Attach snapshot to SqlPoc ───────────────────────────────────
log "PHASE 4: Attach snapshot to SqlPoc as vdd"
cat > /tmp/attach-vdd.xml <<XMLEOF
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2'/>
  <source file='${BACKUP_QCOW2}'/>
  <target dev='vdd' bus='virtio'/>
  <readonly/>
</disk>
XMLEOF
run sudo virsh attach-device "$VM_TARGET" /tmp/attach-vdd.xml --live
log "vdd attached to SqlPoc (read-only)"
sleep 5

# ── Phase 4: Bring T:\ online and restore on SqlPoc ──────────────────────
log "PHASE 5: Bring T:\\ online and RESTORE on SqlPoc"
RENAME_HT=$(ps_rename_map)

winrm_ps SqlPoc "
\$ErrorActionPreference='Stop'
# Bring new disk online as T:\
\$disk = Get-Disk | Where-Object { \$_.OperationalStatus -eq 'Offline' } | Select-Object -First 1
if (-not \$disk) {
    # May auto-come-online — find by read-only status
    \$disk = Get-Disk | Where-Object { \$_.IsReadOnly -and \$_.Size -gt 10GB -and \$_.Number -ge 3 } | Select-Object -First 1
}
if (\$disk) {
    Set-Disk -Number \$disk.Number -IsOffline \$false -ErrorAction SilentlyContinue
    \$part = Get-Partition -DiskNumber \$disk.Number | Where-Object { \$_.Size -gt 1GB } | Select-Object -First 1
    if (\$part.DriveLetter -and \$part.DriveLetter -ne 'T') {
        Remove-PartitionAccessPath -DiskNumber \$disk.Number -PartitionNumber \$part.PartitionNumber -AccessPath \"\$(\$part.DriveLetter):\\\" -ErrorAction SilentlyContinue
    }
    if (-not \$part.DriveLetter -or \$part.DriveLetter -ne 'T') {
        Add-PartitionAccessPath -DiskNumber \$disk.Number -PartitionNumber \$part.PartitionNumber -AccessPath 'T:\\'
    }
    Write-Host \"T:\\ assigned (Disk \$(\$disk.Number))\"
} else { Write-Warning 'No offline disk found — T:\\ may already be mounted' }
Get-PSDrive T -ErrorAction SilentlyContinue | Out-String | Write-Host
"

# Run Restore-FromVSSSnapshot.ps1 on SqlPoc
RESTORE_SCRIPT=$(cat "$SCRIPT_DIR/Restore-FromVSSSnapshot.ps1")
winrm_ps SqlPoc "
$RESTORE_SCRIPT

Restore-FromVSSSnapshot -Databases @($DB_ARRAY) -RenameMap $RENAME_HT -BackupTimestamp '$BACKUP_TS'
"

log "PHASE 5 complete — databases should be in RESTORING state"

# ── Phase 5: Remove T:\ and detach ───────────────────────────────────────
log "PHASE 6: Remove T:\\ from SqlPoc and detach vdd"
winrm_ps SqlPoc "
\$disk = Get-Disk | Where-Object { \$_.IsReadOnly -eq \$true -and \$_.Size -gt 10GB } | Select-Object -First 1
if (\$disk) {
    \$part = Get-Partition -DiskNumber \$disk.Number | Where-Object { \$_.DriveLetter -eq 'T' }
    if (\$part) { Remove-PartitionAccessPath -DiskNumber \$disk.Number -PartitionNumber \$part.PartitionNumber -AccessPath 'T:\\' }
    Set-Disk -Number \$disk.Number -IsOffline \$true
    Write-Host \"T:\\ removed, disk offline\"
}
"
run sudo virsh detach-disk "$VM_TARGET" vdd --live 2>/dev/null || true
log "vdd detached"

log ""
log "=== Orchestration Complete ==="
log "Backup qcow2 : $BACKUP_QCOW2"
log "Backup TS    : $BACKUP_TS"
log "Databases    : $DATABASES"
log ""
log "Next: Apply-TLogs.ps1 on SqlPoc every 15 min (or run manually)"
