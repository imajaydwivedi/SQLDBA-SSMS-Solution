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
  _loadCurrentUser();
  document.getElementById("rstOverwrite")
          .addEventListener("change", refreshRestoreConflicts);
  setInterval(refreshRunningBadge, 4000);
});

let _currentUser = null;

async function _loadCurrentUser() {
  try {
    const r = await fetch("/auth/me");
    if (r.status === 401) { location.href = "/auth/login"; return; }
    _currentUser = await r.json();
    const el = document.getElementById("sidebarUser");
    if (el) el.textContent = _currentUser.display_name || _currentUser.username || "—";
    _applyRoleUI(_currentUser.role);
  } catch (_) {}
}

function _applyRoleUI(role) {
  const isAdmin = role === "admin";
  // Settings tab: admin only
  if (isAdmin) document.getElementById("settingsNavItem")?.classList.remove("d-none");

  // Backup / Restore action buttons: admin only
  const btnBackup  = document.getElementById("btnStartBackup");
  const btnRestore = document.getElementById("btnStartRestore");
  if (btnBackup)  { btnBackup.disabled  = !isAdmin; btnBackup.title  = isAdmin ? "" : "Admin role required"; }
  if (btnRestore) { btnRestore.disabled = !isAdmin; btnRestore.title = isAdmin ? "" : "Admin role required"; }

  // Snapshot delete controls: admin only
  const btnDelAll  = document.getElementById("btnDeleteAllSnapshots");
  const btnDelSel  = document.getElementById("btnDeleteSelectedSnapshots");
  if (btnDelAll) btnDelAll.classList.toggle("d-none", !isAdmin);
  if (btnDelSel) btnDelSel.classList.toggle("d-none", !isAdmin);
  // Hide the select-all checkbox column when delete is not available
  const chkAll = document.getElementById("chkAllSnapshots");
  if (chkAll) chkAll.closest("th")?.classList.toggle("d-none", !isAdmin);

  // Add-server button in sidebar: admin only
  const btnAddSrv = document.getElementById("btnAddServer");
  if (btnAddSrv) btnAddSrv.classList.toggle("d-none", !isAdmin);
}


// ═══════════════════════════════════════════════════════════════════════════════
// ── Settings Tab ─────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════
let _settingsData = {};      // key → {value, label, description, is_secret}

async function initSettingsTab() {
  await loadSettingsCat("auth");
}

async function loadSettingsCat(cat) {
  // Update sidebar active state
  document.querySelectorAll("#settingsCatList .list-group-item").forEach(el => {
    el.classList.toggle("active", el.dataset.cat === cat);
  });
  const content = document.getElementById("settingsContent");
  content.innerHTML = '<div class="text-muted py-4 text-center"><span class="spinner-border spinner-border-sm me-2"></span>Loading…</div>';
  try {
    const r = await fetch(`/api/settings/${cat}`);
    if (!r.ok) throw new Error(await r.text());
    const rows = await r.json();
    rows.forEach(row => { _settingsData[row.key] = row; });
    content.innerHTML = _renderSettingsPanel(cat, rows);
  } catch (e) {
    content.innerHTML = `<div class="alert alert-danger">${_esc(e.message)}</div>`;
  }
}

function _renderSettingsPanel(cat, rows) {
  const TITLES = {
    "auth":        "Authentication",
    "smtp":        "SMTP / Email",
    "oauth.google":"Google OAuth 2.0",
    "oauth.github":"GitHub OAuth",
    "query":       "Query SQL Logins",
    "retention":   "Retention Policy",
  };
  const HELPS = {
    "oauth.google.client_id":      "From Google Cloud Console → Credentials → OAuth 2.0 Client IDs",
    "oauth.github.client_id":      "From GitHub → Settings → Developer Settings → OAuth Apps",
    "auth.enabled":                "Set to false to make the app publicly accessible (LAN/VPN only)",
    "auth.default_oauth_role":     "Role assigned to new users who sign in via Google or GitHub",
    "retention.snapshot_max_bytes":"In bytes. 268435456000 = 250 GB",
  };
  let html = `<h5 class="settings-section-title">${TITLES[cat] || cat}</h5>`;
  if (rows.length === 0) {
    html += '<p class="text-muted">No settings in this category.</p>';
    return html;
  }
  rows.forEach(row => {
    const isSecret  = row.is_secret || row.is_sensitive;
    const isMasked  = isSecret && row.value === "••••••";
    const inputId   = `si_${row.key.replace(/\./g,"_")}`;
    const inputType = isSecret ? "password" : "text";
    const val       = isMasked ? "" : (row.value || "");
    const extra     = HELPS[row.key] ? `<div class="setting-desc mt-1">${_esc(HELPS[row.key])}</div>` : "";
    const eyeBtn    = isSecret
      ? `<button class="btn btn-sm btn-outline-secondary ms-1" type="button"
               onclick="toggleSettingEye('${inputId}')" title="Show/hide">
           <i class="bi bi-eye"></i></button>`
      : "";
    html += `
    <div class="setting-row">
      <div class="setting-label">
        ${_esc(row.label || row.key)}
        ${extra}
      </div>
      <div class="setting-val d-flex gap-1">
        <input type="${inputType}" class="form-control form-control-sm" id="${inputId}"
               data-key="${row.key}" data-secret="${isSecret ? 1 : 0}"
               value="${_esc(val)}" placeholder="${isMasked ? '(unchanged)' : ''}">
        ${eyeBtn}
        <button class="btn btn-sm btn-primary" onclick="saveSetting('${row.key}','${inputId}')">Save</button>
      </div>
    </div>`;
  });
  html += `<div class="mt-3">
    <button class="btn btn-sm btn-primary" onclick="saveAllSettings('${cat}')">
      <i class="bi bi-floppy me-1"></i>Save All
    </button>
    <span id="settingsSaveStatus" class="ms-2 text-muted small"></span>
  </div>`;
  return html;
}

function toggleSettingEye(inputId) {
  const el = document.getElementById(inputId);
  if (!el) return;
  el.type = el.type === "password" ? "text" : "password";
}

async function saveSetting(key, inputId) {
  const el    = document.getElementById(inputId);
  if (!el) return;
  const value = el.value;
  const meta  = _settingsData[key] || {};
  // Don't send if masked and unchanged
  if (meta.is_secret && value === "" && el.placeholder === "(unchanged)") return;
  try {
    const r = await fetch("/api/settings", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({key, value}),
    });
    if (!r.ok) throw new Error((await r.json()).detail || r.statusText);
    _showToast(`Saved: ${key}`, "success");
  } catch (e) {
    _showToast(`Error: ${e.message}`, "danger");
  }
}

async function saveAllSettings(cat) {
  const inputs = document.querySelectorAll(`#settingsContent input[data-key]`);
  const batch  = [];
  inputs.forEach(el => {
    const key    = el.dataset.key;
    const secret = el.dataset.secret === "1";
    const value  = el.value;
    if (secret && value === "" && el.placeholder === "(unchanged)") return;
    batch.push({key, value});
  });
  if (batch.length === 0) return;
  try {
    const r = await fetch("/api/settings/batch", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(batch),
    });
    if (!r.ok) throw new Error((await r.json()).detail || r.statusText);
    _showToast(`${batch.length} setting(s) saved`, "success");
    // Reload the category to show updated masked values
    await loadSettingsCat(cat);
  } catch (e) {
    _showToast(`Error saving settings: ${e.message}`, "danger");
  }
}


// ── User Management ───────────────────────────────────────────────────────────
async function loadUsersMgmt() {
  document.querySelectorAll("#settingsCatList .list-group-item").forEach(el => {
    el.classList.toggle("active", el.dataset.cat === "_users");
  });
  const content = document.getElementById("settingsContent");
  content.innerHTML = '<div class="text-muted py-4 text-center"><span class="spinner-border spinner-border-sm me-2"></span>Loading…</div>';
  try {
    const r = await fetch("/api/users");
    if (!r.ok) throw new Error(await r.text());
    const users = await r.json();
    content.innerHTML = _renderUsersTable(users);
  } catch (e) {
    content.innerHTML = `<div class="alert alert-danger">${_esc(e.message)}</div>`;
  }
}

function _renderUsersTable(users) {
  const roleBadge = r =>
    `<span class="role-${r}">${r}</span>`;
  const provIcon = p => ({
    local:"<i class='bi bi-person-fill'></i>",
    google:"<i class='bi bi-google text-danger'></i>",
    github:"<i class='bi bi-github'></i>",
  }[p] || p);
  const rows = users.map(u => `
    <tr class="${u.is_active ? "" : "table-secondary text-muted"}">
      <td>${_esc(u.username)}</td>
      <td>${_esc(u.email || "")}</td>
      <td>${_esc(u.display_name || "")}</td>
      <td>${provIcon(u.provider)}</td>
      <td>${roleBadge(u.role)}</td>
      <td>${u.last_login ? u.last_login.substring(0,16) : "—"}</td>
      <td>${u.is_active ? '<span class="badge bg-success">Active</span>' : '<span class="badge bg-secondary">Inactive</span>'}</td>
      <td>
        <div class="btn-group btn-group-sm">
          <button class="btn btn-outline-secondary" onclick="editUserModal(${u.id},'${u.role}')" title="Edit role">
            <i class="bi bi-pencil"></i></button>
          ${u.username !== "admin"
            ? `<button class="btn btn-outline-${u.is_active ? "warning" : "success"}"
                 onclick="toggleUserActive(${u.id},${u.is_active ? 0 : 1})"
                 title="${u.is_active ? "Deactivate" : "Reactivate"}">
                 <i class="bi bi-${u.is_active ? "person-dash" : "person-check"}"></i></button>`
            : ""}
        </div>
      </td>
    </tr>`).join("");
  return `
  <h5 class="settings-section-title">Users</h5>
  <div class="d-flex gap-2 mb-3">
    <button class="btn btn-sm btn-primary" onclick="showCreateUserModal()">
      <i class="bi bi-person-plus me-1"></i>Create User</button>
    <button class="btn btn-sm btn-outline-primary" onclick="showInviteModal()">
      <i class="bi bi-envelope-plus me-1"></i>Invite via Email</button>
  </div>
  <div class="table-responsive">
  <table class="table table-sm table-hover table-bordered align-middle" style="font-size:13px">
    <thead class="table-dark">
      <tr><th>Username</th><th>Email</th><th>Display Name</th><th>Provider</th>
          <th>Role</th><th>Last Login</th><th>Status</th><th>Actions</th></tr>
    </thead>
    <tbody>${rows}</tbody>
  </table></div>

  <!-- Create User Modal -->
  <div class="modal fade" id="createUserModal" tabindex="-1">
    <div class="modal-dialog"><div class="modal-content">
      <div class="modal-header"><h5 class="modal-title">Create Local User</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>
      <div class="modal-body">
        <div class="mb-2"><label class="form-label small">Username</label>
          <input type="text" class="form-control form-control-sm" id="newUserName"></div>
        <div class="mb-2"><label class="form-label small">Email</label>
          <input type="email" class="form-control form-control-sm" id="newUserEmail"></div>
        <div class="mb-2"><label class="form-label small">Display Name</label>
          <input type="text" class="form-control form-control-sm" id="newUserDisplay"></div>
        <div class="mb-2"><label class="form-label small">Password</label>
          <input type="password" class="form-control form-control-sm" id="newUserPwd"></div>
        <div class="mb-2"><label class="form-label small">Role</label>
          <select class="form-select form-select-sm" id="newUserRole">
            <option value="viewer">Viewer</option>
            <option value="editor">Editor</option>
            <option value="admin">Admin</option>
          </select></div>
        <div class="alert alert-danger d-none" id="createUserErr"></div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancel</button>
        <button class="btn btn-primary btn-sm" onclick="doCreateUser()">Create</button>
      </div>
    </div></div>
  </div>

  <!-- Invite Modal -->
  <div class="modal fade" id="inviteModal" tabindex="-1">
    <div class="modal-dialog"><div class="modal-content">
      <div class="modal-header"><h5 class="modal-title">Invite User</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>
      <div class="modal-body">
        <div class="mb-2"><label class="form-label small">Email Address</label>
          <input type="email" class="form-control form-control-sm" id="inviteEmail"></div>
        <div class="mb-2"><label class="form-label small">Role</label>
          <select class="form-select form-select-sm" id="inviteRole">
            <option value="viewer">Viewer</option>
            <option value="editor">Editor</option>
            <option value="admin">Admin</option>
          </select></div>
        <div class="alert d-none" id="inviteResult"></div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancel</button>
        <button class="btn btn-primary btn-sm" onclick="doInviteUser()">Send Invitation</button>
      </div>
    </div></div>
  </div>`;
}

function showCreateUserModal() {
  const m = new bootstrap.Modal(document.getElementById("createUserModal"));
  m.show();
}

async function doCreateUser() {
  const body = {
    username:     document.getElementById("newUserName").value.trim(),
    email:        document.getElementById("newUserEmail").value.trim(),
    display_name: document.getElementById("newUserDisplay").value.trim(),
    password:     document.getElementById("newUserPwd").value,
    role:         document.getElementById("newUserRole").value,
  };
  const errEl = document.getElementById("createUserErr");
  errEl.classList.add("d-none");
  try {
    const r = await fetch("/api/users", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(body),
    });
    if (!r.ok) { const j = await r.json(); throw new Error(j.detail || r.statusText); }
    bootstrap.Modal.getInstance(document.getElementById("createUserModal"))?.hide();
    _showToast("User created successfully", "success");
    await loadUsersMgmt();
  } catch (e) {
    errEl.textContent = e.message;
    errEl.classList.remove("d-none");
  }
}

function showInviteModal() {
  const m = new bootstrap.Modal(document.getElementById("inviteModal"));
  m.show();
}

async function doInviteUser() {
  const email = document.getElementById("inviteEmail").value.trim();
  const role  = document.getElementById("inviteRole").value;
  const resEl = document.getElementById("inviteResult");
  resEl.className = "alert d-none";
  try {
    const r = await fetch("/api/users/invite", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({email, role}),
    });
    const j = await r.json();
    if (!r.ok) throw new Error(j.detail || r.statusText);
    resEl.className = "alert alert-success";
    resEl.textContent = j.email_sent
      ? `Invitation sent to ${email}.`
      : `Invitation link (email not sent): ${j.link}`;
    resEl.classList.remove("d-none");
  } catch (e) {
    resEl.className = "alert alert-danger";
    resEl.textContent = e.message;
    resEl.classList.remove("d-none");
  }
}

async function editUserModal(uid, currentRole) {
  const role = prompt(`New role for user ${uid} (admin/editor/viewer):`, currentRole);
  if (!role || !["admin","editor","viewer"].includes(role)) return;
  try {
    const r = await fetch(`/api/users/${uid}`, {
      method: "PATCH",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({role}),
    });
    if (!r.ok) throw new Error((await r.json()).detail || r.statusText);
    _showToast("Role updated", "success");
    await loadUsersMgmt();
  } catch (e) {
    _showToast(`Error: ${e.message}`, "danger");
  }
}

async function toggleUserActive(uid, newState) {
  try {
    const r = await fetch(`/api/users/${uid}`, {
      method: "PATCH",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({is_active: newState === 1}),
    });
    if (!r.ok) throw new Error((await r.json()).detail || r.statusText);
    _showToast(newState ? "User reactivated" : "User deactivated", "success");
    await loadUsersMgmt();
  } catch (e) {
    _showToast(`Error: ${e.message}`, "danger");
  }
}


// ── Audit log viewer ──────────────────────────────────────────────────────────
async function loadAuditLog() {
  document.querySelectorAll("#settingsCatList .list-group-item").forEach(el => {
    el.classList.toggle("active", el.dataset.cat === "_audit");
  });
  const content = document.getElementById("settingsContent");
  content.innerHTML = '<div class="text-muted py-4 text-center"><span class="spinner-border spinner-border-sm me-2"></span>Loading…</div>';
  try {
    const r = await fetch("/api/audit-log?limit=300");
    if (!r.ok) throw new Error(await r.text());
    const logs = await r.json();
    const rows = logs.map(l => `
      <tr>
        <td style="white-space:nowrap">${(l.timestamp||"").substring(0,19)}</td>
        <td>${_esc(l.username||"")}</td>
        <td><span class="badge bg-secondary">${_esc(l.action||"")}</span></td>
        <td>${_esc(l.resource||"")}</td>
        <td style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap"
            title="${_esc(l.details||"")}">${_esc(l.details||"")}</td>
        <td>${_esc(l.ip_address||"")}</td>
      </tr>`).join("");
    content.innerHTML = `
      <h5 class="settings-section-title">Audit Log</h5>
      <div class="table-responsive" style="max-height:520px;overflow-y:auto">
      <table class="table table-sm table-hover table-bordered" style="font-size:12px;font-family:Consolas,monospace">
        <thead class="table-dark sticky-top">
          <tr><th>Time</th><th>User</th><th>Action</th><th>Resource</th><th>Details</th><th>IP</th></tr>
        </thead>
        <tbody>${rows || '<tr><td colspan="6" class="text-muted text-center">No log entries.</td></tr>'}</tbody>
      </table></div>`;
  } catch (e) {
    content.innerHTML = `<div class="alert alert-danger">${_esc(e.message)}</div>`;
  }
}


// ── Toast helper ──────────────────────────────────────────────────────────────
function _showToast(msg, type = "secondary") {
  let container = document.getElementById("toastContainer");
  if (!container) {
    container = document.createElement("div");
    container.id = "toastContainer";
    container.style.cssText = "position:fixed;bottom:20px;right:20px;z-index:9999;display:flex;flex-direction:column;gap:6px";
    document.body.appendChild(container);
  }
  const el = document.createElement("div");
  el.className = `toast align-items-center text-white bg-${type} border-0 show`;
  el.role = "alert";
  el.innerHTML = `<div class="d-flex"><div class="toast-body">${_esc(msg)}</div>
    <button type="button" class="btn-close btn-close-white me-2 m-auto" onclick="this.closest('.toast').remove()"></button></div>`;
  container.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}

function _esc(s) {
  return String(s ?? "").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
}

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
  const canAdmin = _currentUser?.role === "admin";
  for (const [key, s] of Object.entries(_servers)) {
    const roleBadge = s.role === "source"
      ? '<span class="badge bg-info text-dark" style="font-size:9px">SOURCE</span>'
      : '<span class="badge bg-warning text-dark" style="font-size:9px">TARGET</span>';
    const delBtn = (s.builtin || !canAdmin) ? ""
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
  };
  if (!body.key || !body.ip) { alert("Name and IP are required."); return; }
  const r = await fetch("/api/servers", { method: "POST",
    headers: {"Content-Type": "application/json"}, body: JSON.stringify(body) });
  if (!r.ok) { const e = await r.json().catch(() => ({})); alert(e.detail || `Error ${r.status}`); return; }
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
let _jobsTimeRange = 'all';       // matches the <select> default

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
  const canAdmin = _currentUser?.role === "admin";
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
        <td>${canAdmin ? `<input class="form-check-input snap-chk" type="checkbox" value="${s.name.replace(/"/g, '&quot;')}" onchange="updateDeleteSelectedButton()">` : ''}</td>
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
          ${canAdmin ? `<button class="btn btn-sm btn-link p-0 text-danger" title="Delete"
                  onclick="deleteSnapshot('${s.name.replace(/'/g, "\\'")}')">
            <i class="bi bi-trash3"></i>
          </button>` : ''}
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

// ══════════════════════════════════════════════════════════════════════════════
// QUERY WINDOW
// ══════════════════════════════════════════════════════════════════════════════

const _QRY_HIST_KEY = "vss_qry_history";
const _QRY_HIST_MAX = 40;
let   _qryInited    = false;
let   _qryRunning   = false;

/** Called once when the Query tab is first opened. */
function initQueryTab() {
  if (_qryInited) return;
  _qryInited = true;

  // _populateQryHosts is async; it calls loadQueryDatabases() once the host
  // dropdown is populated — don't call loadQueryDatabases() here separately.
  _populateQryHosts();
  _renderQryHistory();
  _initQrySplitter();

  const ed = document.getElementById("qryEditor");
  if (!ed) return;

  // Ctrl+Enter → run; Tab → 4 spaces
  ed.addEventListener("keydown", e => {
    if (e.ctrlKey && e.key === "Enter") { e.preventDefault(); runQuery(); return; }
    if (e.key === "Tab") {
      e.preventDefault();
      const s = ed.selectionStart, end = ed.selectionEnd;
      ed.value = ed.value.substring(0, s) + "    " + ed.value.substring(end);
      ed.selectionStart = ed.selectionEnd = s + 4;
      _updateQryGutter();
    }
  });
  ed.addEventListener("input",  _updateQryGutter);
  ed.addEventListener("scroll", () => {
    const g = document.getElementById("qryGutter");
    if (g) g.scrollTop = ed.scrollTop;
  });
  _updateQryGutter();
}

function _updateQryGutter() {
  const ed = document.getElementById("qryEditor");
  const g  = document.getElementById("qryGutter");
  if (!ed || !g) return;
  const n = (ed.value.match(/\n/g) || []).length + 1;
  g.textContent = Array.from({length: n}, (_, i) => i + 1).join("\n");
  // widen gutter to fit largest number
  g.style.minWidth = (String(n).length * 8 + 20) + "px";
}

function _initQrySplitter() {
  const handle = document.getElementById("qrySplitHandle");
  const wrap   = document.getElementById("qryEditorWrap");
  if (!handle || !wrap) return;
  let dragging = false, startY = 0, startH = 0;
  handle.addEventListener("mousedown", e => {
    dragging = true; startY = e.clientY; startH = wrap.offsetHeight;
    document.body.style.userSelect = "none";
    document.body.style.cursor = "row-resize";
    e.preventDefault();
  });
  document.addEventListener("mousemove", e => {
    if (!dragging) return;
    const newH = Math.max(60, Math.min(startH + e.clientY - startY, window.innerHeight * 0.72));
    wrap.style.height = newH + "px";
    _updateQryGutter();
  });
  document.addEventListener("mouseup", () => {
    if (!dragging) return;
    dragging = false;
    document.body.style.userSelect = "";
    document.body.style.cursor = "";
  });
}

async function _populateQryHosts() {
  const el = document.getElementById("qryHost");
  if (!el) return;
  // Always fetch fresh from /api/servers so the dropdown is correct even if
  // the Query tab is opened before the initial loadServers() call completes,
  // or after servers are added/removed at runtime.
  try {
    const r    = await fetch("/api/servers");
    const srvs = await r.json();
    const keys = Object.keys(srvs || {});
    el.innerHTML = keys.map(k => `<option value="${k}">${k}</option>`).join("");
    if (keys.length) loadQueryDatabases();  // populate DB list for first host
  } catch (_) { /* keep dropdown empty on network error */ }
}

async function loadQueryDatabases() {
  const host = document.getElementById("qryHost")?.value;
  const dbEl = document.getElementById("qryDatabase");
  if (!host || !dbEl) return;
  dbEl.innerHTML = '<option value="master">master</option>';
  try {
    const r  = await fetch(`/api/databases?host=${encodeURIComponent(host)}`);
    const js = await r.json();
    const fixed = ["master", "msdb", "model"];
    const user  = (js || []).filter(d => !fixed.includes(d.name)).map(d => d.name);
    dbEl.innerHTML = [...fixed, ...user].map(n => `<option value="${n}">${n}</option>`).join("");
  } catch (_) { /* keep master */ }
}

// ── Results / Messages output tab switcher ────────────────────────────────────
function switchQryOutputTab(tab) {
  const rPane = document.getElementById("qryResultsPane");
  const mPane = document.getElementById("qryMessagesPane");
  const rTab  = document.getElementById("qryOutTabResults");
  const mTab  = document.getElementById("qryOutTabMessages");
  if (tab === "results") {
    rPane.style.display = ""; mPane.style.display = "none";
    rTab.classList.add("active"); mTab.classList.remove("active");
  } else {
    mPane.style.display = ""; rPane.style.display = "none";
    mTab.classList.add("active"); rTab.classList.remove("active");
  }
}

function clearQuery() {
  const ed = document.getElementById("qryEditor");
  if (ed) { ed.value = ""; _updateQryGutter(); }
  const rPane = document.getElementById("qryResultsPane");
  if (rPane) rPane.innerHTML = `<div class="text-muted text-center py-5" id="qryPlaceholder">
    <i class="bi bi-play-circle fs-3 d-block mb-2 opacity-25"></i>Run a query to see results</div>`;
  const mPane = document.getElementById("qryMessagesPane");
  if (mPane) mPane.innerHTML = '<span class="qry-msg-info">No messages.</span>';
  const meta = document.getElementById("qryMeta");
  if (meta) meta.classList.add("d-none");
  // Reset badges
  const rb = document.getElementById("qryResultsBadge");
  const mb = document.getElementById("qryMsgBadge");
  if (rb) rb.style.display = "none";
  if (mb) mb.style.display = "none";
  // Keep Results tab active
  switchQryOutputTab("results");
}

async function runQuery() {
  if (_qryRunning) return;
  const host = document.getElementById("qryHost")?.value;
  const db   = document.getElementById("qryDatabase")?.value || "master";
  const sql  = document.getElementById("qryEditor")?.value?.trim();
  if (!host || !sql) return;

  _qryRunning = true;
  const btn    = document.getElementById("qryRunBtn");
  const rPane  = document.getElementById("qryResultsPane");
  const mPane  = document.getElementById("qryMessagesPane");
  const metaEl = document.getElementById("qryMeta");

  if (btn) { btn.disabled = true; btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Running…'; }
  rPane.innerHTML = '<div class="text-muted text-center py-4"><span class="spinner-border spinner-border-sm me-2"></span>Executing…</div>';
  mPane.innerHTML = '<span class="qry-msg-info">Executing…</span>';
  if (metaEl) metaEl.classList.add("d-none");

  try {
    const resp = await fetch("/api/query", {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ host, database: db, sql }),
    });
    const j = await resp.json();
    _renderQryResults(j, metaEl, rPane, mPane);
    _pushQryHistory(sql, host, db);
    _renderQryHistory();
  } catch (e) {
    rPane.innerHTML = `<div class="alert alert-danger m-2"><i class="bi bi-exclamation-triangle me-2"></i>${_qEsc(e.message)}</div>`;
    mPane.innerHTML = `<span class="qry-msg-error">${_qEsc(e.message)}</span>`;
  } finally {
    _qryRunning = false;
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = '<i class="bi bi-play-fill me-1"></i>Run <kbd class="ms-1 text-white border-0 bg-transparent" style="font-size:10px">Ctrl+Enter</kbd>';
    }
  }
}

function _renderQryResults(j, metaEl, rPane, mPane) {
  const elapsed  = j.elapsed_ms ?? 0;
  const finishTs = new Date().toISOString().replace("T", " ").substring(0, 23);
  const rb = document.getElementById("qryResultsBadge");
  const mb = document.getElementById("qryMsgBadge");

  // ── Error path ─────────────────────────────────────────────────────────────
  if (j.error) {
    rPane.innerHTML = `<div class="alert alert-danger m-3"><strong>Error:</strong> ${_qEsc(j.error)}</div>`;
    mPane.innerHTML =
      `<span class="qry-msg-error">${_qEsc(j.error)}</span>\n\n` +
      `<span class="qry-msg-info">Completion time: ${finishTs} (${elapsed}ms)</span>`;
    if (metaEl) { metaEl.textContent = `Error · ${elapsed}ms`; metaEl.className = "small text-danger ms-1"; metaEl.classList.remove("d-none"); }
    if (rb) rb.style.display = "none";
    if (mb) { mb.textContent = "Error"; mb.style.display = ""; }
    // Auto-switch to Messages so the error is visible
    switchQryOutputTab("messages");
    return;
  }

  // ── Success path ───────────────────────────────────────────────────────────
  const results   = j.results || [];
  const totalRows = results.reduce((s, r) => s + r.row_count, 0);

  // Build messages text (SSMS-style)
  let msgs = "";
  if (results.length === 0) {
    msgs += `<span class="qry-msg-ok">Command(s) completed successfully.</span>\n`;
  } else {
    results.forEach((r, i) => {
      if (results.length > 1) msgs += `<span class="qry-msg-info">-- Result set ${i + 1} --</span>\n`;
      msgs += `<span class="qry-msg-info">(${r.row_count} row${r.row_count !== 1 ? "s" : ""} affected)</span>\n`;
      if (r.truncated) msgs += `<span class="qry-msg-error">Warning: results truncated to ${r.row_count} rows.</span>\n`;
    });
  }
  msgs += `\n<span class="qry-msg-info">Completion time: ${finishTs} (${elapsed}ms)</span>`;
  mPane.innerHTML = msgs;

  if (metaEl) {
    metaEl.textContent = results.length
      ? `${totalRows} row(s) · ${elapsed}ms`
      : `OK · ${elapsed}ms`;
    metaEl.className = "small text-muted ms-1";
    metaEl.classList.remove("d-none");
  }

  // Update badges
  if (rb) { rb.textContent = totalRows; rb.style.display = totalRows ? "" : "none"; }
  if (mb) mb.style.display = "none";

  // ── Populate Results pane ──────────────────────────────────────────────────
  if (results.length === 0) {
    rPane.innerHTML = `<div class="text-muted text-center py-4">
      <i class="bi bi-check-circle text-success me-2"></i>Query executed — no rows returned.</div>`;
    switchQryOutputTab("messages");   // no grid → show messages
    return;
  }

  if (results.length === 1) {
    rPane.innerHTML = _qryTable(results[0]);
  } else {
    // Multiple result sets → inner Bootstrap tabs
    const uid = "qrs" + Date.now();
    const navHtml = results.map((r, i) =>
      `<li class="nav-item"><a class="nav-link py-1 px-3 small ${i === 0 ? "active" : ""}"
           data-bs-toggle="tab" href="#${uid}_${i}">
         Result ${i + 1} <span class="badge bg-secondary ms-1">${r.row_count}</span></a></li>`
    ).join("");
    const paneHtml = results.map((r, i) =>
      `<div class="tab-pane fade ${i === 0 ? "show active" : ""}" id="${uid}_${i}"
            style="overflow:auto">${_qryTable(r)}</div>`
    ).join("");
    rPane.innerHTML =
      `<ul class="nav nav-tabs px-2 pt-1 bg-light border-bottom">${navHtml}</ul>` +
      `<div class="tab-content" style="overflow:auto;flex:1">${paneHtml}</div>`;
  }

  switchQryOutputTab("results");
}

function _qryTable(rs) {
  if (!rs?.columns?.length) return '<div class="text-muted text-center py-3 small">Empty result set.</div>';
  // Row-number gutter (col 0 is the row index, styled like SSMS)
  const head = `<th style="background:#e8e8e8;color:#666;width:36px;text-align:right;font-weight:normal;border-right:2px solid #ccc;user-select:none"></th>` +
    rs.columns.map(c => `<th class="text-nowrap" style="background:#dce6f0">${_qEsc(c)}</th>`).join("");
  const body = rs.rows.map((row, ri) =>
    `<tr>${`<td style="background:#f5f5f5;color:#888;text-align:right;border-right:2px solid #ddd;user-select:none;padding:2px 6px;font-size:11px">${ri + 1}</td>` +
      row.map(v => v === null
        ? `<td><em class="text-muted" style="font-size:11px">NULL</em></td>`
        : `<td title="${_qEsc(String(v))}">${_qEsc(String(v))}</td>`
    ).join("")}</tr>`
  ).join("");
  return `<div style="overflow:auto;height:100%">
    <table class="table table-sm table-hover table-bordered mb-0"
           style="font-size:12px;font-family:Consolas,Monaco,monospace;border-collapse:separate;border-spacing:0">
      <thead class="sticky-top"><tr>${head}</tr></thead>
      <tbody>${body}</tbody>
    </table></div>`;
}

// ── Query History ─────────────────────────────────────────────────────────────
function _pushQryHistory(sql, host, db) {
  let h = JSON.parse(localStorage.getItem(_QRY_HIST_KEY) || "[]");
  h = h.filter(e => e.sql !== sql);                      // de-dup
  h.unshift({ sql, host, db, ts: new Date().toISOString() });
  h = h.slice(0, _QRY_HIST_MAX);
  localStorage.setItem(_QRY_HIST_KEY, JSON.stringify(h));
}

function _renderQryHistory() {
  const el = document.getElementById("qryHistoryList");
  if (!el) return;
  const hist = JSON.parse(localStorage.getItem(_QRY_HIST_KEY) || "[]");
  if (!hist.length) {
    el.innerHTML = '<li class="dropdown-item disabled text-muted small">No history yet</li>';
    return;
  }
  el.innerHTML = hist.map((h, i) => {
    const preview = h.sql.replace(/\s+/g, " ").trim().substring(0, 55);
    const ts = new Date(h.ts).toLocaleTimeString([], {hour:"2-digit", minute:"2-digit"});
    return `<li><a class="dropdown-item small py-1" href="#" onclick="_loadQryHistItem(${i});return false">
      <div class="text-truncate" style="max-width:380px" title="${_qEsc(h.sql)}">${_qEsc(preview)}${preview.length >= 55 ? "…" : ""}</div>
      <small class="text-muted">${_qEsc(h.host)} / ${_qEsc(h.db)} · ${ts}</small>
    </a></li>`;
  }).join("") +
  `<li><hr class="dropdown-divider"></li>
   <li><a class="dropdown-item small text-danger" href="#" onclick="_clearQryHistory();return false">
     <i class="bi bi-trash me-1"></i>Clear history</a></li>`;
}

function _loadQryHistItem(i) {
  const hist = JSON.parse(localStorage.getItem(_QRY_HIST_KEY) || "[]");
  const h = hist[i]; if (!h) return;
  const ed = document.getElementById("qryEditor");
  if (ed) { ed.value = h.sql; _updateQryGutter(); }
  const hostEl = document.getElementById("qryHost");
  if (hostEl && h.host) { hostEl.value = h.host; loadQueryDatabases().then(() => {
    const dbEl = document.getElementById("qryDatabase");
    if (dbEl && h.db) dbEl.value = h.db;
  }); }
}

function _clearQryHistory() {
  localStorage.removeItem(_QRY_HIST_KEY);
  _renderQryHistory();
}

// ── vss_developer setup ───────────────────────────────────────────────────────
async function setupDevLogin() {
  const host = document.getElementById("qryHost")?.value;
  if (!host) { showToast("Select a server first.", "warning"); return; }
  const pwd = prompt(
    `Set password for vss_developer on ${host}:\n\n` +
    "The login will get VIEW SERVER STATE, VIEW ANY DATABASE,\n" +
    "db_datareader, db_datawriter on all databases.",
    "Vss@Dev2024!"
  );
  if (!pwd) return;
  const btn = document.querySelector('[onclick="setupDevLogin()"]');
  if (btn) { btn.disabled = true; btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Provisioning…'; }
  try {
    const r = await fetch("/api/setup/dev-login", {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ host, dev_pwd: pwd }),
    });
    const j = await r.json();
    if (!r.ok) throw new Error(j.detail || JSON.stringify(j));
    showToast(`vss_developer provisioned on ${host}`, "success");
    // Show output in a simple alert so the admin can see the per-DB summary
    if (j.output) alert(`Setup complete on ${host}\n\n` + j.output.substring(0, 1200));
  } catch (e) {
    showToast("Setup failed: " + e.message, "danger");
  } finally {
    if (btn) { btn.disabled = false; btn.innerHTML = '<i class="bi bi-shield-check me-1"></i>Setup Login'; }
  }
}

function _qEsc(s) {
  if (s == null) return "";
  return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
}

// ══════════════════════════════════════════════════════════════════════════════
// END QUERY WINDOW
// ══════════════════════════════════════════════════════════════════════════════

// Footer counters: servers + snapshots + jobs. Called from loadServers,
// loadSnapshotsPage, loadJobs — keeps the footer in sync with whatever view
// is currently open without firing extra requests of its own.
function updateFooter() {
  const s = document.getElementById("footServers");
  const p = document.getElementById("footSnaps");
  if (s && typeof _servers !== "undefined" && _servers) s.textContent = _servers.length;
  if (p) p.textContent = (_snapshotCache || []).length;
}
