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
  // /api/databases is now mssql-python direct (~15 ms cold, ~2 ms pool hit)
  // so this does not delay page render noticeably.
  const bkp = document.getElementById("bkpSource");
  if (bkp && bkp.value) loadDatabases("bkpSource", "bkpDbList");
  updateFooter();
  // Load snapshot cache + jobs count in background so the footer is accurate
  // from the first render, without blocking the initial Backup tab.
  fetch("/api/snapshots").then(r => r.json()).then(j => {
    _snapshotCache = j || [];
    updateFooter();
  }).catch(() => {});
  fetch("/api/jobs").then(r => r.json()).then(js => {
    const f = document.getElementById("footJobs");
    if (f && Array.isArray(js)) f.textContent = js.length;
  }).catch(() => {});
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
  if (!dbs.length) { toast("Select at least one database.", "warning"); return; }
  const body = {
    label:     document.getElementById("bkpLabel").value || "gui_backup",
    source:    document.getElementById("bkpSource").value,
    databases: dbs,
    compress:  document.getElementById("bkpCompress").checked,
    parallel:  +document.getElementById("bkpParallel").value,
    with_tlog: document.getElementById("bkpTlog").checked,
    copy_only: document.getElementById("bkpCopyOnly").checked,
  };
  if (!confirm(`Start backup of ${dbs.length} database(s) on ${body.source}?\n\n  • ${dbs.join("\n  • ")}`))
    return;
  try {
    const r = await fetch("/api/jobs/backup", { method: "POST",
      headers: {"Content-Type":"application/json"}, body: JSON.stringify(body) });
    if (!r.ok) throw new Error(await r.text());
    const j = await r.json();
    toast(`Backup job ${j.job_id} started (${dbs.length} DB)`, "success");
    openProgress(j.job_id, `Backup: ${body.label}`);
  } catch (e) {
    toast(`Backup failed to start: ${e.message}`, "danger");
  }
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
  try {
    const r = await fetch("/api/jobs/restore", { method: "POST",
      headers: {"Content-Type":"application/json"}, body: JSON.stringify(body) });
    if (!r.ok) throw new Error(await r.text());
    const j = await r.json();
    toast(`Restore job ${j.job_id} started on ${target}`, "success");
    openProgress(j.job_id, `Restore: ${snap}`);
  } catch (e) {
    toast(`Restore failed to start: ${e.message}`, "danger");
  }
}

// ── Jobs table ────────────────────────────────────────────────────────────────
let _jobsCache     = [];
let _jobsSorts     = [{ col: 'started_at', asc: false }];
let _jobsPage      = 1;
let _jobsPageSize  = 25;          // 0 = show all
let _jobsTimeRange = '24h';       // matches the <select> default

async function loadJobs() {
  try {
    const r    = await fetch("/api/jobs");
    _jobsCache = await r.json();
    renderJobsTable();
  } catch (e) {
    const el = document.getElementById("jobsTable");
    if (el) el.innerHTML = `<tr><td colspan="7" class="text-danger">Failed to load jobs: ${e.message}</td></tr>`;
  }
}

function sortJobs(col, multi = false) {
  const existingIdx = _jobsSorts.findIndex(s => s.col === col);

  if (multi) {
    if (existingIdx >= 0) {
      if (_jobsSorts[existingIdx].asc) {
        _jobsSorts[existingIdx].asc = false;
      } else {
        _jobsSorts.splice(existingIdx, 1);
      }
    } else {
      _jobsSorts.push({ col, asc: true });
    }
  } else {
    if (existingIdx === 0 && _jobsSorts.length === 1) {
      if (_jobsSorts[0].asc) {
        _jobsSorts[0].asc = false;
      } else {
        _jobsSorts = [];
      }
    } else {
      _jobsSorts = [{ col, asc: true }];
    }
  }
  updateSortIcons();
  renderJobsTable();
}

function updateSortIcons() {
  const headers = document.querySelectorAll('#tabJobs th[onclick]');
  headers.forEach(th => {
    const colMatch = th.getAttribute('onclick').match(/'([^']+)'/);
    if (!colMatch) return;
    const col = colMatch[1];
    let icon = th.querySelector('i');
    if (!icon) {
      icon = document.createElement('i');
      th.appendChild(icon);
    }

    const sort = _jobsSorts.find(s => s.col === col);
    if (sort) {
      const idx = _jobsSorts.indexOf(sort);
      icon.className = sort.asc ? 'bi bi-sort-down-alt ms-1 text-primary' : 'bi bi-sort-down ms-1 text-primary';
      icon.style.fontSize = '1em';
      icon.style.opacity = '1.0';
      // Add a small badge if there are multiple sorts
      const existingBadge = th.querySelector('.sort-badge');
      if (existingBadge) existingBadge.remove();
      if (_jobsSorts.length > 1) {
         const badge = document.createElement('span');
         badge.className = 'sort-badge';
         badge.textContent = idx + 1;
         th.appendChild(badge);
      }
    } else {
      icon.className = 'bi bi-arrow-down-up ms-1 text-muted';
      icon.style.fontSize = '0.8em';
      icon.style.opacity = '0.4';
      const existingBadge = th.querySelector('.sort-badge');
      if (existingBadge) existingBadge.remove();
    }
  });
}

function parsePrometheusFilter(q) {
  // Supports key:"value", key:'value', key:value
  // Also supports inequality for times, e.g. Started:">24h ago"
  const filters = [];
  // Basic regex to match key:value pairs
  const regex = /([a-zA-Z0-9_]+)\s*:\s*(?:"([^"]+)"|'([^']+)'|([<>]=?\s*\d+(?:\.\d+)?\s*[smhd](?:\s*ago)?|[^\s]+))/gi;
  let match;

  while ((match = regex.exec(q)) !== null) {
    const key = match[1].toLowerCase();
    let val = match[2] || match[3] || match[4] || "";
    // Some values might come with quotes from match[2] or match[3]
    // The regex already handled it, so we're good.
    filters.push({ key, val, text: match[0] });
  }

  // Anything not captured by the regex is generic search text
  let genericText = q.replace(regex, '').trim().toLowerCase();

  return { filters, genericText };
}

function checkTimeInequality(jobTimeStr, queryVal) {
  if (!jobTimeStr || !queryVal) return false;

  // if queryVal is simple ">24h ago" with no quotes, or if it had quotes and was parsed as `>24h ago`
  // We'll strip surrounding quotes if any just in case
  queryVal = queryVal.replace(/^['"]|['"]$/g, '').trim();

  const jobTime = new Date(jobTimeStr).getTime();

  // Try to parse exact relative time query: >, <, >=, <= followed by amount and unit (s, m, h, d) + optional "ago"
  const timeRegex = /^([<>]=?)\s*(\d+(?:\.\d+)?)\s*([smhd])(?:\s*ago)?$/i;
  const match = timeRegex.exec(queryVal);
  if (match) {
    const op = match[1];
    const amount = parseFloat(match[2]);
    const unit = match[3].toLowerCase();

    let ms = 0;
    if (unit === 's') ms = amount * 1000;
    else if (unit === 'm') ms = amount * 60 * 1000;
    else if (unit === 'h') ms = amount * 60 * 60 * 1000;
    else if (unit === 'd') ms = amount * 24 * 60 * 60 * 1000;

    const targetTime = Date.now() - ms;

    if (op === '>') return jobTime < targetTime;
    if (op === '>=') return jobTime <= targetTime;
    if (op === '<') return jobTime > targetTime;
    if (op === '<=') return jobTime >= targetTime;

    return false;
  }

  // Try parsing absolute ISO timestamp (for simple equals)
  const absTime = new Date(queryVal).getTime();
  if (!isNaN(absTime) && queryVal.length >= 8) { // simple heuristic to not match single numbers as dates
      return jobTimeStr.startsWith(queryVal) || jobTime === absTime;
  }

  // Otherwise try basic text inclusion
  return jobTimeStr.toLowerCase().includes(queryVal.toLowerCase());
}

/** Return the cutoff timestamp (ms) for the active time-range filter, or 0 for "all". */
function _jobsTimeCutoff() {
  const map = { '1h': 3600, '6h': 21600, '24h': 86400, '7d': 604800, '30d': 2592000 };
  const secs = map[_jobsTimeRange] || 0;
  return secs ? Date.now() - secs * 1000 : 0;
}

function renderJobsTable() {
  const el = document.getElementById("jobsTable");
  const footEl = document.getElementById("footJobs");
  if (footEl && Array.isArray(_jobsCache)) footEl.textContent = _jobsCache.length;
  if (!el) return;

  // ── 1. Time-range filter ────────────────────────────────────────────────
  const cutoff = _jobsTimeCutoff();
  let jobs = cutoff
    ? _jobsCache.filter(j => {
        const t = j.started_at ? new Date(j.started_at).getTime() : 0;
        return t >= cutoff;
      })
    : _jobsCache.slice();

  // ── 2. Prometheus-style text / key:value filter ─────────────────────────
  const q = (document.getElementById("jobFilter")?.value || "").trim();
  if (q) {
    const pf = parsePrometheusFilter(q);
    jobs = jobs.filter(j => {
      if (pf.genericText) {
        const gt = pf.genericText;
        if (!((j.id||"").toLowerCase().includes(gt) ||
              (j.type||"").toLowerCase().includes(gt) ||
              (j.label||"").toLowerCase().includes(gt) ||
              (j.status||"").toLowerCase().includes(gt))) return false;
      }
      for (const f of pf.filters) {
        const key = f.key.toLowerCase();
        const val = f.val.toLowerCase();
        if (key === 'status'  && (j.status||"").toLowerCase() !== val) return false;
        if (key === 'type'    && (j.type||"").toLowerCase() !== val) return false;
        if (key === 'label'   && !(j.label||"").toLowerCase().includes(val)) return false;
        if (key === 'id'      && !(j.id||"").toLowerCase().includes(val)) return false;
        if ((key === 'started' || key === 'started_at') &&
            !checkTimeInequality(j.started_at, f.text.substring(f.text.indexOf(':')+1))) return false;
        if ((key === 'finished' || key === 'finished_at') &&
            !checkTimeInequality(j.finished_at, f.text.substring(f.text.indexOf(':')+1))) return false;
      }
      return true;
    });
  }

  // ── 3. Sort ─────────────────────────────────────────────────────────────
  jobs.sort((a, b) => {
    for (const sort of _jobsSorts) {
      let vA = a[sort.col] || "", vB = b[sort.col] || "";
      if (sort.col === 'started_at' || sort.col === 'finished_at') {
        const tA = vA ? new Date(vA).getTime() : 0;
        const tB = vB ? new Date(vB).getTime() : 0;
        if (tA !== tB) return sort.asc ? tA - tB : tB - tA;
      } else {
        if (typeof vA === "string") vA = vA.toLowerCase();
        if (typeof vB === "string") vB = vB.toLowerCase();
        if (vA < vB) return sort.asc ? -1 : 1;
        if (vA > vB) return sort.asc ? 1 : -1;
      }
    }
    return 0;
  });

  const total = jobs.length;

  // ── 4. Pagination ────────────────────────────────────────────────────────
  const ps = _jobsPageSize;          // 0 = show all
  const pages = ps ? Math.max(1, Math.ceil(total / ps)) : 1;
  if (_jobsPage > pages) _jobsPage = pages;
  if (_jobsPage < 1)     _jobsPage = 1;

  const slice = ps ? jobs.slice((_jobsPage - 1) * ps, _jobsPage * ps) : jobs;

  // pagination controls
  const infoEl    = document.getElementById("jobsPaginationInfo");
  const pageNumEl = document.getElementById("jobsPageNum");
  const prevBtn   = document.getElementById("jobsPrevBtn");
  const nextBtn   = document.getElementById("jobsNextBtn");
  const ctrlEl    = document.getElementById("jobsPaginationCtrl");

  if (infoEl) {
    const from = total ? (ps ? (_jobsPage - 1) * ps + 1 : 1) : 0;
    const to   = ps ? Math.min(_jobsPage * ps, total) : total;
    infoEl.textContent = total
      ? `Showing ${from}–${to} of ${total} job(s)`
      : "No jobs match the current filters.";
  }
  if (pageNumEl) pageNumEl.textContent = ps && pages > 1 ? `Page ${_jobsPage} / ${pages}` : "";
  if (prevBtn)   prevBtn.disabled  = _jobsPage <= 1;
  if (nextBtn)   nextBtn.disabled  = _jobsPage >= pages;
  if (ctrlEl)    ctrlEl.style.display = ps && pages > 1 ? "" : "none";

  // ── 5. Render rows ───────────────────────────────────────────────────────
  if (!slice.length) {
    el.innerHTML = '<tr><td colspan="7" class="text-muted text-center py-3">No jobs found.</td></tr>';
    updateSortIcons();
    return;
  }

  el.innerHTML = slice.map(j => `
    <tr>
      <td><code class="small">${j.id}</code></td>
      <td><span class="badge ${j.type==="backup"?"bg-primary":"bg-success"}">${j.type}</span></td>
      <td class="small">${j.label}</td>
      <td><span class="badge ${statusBadge(j.status)}">${j.status}</span></td>
      <td class="small text-muted">${(j.started_at||"—").replace("T"," ").substring(0,19)}</td>
      <td class="small text-muted">${(j.finished_at||"—").replace("T"," ").substring(0,19)}</td>
      <td class="text-end">
        <button class="btn btn-sm btn-outline-secondary py-0"
                onclick="openProgress('${j.id}','${j.label.replace(/'/g,"\\'")}')">
          <i class="bi bi-terminal"></i>
        </button>
      </td>
    </tr>`).join("");

  updateSortIcons();
}

function setJobsTimeFilter(val) {
  _jobsTimeRange = val;
  _jobsPage = 1;
  renderJobsTable();
}

function setJobsPage(n) {
  _jobsPage = n;
  renderJobsTable();
}

function setJobsPageSize(n) {
  _jobsPageSize = n;
  _jobsPage = 1;
  renderJobsTable();
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

function scrollLogToBottom() {
  const log = document.getElementById("progressLog");
  if (log) log.scrollTop = log.scrollHeight;
}

function toggleLogWrap() {
  const log = document.getElementById("progressLog");
  if (!log) return;
  const nowWrap = log.style.whiteSpace !== "nowrap";
  log.style.whiteSpace = nowWrap ? "nowrap" : "pre-wrap";
  log.style.wordBreak  = nowWrap ? "normal" : "break-all";
  log.style.overflowX  = nowWrap ? "auto"   : "hidden";
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
let _snapshotCache = [];  // last /api/snapshots response; used for client filter

async function loadSnapshotsPage() {
  const tbody = document.getElementById("snapshotsTable");
  tbody.innerHTML = '<tr><td colspan="7" class="text-muted text-center py-3">Loading…</td></tr>';
  try {
    const r = await fetch("/api/snapshots");
    _snapshotCache = await r.json();
    renderSnapshotsTable();
    updateFooter();
  } catch (e) {
    tbody.innerHTML = `<tr><td colspan="7" class="text-danger">${e.message}</td></tr>`;
  }
}

function renderSnapshotsTable() {
  const tbody = document.getElementById("snapshotsTable");
  const sum   = document.getElementById("snapSummary");
  const filterEl = document.getElementById("snapFilter");
  const q = (filterEl ? filterEl.value : "").toLowerCase().trim();
  const snaps = _snapshotCache.filter(s =>
    !q ||
    s.name.toLowerCase().includes(q) ||
    (s.databases || []).some(d => d.toLowerCase().includes(q)));
  if (!_snapshotCache.length) {
    tbody.innerHTML = '<tr><td colspan="7" class="text-muted text-center py-3">No snapshots found.</td></tr>';
    if (sum) sum.textContent = "";
    return;
  }
  if (!snaps.length) {
    tbody.innerHTML = `<tr><td colspan="7" class="text-muted text-center py-3">No snapshots match <code>${q}</code>.</td></tr>`;
  } else {
    tbody.innerHTML = snaps.map(s => `
      <tr>
        <td><input class="form-check-input snap-chk" type="checkbox" value="${s.name.replace(/"/g, '&quot;')}" onchange="updateDeleteSelectedButton()"></td>
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
  }
  const chkAll = document.getElementById("chkAllSnapshots");
  if (chkAll) chkAll.checked = false;
  updateDeleteSelectedButton();
  const total = _snapshotCache.reduce((a, s) => a + (s.size_bytes || 0), 0);
  if (sum) sum.textContent = `(${_snapshotCache.length} snapshot${_snapshotCache.length===1?"":"s"}, ${humanSize(total)} total` +
    (q ? `; ${snaps.length} match '${q}'` : ``) + `)`;
}

function toggleAllSnapshots(checked) {
  document.querySelectorAll(".snap-chk").forEach(chk => chk.checked = checked);
  updateDeleteSelectedButton();
}

function updateDeleteSelectedButton() {
  const btn = document.getElementById("btnDeleteSelectedSnapshots");
  if (!btn) return;
  const anyChecked = document.querySelectorAll(".snap-chk:checked").length > 0;
  btn.style.display = anyChecked ? "inline-block" : "none";
}

async function deleteSelectedSnapshots() {
  const selected = Array.from(document.querySelectorAll(".snap-chk:checked")).map(chk => chk.value);
  if (!selected.length) return;
  if (!confirm(`Delete ${selected.length} selected snapshot(s)?\n\nThis permanently removes the folders and their files from the transport share.`)) return;

  for (const name of selected) {
    try {
      const r = await fetch(`/api/snapshots/${encodeURIComponent(name)}`, { method: "DELETE" });
      if (!r.ok) throw new Error(await r.text());
    } catch (e) {
      alert(`Delete failed for ${name}: ${e.message}`);
    }
  }
  loadSnapshotsPage();
  loadSnapshots();
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


// ── Toasts + footer ──────────────────────────────────────────────────────────
// Bootstrap toast popup — called from startBackup/startRestore and delete ops
// so users always get confirmation that the click registered. Auto-hides after
// 5 s; stays on screen long enough to read but not long enough to stack.
function toast(message, variant = "primary") {
  const container = document.getElementById("toastContainer");
  if (!container) { alert(message); return; }
  const id = "toast_" + Date.now() + "_" + Math.random().toString(36).slice(2,6);
  const icon = ({
    success: "bi-check-circle",
    danger:  "bi-exclamation-triangle",
    warning: "bi-exclamation-triangle",
    primary: "bi-info-circle",
  })[variant] || "bi-info-circle";
  const html = `
    <div class="toast align-items-center text-bg-${variant} border-0 show" role="alert"
         id="${id}" data-bs-delay="5000">
      <div class="d-flex">
        <div class="toast-body"><i class="bi ${icon} me-2"></i>${message}</div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto"
                data-bs-dismiss="toast"></button>
      </div>
    </div>`;
  container.insertAdjacentHTML("beforeend", html);
  const el = document.getElementById(id);
  const t = new bootstrap.Toast(el, { delay: 5000 });
  t.show();
  el.addEventListener("hidden.bs.toast", () => el.remove());
}

// Footer counters: servers + snapshots + jobs. Called from loadServers,
// loadSnapshotsPage, loadJobs — keeps the footer in sync with whatever view
// is currently open without firing extra requests of its own.
function updateFooter() {
  const s = document.getElementById("footServers");
  const p = document.getElementById("footSnaps");
  if (s && typeof _servers !== "undefined" && _servers) s.textContent = _servers.length;
  if (p) p.textContent = (_snapshotCache || []).length;
}
