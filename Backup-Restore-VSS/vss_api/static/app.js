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
  setInterval(refreshRunningBadge, 4000);
});

// ── Servers ───────────────────────────────────────────────────────────────────
async function loadServers() {
  const r = await fetch("/api/servers");
  _servers = await r.json();
  renderSidebar();
  populateDropdowns();
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
  ["bkpSource", "rstTarget"].forEach(id => {
    const sel = document.getElementById(id);
    const prev = sel.value;
    sel.innerHTML = "";
    for (const key of Object.keys(_servers)) {
      const opt = new Option(key, key);
      sel.appendChild(opt);
    }
    if (prev && sel.querySelector(`option[value="${prev}"]`)) sel.value = prev;
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
async function loadSnapshots() {
  const r = await fetch("/api/snapshots");
  const snaps = await r.json();
  const sel = document.getElementById("rstSnapshot");
  if (!snaps.length) { sel.innerHTML = '<option value="">No snapshots found</option>'; return; }
  sel.innerHTML = snaps.map(s =>
    `<option value="${s.name}">${s.name}  [${s.databases.join(", ")}]</option>`
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
    <div class="form-check py-0">
      <input class="form-check-input db-check" type="checkbox" value="${db}"
             id="rst_db_${db}" checked>
      <label class="form-check-label" for="rst_db_${db}" style="font-size:13px">${db}</label>
    </div>`).join("");
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
  const pitrRaw = document.getElementById("rstPitr").value;
  const body = {
    snapshot:  snap,
    target:    document.getElementById("rstTarget").value,
    databases: dbs.length ? dbs : null,
    parallel:  +document.getElementById("rstParallel").value,
    with_tlog: document.getElementById("rstTlog").checked,
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
