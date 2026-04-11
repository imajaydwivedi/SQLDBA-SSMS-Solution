# VSS Snapshot Backup of SQL Server on KVM

## Overview

This guide walks through performing a **VSS (Volume Shadow Copy Service)** snapshot backup of a SQL Server instance running inside a Windows Server virtual machine (`AgHost-1A`) hosted on a KVM hypervisor (`ryzen9` — Ubuntu Desktop).

### Architecture

```
ryzen9 (Ubuntu Desktop - KVM Hypervisor)
  └── AgHost-1A (Windows Server VM - SQL Server)
        └── VSS Snapshot → Backup
```

### How VSS Works with KVM

1. The KVM guest agent (`qemu-guest-agent`) signals Windows inside the VM.
2. Windows VSS freezes SQL Server I/O (via the SQL Writer VSS provider).
3. KVM takes a consistent disk snapshot (external snapshot).
4. VSS thaws SQL Server I/O — normal operations resume.
5. The snapshot can be mounted, backed up, or exported from the host.

---

## Prerequisites

### On the KVM Host (ryzen9 — Ubuntu)

- KVM/QEMU installed with `libvirt`
- `virsh` available
- Enough disk space for snapshots

```bash
# Verify the VM is recognized and running
virsh list --all | grep AgHost-1A

# Check available disk space on the host (need at least 2x VM disk size free)
df -h /var/lib/libvirt/images/
df -h /backup/

# Verify libvirt version supports --quiesce
virsh --version
virt-host-validate
```

### On the Windows Server VM (AgHost-1A)

- SQL Server installed and running
- `qemu-guest-agent` installed (enables host↔guest coordination)
- **SQL Server VSS Writer** service running
- Windows VSS service (`VSS`) running

```powershell
# Pre-flight: verify all required services are running on AgHost-1A (run as Administrator)
Get-Service -Name 'MSSQLSERVER','SQLWriter','VSS','QEMU-GA' | Select-Object Name, Status, StartType
```

Expected output — all four should show `Running`:
```
Name          Status  StartType
----          ------  ---------
MSSQLSERVER   Running Automatic
SQLWriter     Running Manual
VSS           Running Manual
QEMU-GA       Running Automatic
```

---

## Step 1 — Install & Verify qemu-guest-agent on AgHost-1A

The guest agent is critical — without it, KVM cannot signal VSS before snapshotting.

### 1.1 Download the Guest Agent on AgHost-1A

On the Windows VM, download the VirtIO drivers ISO which includes the guest agent:

```
https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

Or install via the bundled installer if already mounted:

```
D:\guest-agent\qemu-ga-x86_64.msi
```

### 1.2 Install and Start the Service

```powershell
# Run in PowerShell on AgHost-1A (as Administrator)
Start-Service QEMU-GA
Set-Service -Name QEMU-GA -StartupType Automatic
Get-Service QEMU-GA
```

### 1.3 ✅ Verify Guest Agent from the Host (ryzen9)

```bash
# On ryzen9 — check guest agent is responding and get version info
virsh qemu-agent-command AgHost-1A '{"execute":"guest-info"}' | python3 -m json.tool
```

Expected: a JSON response with `"version"` and `"supported_commands"` fields.
If the command hangs or returns an error, the guest agent is not running — return to Step 1.2.

```bash
# Also verify guest agent channel exists in the VM config
virsh dumpxml AgHost-1A | grep -A3 'channel'
```

Expected output should include:
```xml
<channel type='unix'>
  ...
  <target type='virtio' name='org.qemu.guest_agent.0'/>
```

---

## Step 2 — Verify SQL Server VSS Writer on AgHost-1A

```powershell
# Run in PowerShell or CMD on AgHost-1A (as Administrator)
vssadmin list writers
```

### ✅ Expected Output — SqlServerWriter Must Be Stable

```
Writer name: 'SqlServerWriter'
   Writer Id: {a65faa63-5ea8-4ebc-9dbd-a0c4db26912a}
   State: [1] Stable
   Last error: No error
```

> ⚠️ **Do not proceed to Step 4 if State is not `[1] Stable`.**
> A failed writer means VSS will not quiesce SQL Server properly.

### Fix — If the SQL Writer Is Missing or in a Failed State

```powershell
# Restart the SQL Server VSS Writer
net stop SQLWriter
net start SQLWriter

# Also restart the base VSS service if needed
net stop VSS
net start VSS

# Re-verify after restart
vssadmin list writers | Select-String -Pattern 'SqlServerWriter' -Context 0,4
```

### ✅ Validate VSS Shadow Copy Provider Is Available

```powershell
# List available VSS providers — Microsoft Software Shadow Copy provider must appear
vssadmin list providers
```

Expected output includes:
```
Provider name: 'Microsoft Software Shadow Copy provider 1.0'
   Provider type: System
   Provider Id: {b5946137-7b9f-4925-af80-51abd60b20d5}
```

---

## Step 3 — Identify the VM Disk on the Host (ryzen9)

```bash
# Find the disk image path used by AgHost-1A
virsh domblklist AgHost-1A --details
```

Example output:
```
Type   Device  Target  Source
------------------------------------------------
file   disk    vda     /var/lib/libvirt/images/AgHost-1A.qcow2
```

Note the **Source** path — this is what will be snapshotted.

### ✅ Validate Disk Image Health Before Snapshotting

```bash
# Confirm the base image is intact and not already on an overlay chain
BASE_IMAGE="/var/lib/libvirt/images/AgHost-1A.qcow2"
qemu-img info "$BASE_IMAGE"
qemu-img check "$BASE_IMAGE"
```

Expected `qemu-img info` output includes:
```
image: AgHost-1A.qcow2
file format: qcow2
...
backing file: <none>       ← must have no backing file (not already an overlay)
```

Expected `qemu-img check` output:
```
No errors were found on the image.
```

---

## Step 4 — Create a VSS-Consistent External Snapshot from ryzen9

This is the key step. `virsh snapshot-create-as` with `--quiesce` tells `qemu-guest-agent`
to trigger a VSS freeze inside Windows before taking the snapshot.

```bash
# On ryzen9 — create a quiesced (VSS-consistent) external snapshot
virsh snapshot-create-as AgHost-1A \
  --name "AgHost-1A-vss-$(date +%Y%m%d-%H%M%S)" \
  --description "VSS-consistent SQL Server snapshot" \
  --disk-only \
  --quiesce \
  --atomic
```

### Parameter Explanation

| Parameter | Purpose |
|---|---|
| `--disk-only` | Creates an external snapshot (overlay file), not a full VM state snapshot |
| `--quiesce` | Signals guest agent to freeze I/O via VSS before snapping |
| `--atomic` | Rolls back all disks if any one snapshot fails |

### ✅ Verify the Snapshot Was Created

```bash
# Confirm snapshot appears in the list
virsh snapshot-list AgHost-1A

# Confirm active disk is now the overlay (not the original qcow2)
virsh domblklist AgHost-1A --details
```

Expected — Source column should now point to an overlay file:
```
Type   Device  Target  Source
---------------------------------------------------------------------
file   disk    vda     /var/lib/libvirt/images/AgHost-1A.vss-20250411-020001
```

```bash
# Verify the overlay file exists and has a backing file pointing to the original
OVERLAY=$(virsh domblklist AgHost-1A | awk '/vda/ {print $2}')
qemu-img info "$OVERLAY"
```

Expected `qemu-img info` output confirms the chain:
```
image: AgHost-1A.vss-20250411-020001
file format: qcow2
backing file: /var/lib/libvirt/images/AgHost-1A.qcow2
```

### ✅ Verify VSS Freeze/Thaw Events in Windows Event Log

Immediately after the snapshot, check Windows Event Viewer on `AgHost-1A` to confirm VSS completed cleanly:

```powershell
# On AgHost-1A — check Application event log for VSS events around snapshot time
Get-WinEvent -LogName Application -MaxEvents 50 |
  Where-Object { $_.ProviderName -match 'VSS|SQLWriter|SQLWRITER' } |
  Select-Object TimeCreated, Id, LevelDisplayName, Message |
  Format-List
```

Look for Event IDs:
| Event ID | Source | Meaning |
|---|---|---|
| `8229` | VSS | A VSS writer has successfully completed a backup |
| `8230` | VSS | No error — freeze and thaw completed cleanly |
| `24583` | MSSQLSERVER | SQL Server database was successfully quiesced |

> ⚠️ Any **Error** or **Warning** level VSS events indicate the snapshot may not be application-consistent.
> In that case, **do not use the backup** — delete it and repeat from Step 4.

---

## Step 5 — Back Up the Snapshot Data (ryzen9)

Now that a consistent snapshot exists, the **original base disk** (before the overlay) holds
a point-in-time consistent image of SQL Server. Back it up:

```bash
SNAP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/backup/AgHost-1A"
mkdir -p "$BACKUP_DIR"

# The base disk is the original qcow2 before the overlay was created
cp /var/lib/libvirt/images/AgHost-1A.qcow2 "$BACKUP_DIR/AgHost-1A-base-$SNAP_DATE.qcow2"

# Optional: compress it
qemu-img convert -O qcow2 -c \
  /var/lib/libvirt/images/AgHost-1A.qcow2 \
  "$BACKUP_DIR/AgHost-1A-$SNAP_DATE-compressed.qcow2"
```

### ✅ Validate the Backup File Integrity

```bash
BACKUP_FILE="$BACKUP_DIR/AgHost-1A-base-$SNAP_DATE.qcow2"

# Check file was written and is non-zero
ls -lh "$BACKUP_FILE"

# Verify the backup image has no internal corruption
qemu-img check "$BACKUP_FILE"
```

Expected output:
```
No errors were found on the image.
Image end offset: XXXXXXX
```

```bash
# Cross-check: backup file size should be close to (or larger than) the source
du -sh /var/lib/libvirt/images/AgHost-1A.qcow2
du -sh "$BACKUP_FILE"
```

---

## Step 6 — Merge (Blockcommit) and Clean Up the Snapshot

After backup, merge the overlay back into the base image so the VM stays healthy.

```bash
# Blockcommit merges the overlay back into the base and pivots the active disk
virsh blockcommit AgHost-1A vda --active --verbose --pivot

# Delete the snapshot metadata
SNAP_NAME="<snapshot-name>"   # use name from Step 4
virsh snapshot-delete AgHost-1A --snapshotname "$SNAP_NAME" --metadata
```

> ⚠️ **Do not** leave the VM running on the overlay file long-term.
> Overlays grow unbounded and are not suitable as permanent disk images.

### ✅ Verify Active Disk Is Back to the Base Image

```bash
# Source must point back to the original .qcow2, not an overlay
virsh domblklist AgHost-1A --details
```

Expected — Source column reverts to the original path:
```
Type   Device  Target  Source
------------------------------------------------
file   disk    vda     /var/lib/libvirt/images/AgHost-1A.qcow2
```

```bash
# Confirm no backing file (overlay chain is fully collapsed)
qemu-img info /var/lib/libvirt/images/AgHost-1A.qcow2 | grep -E 'backing|format|image'
```

Expected:
```
image: AgHost-1A.qcow2
file format: qcow2
backing file: <none>       ← overlay fully merged
```

### ✅ Verify SQL Server Is Healthy After Thaw

```powershell
# On AgHost-1A — confirm SQL Server is running and accessible
Invoke-Sqlcmd -Query "SELECT @@SERVERNAME AS ServerName, GETDATE() AS CurrentTime, @@VERSION AS Version"

# Check all databases are ONLINE
Invoke-Sqlcmd -Query "SELECT name, state_desc FROM sys.databases ORDER BY name"
```

All user databases should show `state_desc = ONLINE`. If any show `SUSPECT` or `RECOVERY`, the VSS freeze did not complete cleanly.

---

## Step 7 — Validate Backup Recoverability (Restore Test)

> This is the most important validation step. A backup that cannot be restored is worthless.

### 7.1 Mount the Backup Image on ryzen9

```bash
# Load the NBD module
sudo modprobe nbd max_part=8

# Attach the backup qcow2 as a block device
sudo qemu-nbd --connect=/dev/nbd0 /backup/AgHost-1A/AgHost-1A-base-<date>.qcow2

# List partitions inside the image
sudo fdisk -l /dev/nbd0
```

### 7.2 Mount the Windows Partition Read-Only

```bash
# Windows Server typically places data on partition 3 or 4 — check fdisk output first
sudo mkdir -p /mnt/AgHost-1A-backup
sudo mount -o ro,offset=... /dev/nbd0p3 /mnt/AgHost-1A-backup

# Confirm SQL Server data files are present
ls -lh "/mnt/AgHost-1A-backup/Program Files/Microsoft SQL Server/"
```

### 7.3 ✅ Verify SQL Data File Consistency Using sqlcmd (Optional — Requires Attach)

If you have a separate test SQL Server instance, you can attach the MDF/LDF files directly:

```sql
-- Run on a separate SQL Server test instance
USE master;
GO
CREATE DATABASE [TestRestore]
  ON (FILENAME = 'E:\restored\YourDB.mdf'),
     (FILENAME = 'E:\restored\YourDB_log.ldf')
  FOR ATTACH;
GO

-- Verify data integrity
DBCC CHECKDB('TestRestore') WITH NO_INFOMSGS, ALL_ERRORMSGS;
GO
```

### 7.4 ✅ Clean Up After Restore Test

```bash
# Unmount and disconnect
sudo umount /mnt/AgHost-1A-backup
sudo qemu-nbd --disconnect /dev/nbd0
```

---

## Automation Script (ryzen9)

Save as `/usr/local/bin/AgHost-1A-vss-backup.sh`:

```bash
#!/bin/bash
set -euo pipefail

VM_NAME="AgHost-1A"
BACKUP_DIR="/backup/AgHost-1A"
SNAP_NAME="${VM_NAME}-vss-$(date +%Y%m%d-%H%M%S)"
DISK_TARGET="vda"
BASE_IMAGE="/var/lib/libvirt/images/AgHost-1A.qcow2"

mkdir -p "$BACKUP_DIR"

# --- Pre-flight checks ---
echo "[0/6] Running pre-flight checks..."
virsh domstate "$VM_NAME" | grep -q "running" || { echo "❌ VM is not running. Aborting."; exit 1; }
virsh qemu-agent-command "$VM_NAME" '{"execute":"guest-info"}' > /dev/null 2>&1 \
  || { echo "❌ Guest agent not responding. Aborting."; exit 1; }
qemu-img check "$BASE_IMAGE" > /dev/null \
  || { echo "❌ Base image has errors. Aborting."; exit 1; }
echo "✅ Pre-flight passed."

# --- Snapshot ---
echo "[1/6] Creating VSS-consistent snapshot: $SNAP_NAME"
virsh snapshot-create-as "$VM_NAME" \
  --name "$SNAP_NAME" \
  --description "Automated VSS SQL Server backup" \
  --disk-only \
  --quiesce \
  --atomic

# Verify snapshot overlay exists
OVERLAY=$(virsh domblklist "$VM_NAME" | awk "/$DISK_TARGET/ {print \$2}")
[[ -f "$OVERLAY" ]] || { echo "❌ Overlay file not found after snapshot. Aborting."; exit 1; }
echo "✅ Snapshot overlay: $OVERLAY"

# --- Backup ---
echo "[2/6] Backing up base image..."
cp "$BASE_IMAGE" "$BACKUP_DIR/${SNAP_NAME}.qcow2"

echo "[3/6] Validating backup file integrity..."
qemu-img check "$BACKUP_DIR/${SNAP_NAME}.qcow2" \
  || { echo "❌ Backup image check failed!"; exit 1; }
echo "✅ Backup file integrity OK: $BACKUP_DIR/${SNAP_NAME}.qcow2"

# --- Blockcommit ---
echo "[4/6] Merging overlay back into base image..."
virsh blockcommit "$VM_NAME" "$DISK_TARGET" --active --verbose --pivot

# Verify active disk is back to base
ACTIVE_DISK=$(virsh domblklist "$VM_NAME" | awk "/$DISK_TARGET/ {print \$2}")
[[ "$ACTIVE_DISK" == "$BASE_IMAGE" ]] \
  || { echo "⚠️  Warning: active disk is $ACTIVE_DISK, not $BASE_IMAGE. Check manually."; }

# --- Cleanup ---
echo "[5/6] Removing snapshot metadata..."
virsh snapshot-delete "$VM_NAME" --snapshotname "$SNAP_NAME" --metadata

# --- Final validation ---
echo "[6/6] Final base image health check..."
qemu-img check "$BASE_IMAGE" \
  || { echo "⚠️  Base image check failed after blockcommit. Investigate immediately."; exit 1; }

echo "✅ Backup complete: $BACKUP_DIR/${SNAP_NAME}.qcow2"
```

```bash
chmod +x /usr/local/bin/AgHost-1A-vss-backup.sh
```

Schedule with cron (daily at 2 AM):

```bash
echo "0 2 * * * root /usr/local/bin/AgHost-1A-vss-backup.sh >> /var/log/AgHost-1A-backup.log 2>&1" \
  | sudo tee /etc/cron.d/AgHost-1A-vss-backup
```

---

## Verification & Validation Checklist

Use this as a go/no-go checklist at each stage of the process:

### Before Taking the Snapshot (Pre-flight)
- [ ] `virsh list --all` shows `AgHost-1A` in **running** state
- [ ] `virsh qemu-agent-command AgHost-1A '{"execute":"guest-info"}'` returns a JSON response
- [ ] `Get-Service QEMU-GA` on AgHost-1A shows **Running**
- [ ] `vssadmin list writers` shows `SqlServerWriter` in **Stable** state with **No error**
- [ ] `vssadmin list providers` shows the Microsoft Software Shadow Copy provider
- [ ] `qemu-img check AgHost-1A.qcow2` reports **No errors**
- [ ] Host has sufficient free disk space (`df -h /var/lib/libvirt/images/`)
- [ ] No active overlay/snapshot chain (`qemu-img info` shows no backing file)

### After Taking the Snapshot
- [ ] `virsh snapshot-list AgHost-1A` shows the new snapshot entry
- [ ] `virsh domblklist AgHost-1A` Source column points to an **overlay** file
- [ ] `qemu-img info <overlay>` shows correct **backing file** path
- [ ] Windows Event Viewer on `AgHost-1A` shows VSS events with **no errors** (Event IDs 8229, 8230)
- [ ] SQL Server is accessible after thaw — `SELECT @@SERVERNAME` returns a result
- [ ] All databases show `state_desc = ONLINE` in `sys.databases`

### After Backup Copy
- [ ] Backup file exists and is non-zero: `ls -lh /backup/AgHost-1A/`
- [ ] `qemu-img check <backup.qcow2>` reports **No errors**
- [ ] Backup file size is reasonable compared to the source disk

### After Blockcommit & Cleanup
- [ ] `virsh domblklist AgHost-1A` Source column is back to the **original `.qcow2`**
- [ ] `qemu-img info AgHost-1A.qcow2` shows **no backing file** (overlay fully merged)
- [ ] `qemu-img check AgHost-1A.qcow2` reports **No errors** on the live disk
- [ ] `virsh snapshot-list AgHost-1A` shows no leftover snapshot entries

### Restore Test (Periodic — Recommended Monthly)
- [ ] Backup `.qcow2` mounts successfully via `qemu-nbd`
- [ ] SQL Server `.mdf`/`.ldf` files are visible in the mounted partition
- [ ] `DBCC CHECKDB` on attached databases reports **no corruption**

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `--quiesce` fails with "unsupported" | Guest agent not running | Install/start `QEMU-GA` on AgHost-1A |
| `vssadmin list writers` shows SqlServerWriter as failed | SQL Writer service stopped | `net stop/start SQLWriter` |
| Snapshot created but data inconsistent | VSS freeze timed out | Check Windows Event Viewer → Application log for VSS errors |
| `blockcommit` fails | Overlay disk not found | Run `virsh domblklist AgHost-1A` to confirm overlay path |
| Mount shows NTFS errors | Snapshot taken without quiesce | Repeat with `--quiesce` enabled |
| `qemu-img check` fails on backup | I/O error during copy | Retry copy; check host disk health with `smartctl` |
| SQL databases in SUSPECT after thaw | VSS freeze/thaw interrupted | Run `DBCC CHECKDB` immediately; restore from backup if needed |

---

## References

- [libvirt Snapshot XML Format](https://libvirt.org/formatsnapshot.html)
- [QEMU Guest Agent Protocol](https://wiki.qemu.org/Features/GuestAgent)
- [Microsoft VSS Technical Reference](https://learn.microsoft.com/en-us/windows-server/storage/file-server/volume-shadow-copy-service)
- [SQL Server VSS Writer](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/vss-writer-sql-server)
- [VirtIO Win Guest Tools](https://github.com/virtio-win/virtio-win-pkg-scripts)
