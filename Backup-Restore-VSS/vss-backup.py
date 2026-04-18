#!/usr/bin/env python3
"""
vss-backup.py — KVM VSS snapshot + SqlPoc restore orchestrator.

Usage:
  python3 vss-backup.py [-d CDCDemo,Db2] [-r CDCDemo:CDCDemo_Restored] [-n]

Runs on: ryzen9 (Ubuntu KVM host). Requires pywinrm, virsh, and the
qemu-guest-agent (or WinRM) on the guest VMs.
"""
import argparse, subprocess, sys, time, os, datetime, shlex
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from winrm_helper import run_ps, push_file, run_file, HOSTS

SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
VM_SOURCE    = "AgHost-1A"
VM_TARGET    = "SqlPoc"
DISK_TARGET  = "vdc"
BACKUP_STORE = "/vm-storage-02/libvirt-images"
SOURCE_DISK  = "/vm-storage-01/AgHost-1A_E_Drive.qcow2"
REMOTE_SCRIPT_DIR = "C:\\Scripts"

def log(msg):
    print(f"[{datetime.datetime.now():%H:%M:%S}] {msg}", flush=True)

def sh(cmd, dry=False, check=True):
    if dry:
        print(f"DRY: {cmd}"); return 0, "", ""
    log(f"$ {cmd}")
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if r.stdout.strip(): print(r.stdout.rstrip())
    if r.stderr.strip(): print(r.stderr.rstrip(), file=sys.stderr)
    if check and r.returncode != 0:
        raise RuntimeError(f"cmd failed ({r.returncode}): {cmd}")
    return r.returncode, r.stdout, r.stderr

def ps_list(items):
    return "@(" + ",".join(f"'{x}'" for x in items) + ")"

def ps_hash(d):
    if not d: return "@{}"
    return "@{" + ";".join(f"{k}='{v}'" for k, v in d.items()) + "}"

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("-d", "--databases", default="CDCDemo,Db2,Facebook",
                   help="Comma-separated database list")
    p.add_argument("-r", "--rename", default="",
                   help="Rename map (SRC:TGT,SRC2:TGT2)")
    p.add_argument("-n", "--dry-run", action="store_true")
    p.add_argument("--skip-backup", action="store_true",
                   help="Skip pre-snapshot BACKUP DATABASE (snapshot only)")
    p.add_argument("--use-existing-qcow2", default="",
                   help="Use an existing qcow2 file (skip snapshot)")
    p.add_argument("--backup-ts", default="",
                   help="Backup timestamp to use (required with --use-existing-qcow2)")
    return p.parse_args()

def main():
    args = parse_args()
    dbs = [d.strip() for d in args.databases.split(",") if d.strip()]
    rename = {}
    if args.rename:
        for pair in args.rename.split(","):
            k, v = pair.split(":")
            rename[k.strip()] = v.strip()

    log(f"=== VSS Backup Orchestrator ===")
    log(f"Databases : {dbs}")
    log(f"Rename    : {rename or 'none'}")
    log(f"Dry-run   : {args.dry_run}")

    # ── Ensure scripts are pushed to both hosts ──────────────────────
    for fname, host in [
        ("Backup-Database-PreSnapshot.ps1", VM_SOURCE),
        ("Restore-FromVSSSnapshot.ps1",     VM_TARGET),
        ("Apply-TLogs.ps1",                 VM_TARGET),
    ]:
        remote = f"{REMOTE_SCRIPT_DIR}\\{fname}"
        log(f"Pushing {fname} -> {host}:{remote}")
        if not args.dry_run:
            push_file(host, os.path.join(SCRIPT_DIR, fname), remote)

    # ── Phase 1: Pre-snapshot BACKUP DATABASE ────────────────────────
    if args.use_existing_qcow2:
        backup_qcow2 = args.use_existing_qcow2
        backup_ts    = args.backup_ts
        log(f"Using existing qcow2: {backup_qcow2}  ts={backup_ts}")
    else:
        backup_ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        if not args.skip_backup:
            log(f"PHASE 1: Pre-snapshot BACKUP DATABASE on {VM_SOURCE} (ts={backup_ts})")
            if not args.dry_run:
                ps = f"& '{REMOTE_SCRIPT_DIR}\\Backup-Database-PreSnapshot.ps1' -Databases {ps_list(dbs)}"
                # Pin the timestamp so filenames align
                ps = ("$TS_OVERRIDE='" + backup_ts + "';"
                      "$dbs = " + ps_list(dbs) + ";"
                      "foreach ($db in $dbs) {"
                      " $bak = \"E:\\Backups\\${db}_${TS_OVERRIDE}.bak\";"
                      " Write-Host \"[$db] BACKUP -> $bak\";"
                      " if (-not (Test-Path 'E:\\Backups')) { New-Item -ItemType Directory 'E:\\Backups' | Out-Null }"
                      " Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password 'Pa$$w0rd'"
                      " -QueryTimeout 900 -ErrorAction Stop"
                      " -Query \"BACKUP DATABASE [$db] TO DISK = N'$bak' WITH COMPRESSION, CHECKSUM, STATS=10;\";"
                      " Write-Host \"[$db] OK\""
                      "}")
                out, err, rc = run_ps(VM_SOURCE, ps)
                print(out)
                if rc != 0:
                    print("ERR:", err[:500], file=sys.stderr); sys.exit(1)

        # ── Phase 2: VSS snapshot ────────────────────────────────────
        snap_name = f"{VM_SOURCE}-edrv-{datetime.datetime.now():%Y%m%d-%H%M%S}"
        log(f"PHASE 2: VSS snapshot {snap_name}")
        sh(f"sudo virsh snapshot-create-as {VM_SOURCE} --name {snap_name} "
           f"--description 'VSS edrv snapshot' "
           f"--diskspec vda,snapshot=no --diskspec vdb,snapshot=no "
           f"--diskspec {DISK_TARGET},snapshot=external "
           f"--disk-only --quiesce --atomic", dry=args.dry_run)

        # Phase 3: rsync qcow2
        backup_qcow2 = f"{BACKUP_STORE}/{VM_SOURCE}_E_Drive-{snap_name}.qcow2"
        log(f"PHASE 3: rsync base image -> {backup_qcow2}")
        sh(f"sudo rsync -avhP {SOURCE_DISK} {backup_qcow2}", dry=args.dry_run)
        sh(f"sudo qemu-img check {backup_qcow2}", dry=args.dry_run, check=False)

        # Blockcommit overlay back into base
        log("Blockcommit overlay back into base disk")
        sh(f"sudo virsh blockcommit {VM_SOURCE} {DISK_TARGET} --active --pivot",
           dry=args.dry_run)
        sh(f"sudo virsh snapshot-delete {VM_SOURCE} --snapshotname {snap_name} --metadata",
           dry=args.dry_run, check=False)
        overlay = SOURCE_DISK.rsplit(".", 1)[0] + "." + snap_name
        sh(f"sudo rm -f {overlay}", dry=args.dry_run, check=False)

    # ── Phase 4: Attach snapshot to SqlPoc ───────────────────────────
    log(f"PHASE 4: Attach {backup_qcow2} to {VM_TARGET} as vdd (read-only)")
    xml = (f"<disk type='file' device='disk'>\n"
           f"  <driver name='qemu' type='qcow2'/>\n"
           f"  <source file='{backup_qcow2}'/>\n"
           f"  <target dev='vdd' bus='virtio'/>\n"
           f"  <readonly/>\n"
           f"</disk>\n")
    with open("/tmp/attach-vdd.xml", "w") as f: f.write(xml)
    sh(f"sudo virsh attach-device {VM_TARGET} /tmp/attach-vdd.xml --live", dry=args.dry_run)
    time.sleep(5)

    # ── Phase 5: Bring T: online + RESTORE ───────────────────────────
    log("PHASE 5: Bring T: online on SqlPoc + RESTORE WITH NORECOVERY")
    if not args.dry_run:
        mount_script = (
            "$d=Get-Disk|?{$_.OperationalStatus -eq 'Offline' -and $_.Size -gt 10GB}|Select -First 1;"
            "if(-not $d){$d=Get-Disk|?{$_.IsReadOnly -and $_.Size -gt 10GB -and $_.Number -ge 3}|Select -First 1};"
            "if($d){Set-Disk -Number $d.Number -IsOffline $false -ErrorAction SilentlyContinue;"
            "$p=Get-Partition -DiskNumber $d.Number|?{$_.Size -gt 1GB}|Select -First 1;"
            "if($p.DriveLetter -and $p.DriveLetter -ne 'T'){Remove-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber $p.PartitionNumber -AccessPath \"$($p.DriveLetter):\\\" -EA SilentlyContinue};"
            "if(-not $p.DriveLetter){Add-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber $p.PartitionNumber -AccessPath 'T:\\'};"
            "Write-Host \"T: mounted (Disk $($d.Number))\"}else{Write-Host 'No offline disk found'};"
            "Get-PSDrive T -EA SilentlyContinue | Out-String"
        )
        out, err, rc = run_ps(VM_TARGET, mount_script)
        print(out); 
        if rc != 0: print("MOUNT ERR:", err[:300], file=sys.stderr)

        # Run Restore-FromVSSSnapshot.ps1
        restore_args = (f"-Databases {ps_list(dbs)} "
                        f"-RenameMap {ps_hash(rename)} "
                        f"-BackupTimestamp '{backup_ts}'")
        out, err, rc = run_file(VM_TARGET, f"{REMOTE_SCRIPT_DIR}\\Restore-FromVSSSnapshot.ps1", restore_args)
        print(out)
        if rc != 0: print("RESTORE ERR:", err[:500], file=sys.stderr); sys.exit(1)

    # ── Phase 6: Detach ──────────────────────────────────────────────
    log("PHASE 6: Remove T: and detach vdd from SqlPoc")
    if not args.dry_run:
        detach_script = (
            "$d=Get-Disk|?{$_.IsReadOnly -and $_.Size -gt 10GB}|Select -First 1;"
            "if($d){$p=Get-Partition -DiskNumber $d.Number|?{$_.DriveLetter -eq 'T'};"
            "if($p){Remove-PartitionAccessPath -DiskNumber $d.Number -PartitionNumber $p.PartitionNumber -AccessPath 'T:\\'};"
            "Set-Disk -Number $d.Number -IsOffline $true}"
        )
        run_ps(VM_TARGET, detach_script)
    sh(f"sudo virsh detach-disk {VM_TARGET} vdd --live", dry=args.dry_run, check=False)

    log("=== Orchestration complete ===")
    log(f"Backup qcow2: {backup_qcow2}")
    log(f"Backup TS   : {backup_ts}")

if __name__ == "__main__":
    main()
