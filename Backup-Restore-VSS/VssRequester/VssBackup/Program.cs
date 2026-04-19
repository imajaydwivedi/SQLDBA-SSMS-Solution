using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Threading.Tasks;
using ArxOne.Win32.Vss;

namespace VssRequester.Backup;

// VssBackup.exe : Microsoft-standard VSS backup requester for SQL Server.
//
// Runs on the source VM (AgHost-1A). For each selected database:
//   1. Ask VSS SQL Writer to freeze the DB (DoSnapshotSet)
//   2. Copy MDF+LDF from the shadow-copy volume to the transport share
//      (per-DB in parallel, optionally gzip-compressed on the fly)
//   3. Persist the writer metadata XML so the restore requester can call
//      PreRestore/PostRestore with SetAdditionalRestores(true)
//
// Usage:
//   VssBackup.exe --databases CDCDemo,Db2 --output \\ryzen9\vss-transport\<ts>
//                 [--compress] [--parallel N] [--copy-only]
//
// --copy-only uses VSS_BT_COPY (VssBackupType.Copy), which tells SQL Writer
// not to update each database's backup history / differential base. This is
// the standard knob to use when taking a VSS snapshot alongside an existing
// backup schedule, so the other backup chain (e.g. nightly full + log ship)
// is not broken.

internal static class Program
{
    private static readonly Guid SqlServerWriterId =
        new("a65faa63-5ea8-4ebc-9dbd-a0c4db26912a");

    private static int Main(string[] args)
    {
        try
        {
            var opts = ParseArgs(args);
            var backupType = opts.CopyOnly ? VssBackupType.Copy : VssBackupType.Full;
            Log($"=== VssBackup ===  dbs=[{string.Join(",", opts.Databases)}]  output={opts.Output}  compress={opts.Compress}  parallel={opts.Parallel}  type={backupType}");
            Directory.CreateDirectory(opts.Output);

            var factory = VssFactoryProvider.Default.GetVssFactory();
            using var bc = factory.CreateVssBackupComponents();
            bc.InitializeForBackup(null);
            bc.SetBackupState(
                selectComponents: true,
                backupBootableSystemState: false,
                backupType: backupType,
                partialFileSupport: false);
            bc.SetContext(VssSnapshotContext.Backup);
            bc.GatherWriterMetadata();

            var sql = bc.WriterMetadata.FirstOrDefault(w => w.WriterId == SqlServerWriterId)
                      ?? throw new InvalidOperationException("SQL Server VSS Writer not found");
            Log($"Writer: {sql.WriterName}  components={sql.Components.Count}");

            var selected = new List<IVssWMComponent>();
            foreach (var db in opts.Databases)
            {
                var comp = sql.Components.FirstOrDefault(
                    c => string.Equals(c.ComponentName, db, StringComparison.OrdinalIgnoreCase));
                if (comp == null)
                    throw new InvalidOperationException($"DB '{db}' not found as a SQL Writer component");
                bc.AddComponent(sql.InstanceId, sql.WriterId, comp.Type, comp.LogicalPath, comp.ComponentName);
                selected.Add(comp);
                Log($"  + {db}  type={comp.Type}  files={comp.Files.Count + comp.DatabaseFiles.Count + comp.DatabaseLogFiles.Count}");
            }

            // SQL Writer exposes MDF/LDF through IVssWMComponent.Files (FileGroup type).
            // DatabaseFiles/DatabaseLogFiles are used only by Database-type writers.
            static IEnumerable<VssWMFileDescriptor> AllFiles(IVssWMComponent c) =>
                c.Files.Concat(c.DatabaseFiles).Concat(c.DatabaseLogFiles);

            var volumes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var c in selected)
                foreach (var f in AllFiles(c))
                    volumes.Add(Path.GetPathRoot(f.Path)!.TrimEnd('\\') + "\\");
            Log($"Volumes to snapshot: [{string.Join(",", volumes)}]");

            Guid snapshotSetId = bc.StartSnapshotSet();
            var volToSnap = new Dictionary<string, Guid>(StringComparer.OrdinalIgnoreCase);
            foreach (var v in volumes)
            {
                var id = bc.AddToSnapshotSet(v, Guid.Empty);
                volToSnap[v] = id;
                Log($"Snapshot queued: {v}  id={id}");
            }

            bc.PrepareForBackup();
            bc.DoSnapshotSet();
            Log("DoSnapshotSet complete");

            var snapPath = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var kv in volToSnap)
            {
                var snap = bc.GetSnapshotProperties(kv.Value);
                snapPath[kv.Key] = snap.SnapshotDeviceObject;
                Log($"Shadow: {kv.Key} -> {snap.SnapshotDeviceObject}");
            }

            var copySw = System.Diagnostics.Stopwatch.StartNew();
            long totalSrc = 0, totalDst = 0;
            var parOpts = new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, opts.Parallel) };
            Parallel.ForEach(selected, parOpts, c =>
            {
                var dbDir = Path.Combine(opts.Output, c.ComponentName);
                Directory.CreateDirectory(dbDir);
                long dbSrc = 0, dbDst = 0;
                var dbSw = System.Diagnostics.Stopwatch.StartNew();
                foreach (var f in AllFiles(c))
                {
                    // f.Path is the directory (e.g. "E:\...\DATA");
                    // f.FileSpec is the filename/wildcard (e.g. "Db2.mdf" or "*.mdf").
                    var vol      = Path.GetPathRoot(f.Path)!.TrimEnd('\\') + "\\";
                    var relDir   = f.Path.Substring(vol.Length);
                    var snapDir  = Path.Combine(snapPath[vol], relDir);
                    foreach (var match in Directory.EnumerateFiles(snapDir, f.FileSpecification))
                    {
                        var name = Path.GetFileName(match);
                        var dst  = Path.Combine(dbDir, opts.Compress ? name + ".gz" : name);
                        var srcLen = new FileInfo(match).Length;
                        Log($"  [{c.ComponentName}] copy {match}  ->  {dst}");
                        if (opts.Compress)
                            CompressFile(match, dst);
                        else
                            BufferedCopy(match, dst);
                        var dstLen = new FileInfo(dst).Length;
                        System.Threading.Interlocked.Add(ref totalSrc, srcLen);
                        System.Threading.Interlocked.Add(ref totalDst, dstLen);
                        dbSrc += srcLen; dbDst += dstLen;
                    }
                }
                dbSw.Stop();
                var mbps = dbSw.Elapsed.TotalSeconds > 0 ? (dbSrc / 1048576.0) / dbSw.Elapsed.TotalSeconds : 0;
                var ratio = dbSrc > 0 ? (double)dbDst / dbSrc : 1.0;
                Log($"  [{c.ComponentName}] done in {dbSw.Elapsed.TotalSeconds:F1}s  src={dbSrc / 1048576.0:F0}MB  dst={dbDst / 1048576.0:F0}MB  ratio={ratio:F2}  {mbps:F0} MB/s");
            });
            copySw.Stop();
            var totalMbps = copySw.Elapsed.TotalSeconds > 0 ? (totalSrc / 1048576.0) / copySw.Elapsed.TotalSeconds : 0;
            var totalRatio = totalSrc > 0 ? (double)totalDst / totalSrc : 1.0;
            Log($"Copy phase: {copySw.Elapsed.TotalSeconds:F1}s  src={totalSrc / 1048576.0:F0}MB  dst={totalDst / 1048576.0:F0}MB  ratio={totalRatio:F2}  {totalMbps:F0} MB/s aggregate");

            File.WriteAllText(Path.Combine(opts.Output, "backup_components.xml"), bc.SaveAsXml());
            var wmDir = Path.Combine(opts.Output, "writer_metadata");
            Directory.CreateDirectory(wmDir);
            foreach (var w in bc.WriterMetadata)
                File.WriteAllText(Path.Combine(wmDir, $"{w.WriterId}_{w.InstanceId}.xml"), w.SaveAsXml());
            Log("Writer metadata persisted");

            foreach (var c in selected)
                bc.SetBackupSucceeded(sql.InstanceId, sql.WriterId, c.Type, c.LogicalPath, c.ComponentName, true);
            bc.BackupComplete();
            Log("BackupComplete  -> shadow released");

            Console.WriteLine($"OK output={opts.Output}");
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"FAIL: {ex.GetType().Name}: {ex.Message}");
            Console.Error.WriteLine(ex.StackTrace);
            return 2;
        }
    }

    private record Options(IReadOnlyList<string> Databases, string Output, bool Compress, int Parallel, bool CopyOnly);

    private static Options ParseArgs(string[] args)
    {
        string? dbs = null, output = null;
        bool compress = false;
        bool copyOnly = false;
        int? parallel = null;
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--databases": dbs      = args[++i]; break;
                case "--output":    output   = args[++i]; break;
                case "--compress":  compress = true; break;
                case "--copy-only": copyOnly = true; break;
                case "--parallel":  parallel = int.Parse(args[++i]); break;
                default: throw new ArgumentException($"Unknown arg: {args[i]}");
            }
        }
        if (dbs == null || output == null)
            throw new ArgumentException(
                "Usage: VssBackup --databases X,Y --output <share-path> [--compress] [--copy-only] [--parallel N]");
        var dbList = dbs.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var par = parallel ?? 1;
        return new Options(dbList, output, compress, par, copyOnly);
    }

    // 1 MB buffers: good throughput over SMB for multi-GB SQL files.
    private const int CopyBuf = 1 << 20;

    private static void BufferedCopy(string src, string dst)
    {
        using var sin  = new FileStream(src, FileMode.Open,   FileAccess.Read,  FileShare.Read, CopyBuf, FileOptions.SequentialScan);
        using var sout = new FileStream(dst, FileMode.Create, FileAccess.Write, FileShare.None, CopyBuf);
        sin.CopyTo(sout, CopyBuf);
    }

    private static void CompressFile(string src, string dstGz)
    {
        using var sin  = new FileStream(src,   FileMode.Open,   FileAccess.Read,  FileShare.Read, CopyBuf, FileOptions.SequentialScan);
        using var fout = new FileStream(dstGz, FileMode.Create, FileAccess.Write, FileShare.None, CopyBuf);
        using var gz   = new GZipStream(fout, CompressionLevel.Fastest, leaveOpen: false);
        sin.CopyTo(gz, CopyBuf);
    }

    private static void Log(string m)
    {
        Console.WriteLine($"{DateTime.Now:HH:mm:ss} {m}");
        Console.Out.Flush();
    }
}
