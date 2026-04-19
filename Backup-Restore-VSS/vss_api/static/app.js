/* VSS Backup & Restore — frontend logic */
"use strict";

let _servers = {};
let _ws      = null;
let _progressModal = null;
let _addServerModal = null;

// ── Bootstrap ─────────────────────────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", () => {
  _progressModal  = new bootstrap.Modal(document.getElementById("progressModal"));
  _addServerModal = new bootstrap.Modal(document.getElementById("addServerModal"));
  loadServers();
  loadSnapshots();
  document.getElementById("rstOverwrite")
          .addEventListener("change", refreshRestoreConflicts);
  setInterval(refreshRunningBadge, 4000);
});

// ── Servers ───────────────────────────────────────────────────────────────────
async function loadServers() {
  const r = await fetch("/api/servers");
  _servers = await r.json();
  renderSidebar();
  populateDropdowns();
  // Auto-populate the Backup tab's DB list for the pre-selected source.
  // /api/databases is now pyodbc-direct (~20 ms) so this does not delay
  // page render noticeably.
  const bkp = document.getElementById("bkpSource");
  if (bkp && bkp.value) loadDatabases("bkpSource", "bkpDbList");
}

function renderSidebar() {
  const el = document.getElementById("serverList");
  el.innerHTML = "";
  for (const [key, s] of Object.entries(_servers)) {
    const roleBadge = s.role === "source"
      ? '<span class="badge bg-info text-dark" style="font-size:9px">SOURCE</span>'
      : '<span class="badge bg-warning text-dark" style="font-size:9px">TARGET</span>';
    const delBtn = s.builtin ? ""
      : `<button class="btn btn-sm p-0 ms-auto text-danger" title="Remove"
              onclick="removeServer('${key}')"><i class="bi bi-x-circle"></i></button>`;
    el.innerHTML += `
      <div class="srv-card d-flex align-items-center gap-2">
        <i class="bi bi-server text-secondary" style="font-size:18px"></i>
        <div class="flex-grow-1" style="min-width:0">
          <div class="fw-semibold text-white" style="font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${key}</div>
          <div style="font-size:10px;color:#888">${s.ip}</div>
        </div>
        ${roleBadge}${delBtn}
      </div>`;
  }
}

function populateDropdowns() {
  ["bkpSource", "rstTarget", "rstTlogSource"].forEach(id => {
    const sel = document.getElementById(id);
    if (!sel) return;
    const prev = sel.value;
    sel.innerHTML = "";
    for (const key of Object.keys(_servers)) {
      sel.appendChild(new Option(key, key));
    }
    if (prev && sel.querySelector(`option[value="${prev}"]`)) {
      sel.value = prev;
    } else if (id === "rstTlogSource") {
      // Default the T-log source to the first server tagged "source"
      const src = Object.entries(_servers).find(([,s]) => s.role === "source");
      if (src) sel.value = src[0];
    }
  });
}

function openAddServer() { _addServerModal.show(); }

async function addServer() {
  const body = {
    key:  document.getElementById("srvKey").value.trim(),
    ip:   document.getElementById("srvIp").value.trim(),
    user: document.getElementById("srvUser").value.trim(),
    pwd:  document.getElementById("srvPwd").value,
    role: document.getElementById("srvRole").value,
  };
  if (!body.key || !body.ip) { alert("Name and IP are required."); return; }
  await fetch("/api/servers", { method: "POST",
    headers: {"Content-Type": "application/json"}, body: JSON.stringify(body) });
  _addServerModal.hide();
  loadServers();
}

async function removeServer(key) {
  if (!confirm(`Remove server '${key}'?`)) return;
  await fetch(`/api/servers/${encodeURIComponent(key)}`, { method: "DELETE" });
  loadServers();
}

// ── Databases ─────────────────────────────────────────────────────────────────
async function loadDatabases(srcId, listId) {
  const host = document.getElementById(srcId).value;
  if (!host) return;
  const el = document.getElementById(listId);
  el.innerHTML = '<div class="text-muted small p-1"><i class="bi bi-hourglass-split me-1"></i>Loading…</div>';
  try {
    const r = await fetch(`/api/databases?host=${encodeURIComponent(host)}`);
    if (!r.ok) throw new Error(await r.text());
    const dbs = await r.json();
    if (!dbs.length) { el.innerHTML = '<small class="text-muted">No user databases found</small>'; return; }
    el.innerHTML = dbs.map(db => `
      <div class="form-check py-0">
        <input class="form-check-input db-check" type="checkbox" value="${db.name}"
               id="chk_${listId}_${db.name}" checked>
        <label class="form-check-label d-flex align-items-center gap-2"
               for="chk_${listId}_${db.name}" style="font-size:13px">
          ${db.name}
          <span class="badge ${db.state==="ONLINE"?"bg-success":"bg-warning text-dark"}" style="font-size:9px">${db.state}</span>
          <span class="text-muted" style="font-size:10px">${db.recovery||""}</span>
        </label>
      </div>`).join("");
  } catch(e) {
    el.innerHTML = `<small class="text-danger"><i class="bi bi-exclamation-triangle me-1"></i>${e.message}</small>`;
  }
}

function getCheckedDbs(listId) {
  return [...document.querySelectorAll(`#${listId} .db-check:checked`)].map(c => c.value);
}
function selectAllDbs(id) { document.querySelectorAll(`#${id} .db-check`).forEach(c => c.checked=true); }
function clearAllDbs(id)  { document.querySelectorAll(`#${id} .db-check`).forEach(c => c.checked=false); }

// ── Snapshots ─────────────────────────────────────────────────────────────────
// The /api/snapshots endpoint returns rows already sorted by directory mtime
// (newest first). Each row carries created_at (formatted) + mtime (epoch).
async function loadSnapshots() {
  const r = await fetch("/api/snapshots");
  const snaps = await r.json();
  const sel = document.getElementById("rstSnapshot");
  if (!snaps.length) { sel.innerHTML = '<option value="">No snapshots found</option>'; return; }
  sel.innerHTML = snaps.map(s =>
    `<option value="${s.name}">${s.created_at} \u2014 ${s.name}  [${s.databases.join(", ")}]</option>`
  ).join("");
  loadSnapshotDbs();
}

async function loadSnapshotDbs() {
  const name = document.getElementById("rstSnapshot").value;
  const el   = document.getElementById("rstDbList");
  if (!name) return;
  const r = await fetch("/api/snapshots");
  const snaps = await r.json();
  const snap  = snaps.find(s => s.name === name);
  if (!snap || !snap.databases.length) {
    el.innerHTML = '<small class="text-muted">No databases in this snapshot</small>'; return;
  }
  el.innerHTML = snap.databases.map(db => `
    <div class="border rounded px-2 py-1 mb-1" data-orig="${db}">
      <div class="d-flex align-items-center gap-2">
        <div class="form-check mb-0" style="min-width:180px">
          <input class="form-check-input db-check" type="checkbox" value="${db}"
                 id="rst_db_${db}" checked onchange="refreshRestoreConflicts()">
          <label class="form-check-label" for="rst_db_${db}" style="font-size:13px">${db}</label>
        </div>
        <i class="bi bi-arrow-right text-muted"></i>
        <input type="text" class="form-control form-control-sm db-rename" value="${db}"
               data-orig="${db}" oninput="refreshRestoreConflicts()"
               placeholder="new name (edit to rename)"
               style="font-size:12px;max-width:220px">
      </div>
      <div class="d-flex align-items-center gap-1 mt-1 ms-4" style="font-size:11px">
        <i class="bi bi-hdd text-info" title="Relocate data files (.mdf/.ndf)"></i>
        <input type="text" class="form-control form-control-sm db-movedata"
               data-orig="${db}" placeholder="Move data dir (e.g. E:\\Data\\${db}_Copy\\) — optional"
               style="font-size:11px">
        <i class="bi bi-journal-text text-warning ms-2" title="Relocate log file (.ldf)"></i>
        <input type="text" class="form-control form-control-sm db-movelog"
               data-orig="${db}" placeholder="Move log dir (e.g. F:\\Log\\${db}_Copy\\) — optional"
               style="font-size:11px">
      </div>
    </div>`).join("");
  refreshRestoreConflicts();
}

// Map of {orig: dir} for --move-data / --move-log; empty inputs are skipped.
function collectDirMap(cssClass) {
  const m = {};
  document.querySelectorAll(`#rstDbList .db-check:checked`).forEach(chk => {
    const orig = chk.value;
    const inp  = document.querySelector(`#rstDbList .${cssClass}[data-orig="${orig}"]`);
    const v    = inp && inp.value.trim();
    if (v) m[orig] = v;
  });
  return m;
}

// Map of {orig_db_name: effective_name} — unchanged names are kept as orig
function collectEffectiveNames() {
  const map = {};
  document.querySelectorAll("#rstDbList .db-check:checked").forEach(chk => {
    const orig = chk.value;
    const inp  = document.querySelector(`#rstDbList .db-rename[data-orig="${orig}"]`);
    const newN = (inp && inp.value.trim()) || orig;
    map[orig] = newN;
  });
  return map;
}

// Return only real renames (orig != new)
function collectRenameMap() {
  const m = {};
  for (const [orig, nn] of Object.entries(collectEffectiveNames())) {
    if (nn && nn !== orig) m[orig] = nn;
  }
  return m;
}

function onRestoreTargetChange() { refreshRestoreConflicts(); }

function onTlogToggle() {
  const on = document.getElementById("rstTlog").checked;
  document.getElementById("pitrSection").style.display  = on ? "" : "none";
  document.getElementById("tlogSection").style.display  = on ? "" : "none";
}

// Query /api/databases/exists for the effective target names and update the
// conflict warning banner.
let _conflictCallToken = 0;
async function refreshRestoreConflicts() {
  const box = document.getElementById("rstConflictBox");
  const msg = document.getElementById("rstConflictMsg");
  const target = document.getElementById("rstTarget").value;
  const eff    = collectEffectiveNames();
  const names  = Object.values(eff);
  if (!target || !names.length) { box.classList.add("d-none"); return; }
  const token = ++_conflictCallToken;
  try {
    const url = `/api/databases/exists?host=${encodeURIComponent(target)}`
              + `&names=${encodeURIComponent(names.join(","))}`;
    const r   = await fetch(url);
    if (token !== _conflictCallToken) return;
    const j   = await r.json();
    const hits = (j.existing || []);
    if (!hits.length) { box.classList.add("d-none"); return; }
    const overwrite = document.getElementById("rstOverwrite").checked;
    msg.innerHTML = `On <b>${target}</b> these databases already exist: `
                  + `<code>${hits.join(", ")}</code>. `
                  + (overwrite
                      ? "They will be <b>dropped</b> before restore."
                      : "Enable <b>Overwrite</b> or rename to avoid collision.");
    box.classList.toggle("alert-warning", !overwrite);
    box.classList.toggle("alert-danger",  !overwrite);
    box.classList.remove("d-none");
  } catch { box.classList.add("d-none"); }
}

// ── Backup ────────────────────────────────────────────────────────────────────
async function startBackup() {
  const dbs = getCheckedDbs("bkpDbList");
  if (!dbs.length) { alert("Select at least one database."); return; }
  const body = {
    label:     document.getElementById("bkpLabel").value || "gui_backup",
    source:    document.getElementById("bkpSource").value,
    databases: dbs,
    compress:  document.getElementById("bkpCompress").checked,
    parallel:  +document.getElementById("bkpParallel").value,
    with_tlog: document.getElementById("bkpTlog").checked,
    copy_only: document.getElementById("bkpCopyOnly").checked,
  };
  const r = await fetch("/api/jobs/backup", { method: "POST",
    headers: {"Content-Type":"application/json"}, body: JSON.stringify(body) });
  const j = await r.json();
  openProgress(j.job_id, `Backup: ${body.label}`);
}

// ── Restore ───────────────────────────────────────────────────────────────────
async function startRestore() {
  const snap = document.getElementById("rstSnapshot").value;
  if (!snap) { alert("Select a snapshot."); return; }
  const dbs  = getCheckedDbs("rstDbList");
  if (!dbs.length) { alert("Select at least one database to restore."); return; }
  const pitrRaw   = document.getElementById("rstPitr").value;
  const target    = document.getElementById("rstTarget").value;
  const overwrite = document.getElementById("rstOverwrite").checked;
  const withTlog  = document.getElementById("rstTlog").checked;
  const source    = document.getElementById("rstTlogSource").value;
  const renameMap = collectRenameMap();
  const effective = collectEffectiveNames();

  // Client-side pre-flight conflict check — gives immediate feedback; the
  // restore runner repeats the check server-side.
  try {
    const url = `/api/databases/exists?host=${encodeURIComponent(target)}`
              + `&names=${encodeURIComponent(Object.values(effective).join(","))}`;
    const r   = await fetch(url);
    const j   = await r.json();
    const hits = (j.existing || []);
    if (hits.length && !overwrite) {
      alert(`Cannot restore: these databases already exist on ${target}:\n`
          + `  ${hits.join(", ")}\n\n`
          + `Enable "Overwrite existing databases" or rename to avoid collision.`);
      return;
    }
    if (hits.length && overwrite) {
      if (!confirm(`The following databases will be DROPPED on ${target} `
                 + `before restore:\n  ${hits.join(", ")}\n\nProceed?`)) return;
    }
  } catch (e) { /* best-effort; server does the authoritative check */ }

  const moveData  = collectDirMap("db-movedata");
  const moveLog   = collectDirMap("db-movelog");
  const body = {
    snapshot:  snap,
    target,
    databases: dbs,
    rename:    Object.keys(renameMap).length ? renameMap : null,
    move_data: Object.keys(moveData).length  ? moveData  : null,
    move_log:  Object.keys(moveLog ).length  ? moveLog   : null,
    overwrite,
    source:    withTlog ? (source || null) : null,
    parallel:  +document.getElementById("rstParallel").value,
    with_tlog: withTlog,
    pitr:      pitrRaw ? pitrRaw.replace("T"," ") : null,
  };
  const r = await fetch("/api/jobs/restore", { method: "POST",
    headers: {"Content-Type":"application/json"}, body: JSON.stringify(body) });
  const j = await r.json();
  openProgress(j.job_id, `Restore: ${snap}`);
}

// ── Jobs table ────────────────────────────────────────────────────────────────
async function loadJobs() {
  const r    = await fetch("/api/jobs");
  const jobs = await r.json();
  const el   = document.getElementById("jobsTable");
  if (!jobs.length) { el.innerHTML = '<p class="text-muted">No jobs yet.</p>'; return; }
  const rows = jobs.map(j => `
    <tr>
      <td><code class="small">${j.id}</code></td>
      <td><span class="badge ${j.type==="backup"?"bg-primary":"bg-success"}">${j.type}</span></td>
      <td class="small">${j.label}</td>
      <td><span class="badge ${statusBadge(j.status)}">${j.status}</span></td>
      <td class="small text-muted">${(j.started_at||"—").replace("T"," ")}</td>
      <td class="small text-muted">${(j.finished_at||"—").replace("T"," ")}</td>
      <td>
        <button class="btn btn-sm btn-outline-secondary py-0"
                onclick="openProgress('${j.id}','${j.label.replace(/'/g,"\\'")}')">
          <i class="bi bi-terminal"></i>
        </button>
      </td>
    </tr>`).join("");
  el.innerHTML = `
    <table class="table table-sm table-hover align-middle">
      <thead class="table-light"><tr>
        <th>ID</th><th>Type</th><th>Label</th><th>Status</th>
        <th>Started</th><th>Finished</th><th></th>
      </tr></thead>
      <tbody>${rows}</tbody>
    </table>`;
}

function statusBadge(s) {
  return {running:"bg-warning text-dark",done:"bg-success",failed:"bg-danger",pending:"bg-secondary"}[s]||"bg-light text-dark";
}

async function refreshRunningBadge() {
  try {
    const r    = await fetch("/api/jobs");
    const jobs = await r.json();
    const n    = jobs.filter(j => j.status === "running").length;
    const badge = document.getElementById("runningBadge");
    document.getElementById("runningCount").textContent = n;
    badge.classList.toggle("d-none", n === 0);
  } catch {}
}

// ── Progress WebSocket modal ───────────────────────────────────────────────────
function openProgress(jobId, title) {
  const log      = document.getElementById("progressLog");
  const statusEl = document.getElementById("progressStatus");
  document.getElementById("progressTitle").textContent = title || jobId;
  log.textContent = "";
  statusEl.innerHTML = '<span class="badge bg-secondary">connecting…</span>';

  if (_ws) { _ws.close(); _ws = null; }
  _progressModal.show();

  fetch(`/api/jobs/${jobId}`).then(r => r.json()).then(j => {
    log.textContent = j.lines.join("");
    log.scrollTop   = log.scrollHeight;

    if (j.status === "done" || j.status === "failed") {
      statusEl.innerHTML = `<span class="badge ${statusBadge(j.status)}">${j.status} — exit ${j.exit_code}</span>`;
      return;
    }

    const proto = location.protocol === "https:" ? "wss" : "ws";
    _ws = new WebSocket(`${proto}://${location.host}/ws/${jobId}`);

    _ws.onopen = () => {
      statusEl.innerHTML = '<span class="badge bg-warning text-dark badge-running">running…</span>';
    };
    _ws.onmessage = e => {
      if (e.data.trim() === "__DONE__") {
        fetch(`/api/jobs/${jobId}`).then(r => r.json()).then(j2 => {
          statusEl.innerHTML =
            `<span class="badge ${statusBadge(j2.status)}">${j2.status} — exit ${j2.exit_code}</span>`;
        });
        return;
      }
      log.textContent += e.data;
      log.scrollTop    = log.scrollHeight;
    };
    _ws.onerror = () => {
      statusEl.innerHTML = '<span class="badge bg-danger">connection error</span>';
    };
  });

  document.getElementById("progressModal").addEventListener("hidden.bs.modal", () => {
    if (_ws) { _ws.close(); _ws = null; }
  }, { once: true });
}


// ── Snapshots management page ────────────────────────────────────────────────
// Renders the "Snapshots" tab: table of all snapshot folders with size and DB
// list, plus per-row details/delete and a "Delete all" button. All endpoints
// read from /api/snapshots (see server.py).
let _snapshotDetailModal = null;

async function loadSnapshotsPage() {
  const tbody = document.getElementById("snapshotsTable");
  const sum   = document.getElementById("snapSummary");
  tbody.innerHTML = '<tr><td colspan="6" class="text-muted text-center py-3">Loading…</td></tr>';
  try {
    const r = await fetch("/api/snapshots");
    const snaps = await r.json();
    if (!snaps.length) {
      tbody.innerHTML = '<tr><td colspan="6" class="text-muted text-center py-3">No snapshots found.</td></tr>';
      if (sum) sum.textContent = "";
      return;
    }
    const total = snaps.reduce((a, s) => a + (s.size_bytes || 0), 0);
    if (sum) sum.textContent = `(${snaps.length} snapshot${snaps.length===1?"":"s"}, ${humanSize(total)} total)`;
    tbody.innerHTML = snaps.map(s => `
      <tr>
        <td><i class="bi bi-hdd text-info"></i></td>
        <td class="font-monospace" style="font-size:12px">${s.name}</td>
        <td style="white-space:nowrap">${s.created_at}</td>
        <td>${(s.databases||[]).map(d => `<span class="badge bg-light text-dark border me-1">${d}</span>`).join("")}</td>
        <td class="text-end" style="white-space:nowrap">${s.size_human || ""}</td>
        <td class="text-end">
          <button class="btn btn-sm btn-link p-0 me-2" title="Details"
                  onclick="showSnapshotDetail('${s.name.replace(/'/g, "\\'")}')">
            <i class="bi bi-info-circle"></i>
          </button>
          <button class="btn btn-sm btn-link p-0 text-danger" title="Delete"
                  onclick="deleteSnapshot('${s.name.replace(/'/g, "\\'")}')">
            <i class="bi bi-trash3"></i>
          </button>
        </td>
      </tr>`).join("");
  } catch (e) {
    tbody.innerHTML = `<tr><td colspan="6" class="text-danger">${e.message}</td></tr>`;
  }
}

function humanSize(n) {
  const units = ["B", "KB", "MB", "GB", "TB"];
  let u = 0;
  while (n >= 1024 && u < units.length - 1) { n /= 1024; u++; }
  return (u === 0 ? n + " B" : n.toFixed(1) + " " + units[u]);
}

async function showSnapshotDetail(name) {
  if (!_snapshotDetailModal) {
    _snapshotDetailModal = new bootstrap.Modal(document.getElementById("snapshotDetailModal"));
  }
  document.getElementById("snapDetailTitle").textContent = name;
  document.getElementById("snapDetailMeta").textContent  = "Loading…";
  document.getElementById("snapDetailFiles").innerHTML   = "";
  _snapshotDetailModal.show();
  try {
    const r = await fetch(`/api/snapshots/${encodeURIComponent(name)}`);
    if (!r.ok) throw new Error(await r.text());
    const d = await r.json();
    document.getElementById("snapDetailMeta").innerHTML =
      `<strong>Created:</strong> ${d.created_at} &nbsp;·&nbsp; ` +
      `<strong>Files:</strong> ${d.file_count} &nbsp;·&nbsp; ` +
      `<strong>Total size:</strong> ${d.size_human} &nbsp;·&nbsp; ` +
      `<strong>Path:</strong> <span class="font-monospace">${d.path}</span>`;
    document.getElementById("snapDetailFiles").innerHTML =
      d.files.map(f => `<tr>
        <td class="font-monospace" style="font-size:11px">${f.rel}</td>
        <td class="text-end" style="white-space:nowrap">${f.human}</td>
      </tr>`).join("");
  } catch (e) {
    document.getElementById("snapDetailMeta").innerHTML =
      `<span class="text-danger">${e.message}</span>`;
  }
}

async function deleteSnapshot(name) {
  if (!confirm(`Delete snapshot '${name}'?\n\nThis permanently removes the folder and its files from the transport share.`)) return;
  try {
    const r = await fetch(`/api/snapshots/${encodeURIComponent(name)}`, { method: "DELETE" });
    if (!r.ok) throw new Error(await r.text());
    loadSnapshotsPage();
    // Refresh Restore tab dropdown too, in case that snapshot was listed there.
    loadSnapshots();
  } catch (e) {
    alert(`Delete failed: ${e.message}`);
  }
}

async function deleteAllSnapshots() {
  if (!confirm("Delete ALL snapshots?\n\nEvery snapshot folder on the transport share will be removed. This cannot be undone.")) return;
  try {
    const r = await fetch("/api/snapshots", { method: "DELETE" });
    if (!r.ok) throw new Error(await r.text());
    const j = await r.json();
    if (j.failed && j.failed.length) {
      alert(`${j.deleted.length} deleted, ${j.failed.length} failed:\n` +
            j.failed.map(f => `  • ${f.name}: ${f.error}`).join("\n"));
    }
    loadSnapshotsPage();
    loadSnapshots();
  } catch (e) {
    alert(`Delete-all failed: ${e.message}`);
  }
}
