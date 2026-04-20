using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using ArxOne.Win32.Vss;

namespace VssRequester.Restore;

// VssRestore.exe : Microsoft-standard VSS restore requester for SQL Server.
//
// Runs on the target VM (SqlPoc). Reads the writer_metadata/* and
// backup_components.xml produced by VssBackup.exe on the source, then:
//
//   1. InitializeForRestore(backup_components_xml)
//   2. For each DB component: SetSelectedForRestore(true), mark for
//      AdditionalRestores so SQL Server leaves the DB in RESTORING state
//   3. PreRestore    -> SQL Writer closes file handles
//   4. Copy MDF/LDF into their target paths (= paths the writer recorded
//      at backup time, loaded from the source writer metadata XML)
//      — per DB in parallel, auto-decompressing any .gz files produced
//      by VssBackup.exe --compress.
//   5. PostRestore   -> SQL Writer registers each DB in RESTORING state
//                      (no crash recovery because SetAdditionalRestores=true)
//
// Usage:
//   VssRestore.exe --input \\ryzen9\vss-transport\<ts>
//                  [--parallel N]
//                  [--source-instance NAME] [--target-instance NAME]
//                  [--rename "OrigDb=NewDb,Db2=Db2_Copy"]
//                  [--move-data "Db2=E:\DATA\Restored\"]
//                  [--move-log "Db2=E:\LOG\Restored\"]
//
// --rename     Accepted for API symmetry but no longer applied via
//              SetRestoreName — SQL Writer's PreRestore pre-attaches the
//              target DB under the original name and locks the MDF path,
//              which broke the requester's own Copy phase. The caller
//              (restore.py) issues ALTER DATABASE MODIFY NAME once the DB
//              is ONLINE, which is what the GUI and CLI already do. For
//              true side-by-side (live original preserved) use --attach-only.
//
// --move-data  Per-DB directory for data files (.mdf/.ndf). Calls AddNewTarget
// --move-log   per file-set before PreRestore so SQL Writer registers the DB
//              with the new physical location; the copy phase writes the files
//              to the new directory. Missing target directories are created.
//
// --attach-only  Comma list of DBs that bypass the SQL Writer restore flow:
//              snapshot files are still staged at the --move-data/--move-log
//              paths by the copy phase, but SetSelectedForRestore /
//              PreRestore / PostRestore are skipped for them. The caller
//              (restore.py) then runs CREATE DATABASE ... FOR ATTACH so the
//              new DB appears side-by-side with the still-live original —
//              without the SQL Writer silently relocating or overwriting it.
//
// Log chain from that point forward is driven by Apply-TLogs.ps1.

internal static class Program
{
    private static readonly Guid SqlServerWriterId =
        new("a65faa63-5ea8-4ebc-9dbd-a0c4db26912a");

    private static int Main(string[] args)
    {
        try
        {
            var opts = ParseArgs(args);
            Log($"=== VssRestore ===  input={opts.Input}");

            var bcXmlPath = Path.Combine(opts.Input, "backup_components.xml");
            if (!File.Exists(bcXmlPath))
                throw new FileNotFoundException("backup_components.xml missing", bcXmlPath);
            var bcXml = File.ReadAllText(bcXmlPath);

            // Load the source-side SQL writer metadata so we know the original
            // file paths for each component; the target writer may not yet have
            // the DBs registered so we cannot rely on its in-process metadata.
            var wmDir = Path.Combine(opts.Input, "writer_metadata");
            var sourceSql = LoadSourceSqlWriterMetadata(wmDir);
            Log($"Source writer metadata: {sourceSql.WriterName}  components={sourceSql.Components.Count}");

            // The SQL Writer uses COMPONENT/@logicalPath as the SQL instance
            // identifier for its PostRestore OLE DB connection. The backup was
            // taken on the source host, so logicalPath is the source machine
            // name; left unchanged, the writer on the target attempts to
            // connect back to the source and fails with login error 18456.
            // Rewrite it to the target instance path (local machine + optional
            // named-instance suffix) so the writer binds to the local DB.
            var sourceLogicalPath = opts.SourceInstance
                ?? DetectSourceLogicalPath(bcXml)
                ?? Environment.MachineName;
            var targetLogicalPath = opts.TargetInstance
                ?? Environment.MachineName;
            if (!string.Equals(sourceLogicalPath, targetLogicalPath, StringComparison.OrdinalIgnoreCase))
            {
                bcXml = RewriteLogicalPath(bcXml, sourceLogicalPath, targetLogicalPath);
                Log($"Rewrote logicalPath: '{sourceLogicalPath}' -> '{targetLogicalPath}'");
            }

            var factory = VssFactoryProvider.Default.GetVssFactory();
            using var bc = factory.CreateVssBackupComponents();
            bc.InitializeForRestore(bcXml);
            bc.GatherWriterMetadata();

            // SQL Writer (FileGroup components) exposes files through
            // IVssWMComponent.Files, not DatabaseFiles/DatabaseLogFiles.
            static IEnumerable<VssWMFileDescriptor> AllFiles(IVssWMComponent c) =>
                c.Files.Concat(c.DatabaseFiles).Concat(c.DatabaseLogFiles);

            // Selection is driven off the rewritten backup_components doc
            // (bc.WriterComponents) so the logicalPath passed to the VSS
            // SetSelectedForRestore/SetAdditionalRestores/SetFileRestoreStatus
            // calls matches what is now in the backup doc. File specs come
            // from the source writer metadata because the target's SQL Writer
            // does not yet know about the DB.
            var selected   = new List<(IVssComponent target, IVssWMComponent source)>();
            var attachOnly = new List<(IVssComponent target, IVssWMComponent source)>();
            foreach (var w in bc.WriterComponents.Where(x => x.WriterId == SqlServerWriterId))
            {
                foreach (var c in w.Components)
                {
                    if (opts.Databases.Count > 0 && !opts.Databases.Contains(c.ComponentName))
                    {
                        Log($"  SKIP {c.ComponentName} - not in --databases list");
                        continue;
                    }
                    var meta = sourceSql.Components.FirstOrDefault(
                        m => string.Equals(m.ComponentName, c.ComponentName, StringComparison.OrdinalIgnoreCase)
                          && string.Equals(
                                NormalizeForMatch(m.LogicalPath, sourceLogicalPath),
                                NormalizeForMatch(c.LogicalPath, targetLogicalPath),
                                StringComparison.OrdinalIgnoreCase));
                    if (meta == null)
                    {
                        Log($"  SKIP {c.ComponentName} - not present in source writer metadata");
                        continue;
                    }
                    if (opts.AttachOnly.Contains(c.ComponentName))
                    {
                        attachOnly.Add((c, meta));
                        Log($"  ~ {c.ComponentName}  (attach-only: files staged at move paths, writer flow skipped)");
                        continue;
                    }
                    bc.SetSelectedForRestore(w.WriterId, c.ComponentType,
                        c.LogicalPath, c.ComponentName, true);
                    // SetAdditionalRestores(true) leaves the DB in RESTORING so a
                    // caller can RESTORE LOG WITH NORECOVERY to bridge the chain.
                    // For in-place rename-only / relocate-only flows (no
                    // --attach-only) we keep the RESTORING behaviour; side-by-
                    // side DBs take the --attach-only path above and never
                    // reach this branch.
                    bc.SetAdditionalRestores(w.WriterId, c.ComponentType,
                        c.LogicalPath, c.ComponentName, true);
                    selected.Add((c, meta));
                    Log($"  + {c.ComponentName}  type={c.ComponentType}  files={AllFiles(meta).Count()}  logicalPath='{c.LogicalPath}'");
                }
            }
            if (selected.Count == 0 && attachOnly.Count == 0)
                throw new InvalidOperationException("No matching SQL Writer components selected for restore");

            // ── Build per-file target plan (move-data / move-log), then call
            //    AddNewTarget before PreRestore so SQL Writer registers the DB
            //    with the alternate location. Also call SetRestoreName for any
            //    DBs being renamed. The fileTargets dict is consumed by the
            //    copy phase to write bytes to the new directory.
            // Rename note: SetRestoreName is intentionally NOT called here.
            // When the original DB is dropped before restore (the overwrite
            // flow), SQL Writer PreRestore pre-attaches the target DB under
            // the original component name and holds file handles on the MDF
            // — calling SetRestoreName to target a new name made that pre-
            // attach step lock the source copy path, and the requester's
            // Copy phase then failed with "file in use". The caller
            // (restore.py) issues ALTER DATABASE MODIFY NAME after the DB is
            // ONLINE, which reliably renames the DB on the target. True
            // side-by-side (live original preserved) is handled via
            // --attach-only, which bypasses the writer flow entirely.
            var fileTargets = new Dictionary<(string comp, string path, string spec), string>(
                new FileKeyComparer());
            foreach (var (c, meta) in selected)
            {
                opts.MoveData.TryGetValue(c.ComponentName, out var dataDir);
                opts.MoveLog .TryGetValue(c.ComponentName, out var logDir);
                if (dataDir == null && logDir == null) continue;
                foreach (var f in AllFiles(meta))
                {
                    string? altDir = null;
                    if (dataDir != null && IsDataFile(f.FileSpecification)) altDir = dataDir;
                    else if (logDir != null && IsLogFile (f.FileSpecification)) altDir = logDir;
                    if (altDir == null) continue;
                    altDir = TrimTrailingSlash(altDir);
                    Directory.CreateDirectory(altDir);
                    bc.AddNewTarget(SqlServerWriterId, c.ComponentType,
                        c.LogicalPath, c.ComponentName,
                        f.Path, f.FileSpecification, recursive: false, altDir);
                    fileTargets[(c.ComponentName, f.Path, f.FileSpecification)] = altDir;
                    Log($"    move  {c.ComponentName}  {f.Path}\\{f.FileSpecification}  ->  {altDir}");
                }
            }

            // Attach-only components: populate fileTargets from --move-data /
            // --move-log directly (no AddNewTarget / SetRestoreName calls
            // because those are bound to the writer's restore plan, which we
            // are deliberately NOT joining for these components). The copy
            // phase below consumes fileTargets for the destination path.
            foreach (var (c, meta) in attachOnly)
            {
                opts.MoveData.TryGetValue(c.ComponentName, out var dataDir);
                opts.MoveLog .TryGetValue(c.ComponentName, out var logDir);
                foreach (var f in AllFiles(meta))
                {
                    string? altDir = IsDataFile(f.FileSpecification) ? dataDir
                                   : IsLogFile (f.FileSpecification) ? logDir
                                   : null;
                    if (altDir == null)
                        throw new InvalidOperationException(
                            $"attach-only '{c.ComponentName}': file '{f.FileSpecification}' "
                          + "has no --move-data/--move-log directory; cannot stage.");
                    altDir = TrimTrailingSlash(altDir);
                    Directory.CreateDirectory(altDir);
                    fileTargets[(c.ComponentName, f.Path, f.FileSpecification)] = altDir;
                    Log($"    stage {c.ComponentName}  {f.Path}\\{f.FileSpecification}  ->  {altDir}  (attach-only)");
                }
            }

            if (selected.Count > 0)
            {
                bc.PreRestore();
                Log("PreRestore complete");
            }
            else
            {
                Log("PreRestore skipped (all components are attach-only)");
            }

            // Copy files from share back to the paths SQL Writer recorded at backup time.
            // Per-DB in parallel; decompress .gz transparently (files produced by
            // VssBackup.exe --compress).
            var copySw = System.Diagnostics.Stopwatch.StartNew();
            long totalSrc = 0, totalDst = 0;
            var degree  = opts.Parallel > 0 ? opts.Parallel : 1;
            Log($"Copy phase starting: parallel={degree}");
            var parOpts = new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, degree) };
            var allCopy = selected.Concat(attachOnly).ToList();
            Parallel.ForEach(allCopy, parOpts, tuple =>
            {
                var (c, meta) = tuple;
                var dbDir = Path.Combine(opts.Input, c.ComponentName);
                long dbSrc = 0, dbDst = 0;
                var dbSw = System.Diagnostics.Stopwatch.StartNew();
                foreach (var f in AllFiles(meta))
                {
                    // f.Path = directory, f.FileSpec = filename (usually literal for SQL).
                    // Honor move-data / move-log plan if set; fallback to f.Path.
                    var dstDir = fileTargets.TryGetValue((c.ComponentName, f.Path, f.FileSpecification), out var alt)
                        ? alt : f.Path;
                    Directory.CreateDirectory(dstDir);
                    // Prefer .gz if present; fall back to the literal filename.
                    var gzMatches    = Directory.EnumerateFiles(dbDir, f.FileSpecification + ".gz").ToList();
                    var plainMatches = Directory.EnumerateFiles(dbDir, f.FileSpecification).ToList();
                    if (gzMatches.Count > 0)
                    {
                        foreach (var srcMatch in gzMatches)
                        {
                            var baseName = Path.GetFileName(srcMatch);
                            if (baseName.EndsWith(".gz", StringComparison.OrdinalIgnoreCase))
                                baseName = baseName[..^3];
                            var dst = Path.Combine(dstDir, baseName);
                            var srcLen = new FileInfo(srcMatch).Length;
                            Log($"  [{c.ComponentName}] decompress {srcMatch}  ->  {dst}");
                            DecompressFile(srcMatch, dst);
                            var dstLen = new FileInfo(dst).Length;
                            System.Threading.Interlocked.Add(ref totalSrc, srcLen);
                            System.Threading.Interlocked.Add(ref totalDst, dstLen);
                            dbSrc += srcLen; dbDst += dstLen;
                        }
                    }
                    else
                    {
                        foreach (var srcMatch in plainMatches)
                        {
                            var dst = Path.Combine(dstDir, Path.GetFileName(srcMatch));
                            var srcLen = new FileInfo(srcMatch).Length;
                            Log($"  [{c.ComponentName}] copy {srcMatch}  ->  {dst}");
                            BufferedCopy(srcMatch, dst);
                            var dstLen = new FileInfo(dst).Length;
                            System.Threading.Interlocked.Add(ref totalSrc, srcLen);
                            System.Threading.Interlocked.Add(ref totalDst, dstLen);
                            dbSrc += srcLen; dbDst += dstLen;
                        }
                    }
                }
                dbSw.Stop();
                var mbps = dbSw.Elapsed.TotalSeconds > 0 ? (dbDst / 1048576.0) / dbSw.Elapsed.TotalSeconds : 0;
                Log($"  [{c.ComponentName}] done in {dbSw.Elapsed.TotalSeconds:F1}s  in={dbSrc / 1048576.0:F0}MB  out={dbDst / 1048576.0:F0}MB  {mbps:F0} MB/s out");
            });
            copySw.Stop();
            var totalMbps = copySw.Elapsed.TotalSeconds > 0 ? (totalDst / 1048576.0) / copySw.Elapsed.TotalSeconds : 0;
            Log($"Copy phase: {copySw.Elapsed.TotalSeconds:F1}s  in={totalSrc / 1048576.0:F0}MB  out={totalDst / 1048576.0:F0}MB  {totalMbps:F0} MB/s out aggregate");

            // SetFileRestoreStatus is a COM call on bc -> keep serial. Only
            // for components that went through the writer flow; attach-only
            // components are registered by the caller via CREATE ... FOR ATTACH.
            foreach (var (c, _) in selected)
                bc.SetFileRestoreStatus(SqlServerWriterId, c.ComponentType,
                    c.LogicalPath, c.ComponentName, VssFileRestoreStatus.All);

            if (selected.Count > 0)
            {
                bc.PostRestore();
                Log("PostRestore complete -> DBs should be in RESTORING state");
            }
            else
            {
                Log("PostRestore skipped (all components are attach-only)");
            }

            Console.WriteLine("OK");
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"FAIL: {ex.GetType().Name}: {ex.Message}");
            Console.Error.WriteLine(ex.StackTrace);
            return 2;
        }
    }

    private static IVssExamineWriterMetadata LoadSourceSqlWriterMetadata(string wmDir)
    {
        if (!Directory.Exists(wmDir))
            throw new DirectoryNotFoundException($"writer_metadata dir missing: {wmDir}");
        var factory = VssFactoryProvider.Default.GetVssFactory();
        foreach (var xmlFile in Directory.EnumerateFiles(wmDir, "*.xml"))
        {
            var ewm = factory.CreateVssExamineWriterMetadata(File.ReadAllText(xmlFile));
            if (ewm.WriterId == SqlServerWriterId)
                return ewm;
        }
        throw new InvalidOperationException("SQL Writer metadata XML not found in " + wmDir);
    }

    private record Options(
        string Input,
        string? SourceInstance,
        string? TargetInstance,
        int Parallel,
        IReadOnlyDictionary<string, string> Rename,
        IReadOnlyDictionary<string, string> MoveData,
        IReadOnlyDictionary<string, string> MoveLog,
        IReadOnlySet<string> AttachOnly,
        IReadOnlySet<string> Databases);

    private static Options ParseArgs(string[] args)
    {
        string? input = null;
        string? srcInst = null;
        string? tgtInst = null;
        int? parallel = null;
        string? rename = null, moveData = null, moveLog = null, attachOnly = null, databases = null;
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--input":            input      = args[++i]; break;
                case "--source-instance":  srcInst    = args[++i]; break;
                case "--target-instance":  tgtInst    = args[++i]; break;
                case "--parallel":         parallel   = int.Parse(args[++i]); break;
                case "--rename":           rename     = args[++i]; break;
                case "--move-data":        moveData   = args[++i]; break;
                case "--move-log":         moveLog    = args[++i]; break;
                case "--attach-only":      attachOnly = args[++i]; break;
                case "--databases":        databases  = args[++i]; break;
                default: throw new ArgumentException($"Unknown arg: {args[i]}");
            }
        }
        if (input == null)
            throw new ArgumentException(
                "Usage: VssRestore --input <share-path> [--source-instance <name>] "
              + "[--target-instance <name>] [--parallel N] "
              + "[--rename Orig=New,...] [--move-data Db=Dir,...] [--move-log Db=Dir,...] "
              + "[--attach-only Db1,Db2,...] [--databases Db1,Db2,...]");
        return new Options(input, srcInst, tgtInst, parallel ?? 0,
            ParseMap(rename), ParseMap(moveData), ParseMap(moveLog),
            ParseSet(attachOnly), ParseSet(databases));
    }

    // Parse "a,b,c" into a case-insensitive set. Empty entries are skipped.
    private static IReadOnlySet<string> ParseSet(string? s)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(s)) return set;
        foreach (var tok in s.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            set.Add(tok);
        return set;
    }

    // Parse "key1=val1,key2=val2" into a case-insensitive dictionary. Empty
    // or malformed pairs are skipped. Trailing backslashes on directory
    // values are normalized.
    private static IReadOnlyDictionary<string, string> ParseMap(string? s)
    {
        var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(s)) return d;
        foreach (var pair in s.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var eq = pair.IndexOf('=');
            if (eq <= 0 || eq == pair.Length - 1) continue;
            var k = pair[..eq].Trim();
            var v = pair[(eq + 1)..].Trim();
            if (k.Length == 0 || v.Length == 0) continue;
            d[k] = v;
        }
        return d;
    }

    // Classify a SQL Writer file spec by extension so --move-data only
    // matches .mdf/.ndf and --move-log only matches .ldf. SQL Writer
    // registers literal filenames so we can rely on the extension.
    private static bool IsDataFile(string fileSpec) =>
        fileSpec.EndsWith(".mdf", StringComparison.OrdinalIgnoreCase) ||
        fileSpec.EndsWith(".ndf", StringComparison.OrdinalIgnoreCase);

    private static bool IsLogFile(string fileSpec) =>
        fileSpec.EndsWith(".ldf", StringComparison.OrdinalIgnoreCase);

    // Normalize a directory-style path so AddNewTarget receives it with a
    // trailing backslash-free form (VSS does not require trailing slash).
    private static string TrimTrailingSlash(string p) =>
        p.TrimEnd('\\', '/');

    // Case-insensitive key comparer for (component, path, spec) tuples used
    // to index the per-file move-data/move-log plan.
    private sealed class FileKeyComparer : IEqualityComparer<(string comp, string path, string spec)>
    {
        public bool Equals((string comp, string path, string spec) x, (string comp, string path, string spec) y) =>
            string.Equals(x.comp, y.comp, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(x.path, y.path, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(x.spec, y.spec, StringComparison.OrdinalIgnoreCase);
        public int GetHashCode((string comp, string path, string spec) o) =>
            HashCode.Combine(
                StringComparer.OrdinalIgnoreCase.GetHashCode(o.comp),
                StringComparer.OrdinalIgnoreCase.GetHashCode(o.path),
                StringComparer.OrdinalIgnoreCase.GetHashCode(o.spec));
    }

    // 1 MB buffers: good throughput over SMB for multi-GB SQL files.
    private const int CopyBuf = 1 << 20;

    private static void BufferedCopy(string src, string dst)
    {
        using var sin  = new FileStream(src, FileMode.Open,   FileAccess.Read,  FileShare.Read, CopyBuf, FileOptions.SequentialScan);
        using var sout = new FileStream(dst, FileMode.Create, FileAccess.Write, FileShare.None, CopyBuf);
        sin.CopyTo(sout, CopyBuf);
    }

    private static void DecompressFile(string srcGz, string dst)
    {
        using var fin  = new FileStream(srcGz, FileMode.Open,   FileAccess.Read,  FileShare.Read, CopyBuf, FileOptions.SequentialScan);
        using var gz   = new GZipStream(fin, CompressionMode.Decompress, leaveOpen: false);
        using var sout = new FileStream(dst,   FileMode.Create, FileAccess.Write, FileShare.None, CopyBuf);
        gz.CopyTo(sout, CopyBuf);
    }

    // Scan the backup components XML for the first SQL Writer
    // COMPONENT/@logicalPath, which (for the SQL Writer) is the source
    // instance identifier. Returns null if not found.
    private static string? DetectSourceLogicalPath(string bcXml)
    {
        var m = Regex.Match(bcXml, "logicalPath=\"([^\"]*)\"");
        return m.Success ? m.Groups[1].Value : null;
    }

    private static string RewriteLogicalPath(string bcXml, string from, string to)
    {
        var esc = Regex.Escape(from);
        return Regex.Replace(bcXml, $"logicalPath=\"{esc}\"", $"logicalPath=\"{to}\"");
    }

    // For matching a backup_components COMPONENT (target-rewritten) back to
    // its source writer_metadata COMPONENT, treat the logical path as equal
    // when it equals its side's instance identifier (default-instance case).
    private static string NormalizeForMatch(string? logicalPath, string selfInstance)
    {
        var lp = logicalPath ?? "";
        return string.Equals(lp, selfInstance, StringComparison.OrdinalIgnoreCase) ? "" : lp;
    }

    private static void Log(string m)
    {
        Console.WriteLine($"{DateTime.Now:HH:mm:ss} {m}");
        Console.Out.Flush();
    }
}

