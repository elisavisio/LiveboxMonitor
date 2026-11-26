(() => {
  'use strict';

  const state = {
    overview: null,
    devices: [],
    topology: null,
    events: [],
    filter: 'active_ip',
    sort: 'name',
    search: '',
    eventSearch: '',
    selectedMac: null,
    graphHours: 24,
    graphDetail: null,
    sse: null,
  };

  // ---------------- Utilities ----------------
  const $ = (id) => document.getElementById(id);

  function esc(str) {
    return String(str ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function formatRate(bps) {
    const bits = (Number(bps) || 0) * 8;
    if (bits >= 1e9) return (bits / 1e9).toFixed(2) + ' Gbps';
    if (bits >= 1e6) return (bits / 1e6).toFixed(2) + ' Mbps';
    if (bits >= 1e3) return (bits / 1e3).toFixed(1) + ' Kbps';
    return Math.round(bits) + ' bps';
  }

  function formatTime(ms) {
    if (!ms) return '—';
    const d = new Date(ms);
    return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  }

  function formatDateTime(ms) {
    if (!ms) return '—';
    const d = new Date(ms);
    return d.toLocaleString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  function ipToNum(ip) {
    if (!ip) return Number.MAX_SAFE_INTEGER;
    const parts = ip.split('.').map(Number);
    if (parts.length !== 4 || parts.some(Number.isNaN)) return Number.MAX_SAFE_INTEGER;
    return (((parts[0] * 256 + parts[1]) * 256 + parts[2]) * 256) + parts[3];
  }

  function linkColor(linkType) {
    switch (linkType) {
      case 'eth': return '#06b6d4';
      case 'wifi6': return '#a855f7';
      case 'wifi5': return '#ff7900';
      case 'wifi24': return '#22c55e';
      case 'guest': return '#f43f5e';
      default: return '#94a3b8';
    }
  }

  function linkBadge(d) {
    const lt = d.linkType || 'eth';
    const label = d.interfaceName || (lt === 'eth' ? 'Ethernet' : 'Wi-Fi');
    const rssi = d.rssi != null ? ` · ${d.rssi} dBm` : '';
    const speed = d.linkSpeedMbps ? ` · ${d.linkSpeedMbps} Mb/s` : '';
    const cls = lt === 'eth' ? 'pill-cyan' : (lt === 'wifi6' ? 'pill-purple' : 'pill-amber');
    const icon = lt === 'eth' ? '🔌' : '📶';
    return `<span class="pill ${cls}">${icon} ${esc(label)}${esc(rssi)}${esc(speed)}</span>`;
  }

  function toast(message, alert = false) {
    const el = document.createElement('div');
    el.className = 'toast' + (alert ? ' toast-alert' : '');
    el.textContent = message;
    $('toast-container').appendChild(el);
    setTimeout(() => el.remove(), 5500);
  }

  async function api(path, options = {}) {
    const res = await fetch(path, {
      headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
      ...options,
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
    return data;
  }

  // ---------------- Theme & Tabs ----------------
  function initTheme() {
    const saved = localStorage.getItem('lbm_theme') || 'dark';
    document.documentElement.setAttribute('data-theme', saved);
    $('btn-theme').textContent = saved === 'dark' ? '☀️ Clair' : '🌙 Sombre';
    $('btn-theme').addEventListener('click', () => {
      const next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('lbm_theme', next);
      $('btn-theme').textContent = next === 'dark' ? '☀️ Clair' : '🌙 Sombre';
      renderTopologySvg();
      if (state.graphDetail) renderCharts();
    });
  }

  function switchTab(name) {
    document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === name));
    document.querySelectorAll('.tab-panel').forEach((p) => p.classList.toggle('active', p.id === `tab-${name}`));
    if (name === 'graphs') {
      loadSelectedDeviceGraphs();
    } else if (name === 'events') {
      loadEvents();
    } else if (name === 'config') {
      loadConfig();
    }
  }

  function openDeviceGraphs(mac) {
    state.selectedMac = mac;
    populateGraphDevicePicker();
    switchTab('graphs');
  }

  // ---------------- Overview & KPIs ----------------
  function renderOverview() {
    const ov = state.overview;
    if (!ov) return;
    const s = ov.stats || {};
    $('header-subtitle').textContent = `${ov.liveboxModel || 'Livebox'} (${ov.liveboxIp || '—'}) · ${ov.statusMessage || ''}`;
    $('btn-sim-device').classList.toggle('hidden', !ov.demoMode);

    $('kpi-active').textContent = s.activeWithIp ?? 0;
    $('kpi-active-sub').textContent = `${s.wifiActive ?? 0} Wi-Fi · ${s.ethActive ?? 0} Ethernet`;
    $('kpi-known').textContent = s.knownDevices ?? 0;
    $('kpi-total-sub').textContent = `${s.totalDevices ?? 0} appareils au total`;
    $('kpi-unknown').textContent = s.unknownDevices ?? 0;
    $('kpi-unknown-sub').textContent = `${s.activeUnknownDevices ?? 0} actif(s) actuellement`;
    $('kpi-bandwidth').textContent = `↓ ${formatRate(s.totalRxBytesPerSec)}`;
    $('kpi-bw-sub').textContent = `↑ ${formatRate(s.totalTxBytesPerSec)}`;
    $('kpi-events').textContent = ov.eventsReceived ?? 0;
    $('kpi-wan-sub').textContent = `WAN : ${ov.wanState || '—'} ${ov.wanIp ? '(' + ov.wanIp + ')' : ''}`;

    const unkBadge = $('tab-unknown-badge');
    const unk = s.unknownDevices || 0;
    unkBadge.textContent = unk;
    unkBadge.classList.toggle('hidden', unk === 0);
  }

  // ---------------- Topology SVG Map + Connection Tree ----------------
  function renderTopology() {
    renderTopologySvg();
    renderTopologyTree();
  }

  function renderTopologySvg() {
    const svg = $('topology-svg');
    const root = state.topology;
    if (!root) {
      svg.innerHTML = `<text x="490" y="250" text-anchor="middle" fill="#94a3b8" font-size="14">Topologie en cours de chargement...</text>`;
      return;
    }

    const isLight = document.documentElement.getAttribute('data-theme') === 'light';
    const cardFill = isLight ? '#ffffff' : '#141a24';
    const textColor = isLight ? '#111827' : '#edf2f7';
    const mutedColor = isLight ? '#64748b' : '#94a3b8';

    const directChildren = root.children || [];
    const repeaters = directChildren.filter((c) => c.role === 'repeater');
    const directDevices = directChildren.filter((c) => c.role !== 'repeater');

    // Collect bottom-level devices grouped by parent
    const leafSlots = [];
    directDevices.forEach((d) => leafSlots.push({ node: d, parentId: root.id }));
    repeaters.forEach((rep) => {
      (rep.children || []).forEach((d) => leafSlots.push({ node: d, parentId: rep.id }));
    });

    const W = Math.max(980, leafSlots.length * 135 + 80);
    const H = repeaters.length > 0 ? 500 : 370;
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);

    const positions = new Map();
    const rootPos = { x: W / 2, y: 66 };
    positions.set(root.id, rootPos);

    // Position repeaters on middle tier
    const repY = 210;
    repeaters.forEach((rep, idx) => {
      const rx = ((idx + 1) / (repeaters.length + 1)) * (W - 160) + 80;
      positions.set(rep.id, { x: rx, y: repY });
    });

    // Position leaf devices on bottom tier
    const leafY = repeaters.length > 0 ? 390 : 255;
    const step = W / Math.max(leafSlots.length, 1);
    leafSlots.forEach((slot, idx) => {
      const x = step * idx + step / 2;
      const y = leafY + (idx % 2 === 0 ? -16 : 26);
      positions.set(slot.node.id, { x, y });
    });

    const lines = [];
    const nodes = [];

    function drawLink(parentPos, childPos, node) {
      const col = linkColor(node.linkType);
      const isWifi = node.linkType !== 'eth';
      const dash = isWifi ? 'stroke-dasharray="6 5"' : '';
      const midX = (parentPos.x + childPos.x) / 2;
      const midY = (parentPos.y + childPos.y) / 2;
      const pathD = `M ${parentPos.x} ${parentPos.y + 26} C ${parentPos.x} ${midY}, ${childPos.x} ${midY}, ${childPos.x} ${childPos.y - 24}`;
      lines.push(`<path d="${pathD}" fill="none" stroke="${col}" stroke-width="${node.active ? 2.4 : 1.3}" ${dash} opacity="${node.active ? 0.9 : 0.35}" />`);
      const lbl = node.rssi != null ? `${node.rssi} dBm` : (node.linkType === 'eth' ? 'ETH' : 'Wi-Fi');
      lines.push(`<rect x="${midX - 24}" y="${midY - 9}" width="48" height="16" rx="8" fill="${cardFill}" stroke="${col}" stroke-width="1" opacity="0.92"/>`);
      lines.push(`<text x="${midX}" y="${midY + 2}" text-anchor="middle" fill="${col}" font-size="9.5" font-weight="700">${esc(lbl)}</text>`);
    }

    // Links: Root -> Repeaters & Root -> Direct Devices
    repeaters.forEach((rep) => drawLink(rootPos, positions.get(rep.id), rep));
    directDevices.forEach((d) => drawLink(rootPos, positions.get(d.id), d));
    // Links: Repeaters -> Children
    repeaters.forEach((rep) => {
      const pPos = positions.get(rep.id);
      (rep.children || []).forEach((d) => drawLink(pPos, positions.get(d.id), d));
    });

    // Draw Livebox root card
    nodes.push(`
      <g class="topo-node" transform="translate(${rootPos.x - 105}, ${rootPos.y - 30})">
        <rect width="210" height="60" rx="14" fill="${cardFill}" stroke="#FF7900" stroke-width="2.5"/>
        <text x="105" y="24" text-anchor="middle" fill="#FF7900" font-size="13.5" font-weight="700">🟠 ${esc(root.name)}</text>
        <text x="105" y="43" text-anchor="middle" fill="${mutedColor}" font-size="11">${esc(root.ipAddress || 'Passerelle')}</text>
      </g>
    `);

    // Draw Repeaters
    repeaters.forEach((rep) => {
      const pos = positions.get(rep.id);
      nodes.push(`
        <g class="topo-node" data-mac="${esc(rep.id)}" transform="translate(${pos.x - 90}, ${pos.y - 26})">
          <rect width="180" height="52" rx="12" fill="${cardFill}" stroke="#06b6d4" stroke-width="2"/>
          <text x="90" y="21" text-anchor="middle" fill="${textColor}" font-size="12" font-weight="700">📡 ${esc(rep.name.slice(0, 22))}</text>
          <text x="90" y="38" text-anchor="middle" fill="${mutedColor}" font-size="10.5">${esc(rep.interfaceLabel)} · ${esc(rep.ipAddress || '')}</text>
        </g>
      `);
    });

    // Draw Leaf Devices
    leafSlots.forEach(({ node }) => {
      const pos = positions.get(node.id);
      const isUnknown = node.trust === 'unknown';
      const stroke = isUnknown ? '#f59e0b' : (node.active ? '#22c55e' : '#475569');
      const shortName = node.name.length > 17 ? node.name.slice(0, 16) + '…' : node.name;
      const bw = node.active ? `↓${formatRate(node.rxBytesPerSec)}` : 'Hors ligne';
      nodes.push(`
        <g class="topo-node" data-mac="${esc(node.id)}" transform="translate(${pos.x - 62}, ${pos.y - 26})">
          <rect width="124" height="58" rx="10" fill="${cardFill}" stroke="${stroke}" stroke-width="${isUnknown ? 2.2 : 1.5}" opacity="${node.active ? 1 : 0.65}"/>
          <circle cx="13" cy="14" r="4.2" fill="${node.active ? '#22c55e' : '#64748b'}"/>
          <text x="23" y="18" fill="${textColor}" font-size="11" font-weight="600">${esc(shortName)}</text>
          <text x="10" y="34" fill="${mutedColor}" font-size="9.5">${esc(node.ipAddress || node.id.slice(-8))}</text>
          <text x="10" y="48" fill="${isUnknown ? '#f59e0b' : '#06b6d4'}" font-size="9.5" font-weight="600">${isUnknown ? '⚠ Inconnu' : esc(bw)}</text>
        </g>
      `);
    });

    svg.innerHTML = lines.join('') + nodes.join('');
    svg.querySelectorAll('.topo-node[data-mac]').forEach((el) => {
      el.addEventListener('click', () => openDeviceGraphs(el.dataset.mac));
    });
  }

  function renderTopologyTree() {
    const box = $('topology-tree');
    const root = state.topology;
    if (!root) {
      box.innerHTML = '<div class="muted-sm">Chargement...</div>';
      return;
    }

    function renderBranch(node) {
      const icon = node.role === 'livebox' ? '🟠' : (node.role === 'repeater' ? '📡' : (node.linkType === 'eth' ? '🔌' : '📶'));
      const statusDot = `<span class="dot ${node.active ? 'dot-green' : 'dot-slate'}"></span>`;
      const trustPill = node.role === 'device'
        ? (node.trust === 'known'
            ? '<span class="pill pill-green">Connu</span>'
            : '<span class="pill pill-amber">Inconnu</span>')
        : '';
      const metaParts = [
        node.interfaceLabel,
        node.ipAddress,
        node.rssi != null ? `${node.rssi} dBm` : null,
        node.active && node.rxBytesPerSec > 0 ? `↓ ${formatRate(node.rxBytesPerSec)}` : null,
      ].filter(Boolean);

      const childrenHtml = (node.children || []).length > 0
        ? `<div class="tree-children">${node.children.map(renderBranch).join('')}</div>`
        : '';

      return `
        <div class="tree-node">
          <div class="tree-row" data-mac="${esc(node.id)}" data-role="${esc(node.role)}">
            <div class="tree-left">
              ${statusDot}
              <span>${icon}</span>
              <div>
                <div class="tree-name">${esc(node.name)}</div>
                <div class="tree-meta mono">${esc(metaParts.join(' · '))}</div>
              </div>
            </div>
            <div>${trustPill}</div>
          </div>
          ${childrenHtml}
        </div>
      `;
    }

    box.innerHTML = renderBranch(root);
    box.querySelectorAll('.tree-row').forEach((row) => {
      if (row.dataset.role !== 'livebox') {
        row.addEventListener('click', () => openDeviceGraphs(row.dataset.mac));
      }
    });
  }

  // ---------------- Devices Table ----------------
  function getFilteredDevices() {
    let list = state.devices.slice();
    switch (state.filter) {
      case 'active_ip':
        list = list.filter((d) => d.active && d.ipAddress && d.ipAddress.trim() !== '');
        break;
      case 'known':
        list = list.filter((d) => d.trust === 'known');
        break;
      case 'unknown':
        list = list.filter((d) => d.trust === 'unknown');
        break;
      case 'wifi':
        list = list.filter((d) => d.linkType !== 'eth');
        break;
      case 'eth':
        list = list.filter((d) => d.linkType === 'eth');
        break;
    }

    const q = state.search.trim().toLowerCase();
    if (q) {
      list = list.filter((d) =>
        (d.name || '').toLowerCase().includes(q) ||
        (d.mac || '').toLowerCase().includes(q) ||
        (d.ipAddress || '').toLowerCase().includes(q) ||
        (d.vendor || '').toLowerCase().includes(q) ||
        (d.note || '').toLowerCase().includes(q)
      );
    }

    list.sort((a, b) => {
      switch (state.sort) {
        case 'ip':
          return ipToNum(a.ipAddress) - ipToNum(b.ipAddress);
        case 'id':
          return (a.mac || '').localeCompare(b.mac || '');
        case 'bandwidth':
          return ((b.rxBytesPerSec || 0) + (b.txBytesPerSec || 0)) - ((a.rxBytesPerSec || 0) + (a.txBytesPerSec || 0));
        case 'trust':
          if (a.trust !== b.trust) return a.trust === 'unknown' ? -1 : 1;
          return (a.name || '').localeCompare(b.name || '');
        case 'name':
        default:
          return (a.name || '').localeCompare(b.name || '', 'fr', { sensitivity: 'base' });
      }
    });
    return list;
  }

  function renderDevicesTable() {
    const tbody = $('devices-tbody');
    const list = getFilteredDevices();
    if (list.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" class="muted" style="text-align:center;padding:24px;">Aucun équipement ne correspond aux filtres.</td></tr>';
      return;
    }

    tbody.innerHTML = list.map((d) => {
      const isKnown = d.trust === 'known';
      return `
        <tr>
          <td>
            <span class="pill ${d.active ? 'pill-green' : 'pill-neutral'}">
              <span class="dot ${d.active ? 'dot-green' : 'dot-slate'}"></span>
              ${d.active ? 'Actif' : 'Hors ligne'}
            </span>
          </td>
          <td>
            <div class="dev-name-main">${esc(d.name)}</div>
            <div class="muted-sm">${esc(d.vendor || d.deviceType)}</div>
            ${d.note ? `<div class="dev-note">📝 ${esc(d.note)}</div>` : ''}
          </td>
          <td class="mono">
            <div>${esc(d.ipAddress || '—')}</div>
            <div class="muted-sm">${esc(d.mac)}</div>
          </td>
          <td>${linkBadge(d)}</td>
          <td class="mono">
            <div>↓ ${formatRate(d.rxBytesPerSec)}</div>
            <div class="muted-sm">↑ ${formatRate(d.txBytesPerSec)}</div>
          </td>
          <td>
            <button class="btn btn-sm ${isKnown ? 'btn-known' : 'btn-unknown'} js-toggle-trust" data-mac="${esc(d.mac)}" data-next="${isKnown ? 'unknown' : 'known'}">
              ${isKnown ? '✓ Connu' : '⚠ Inconnu'}
            </button>
          </td>
          <td>
            <div class="actions-cell">
              <button class="btn btn-sm btn-ghost js-open-graph" data-mac="${esc(d.mac)}">📈 Graphes</button>
              <button class="btn btn-sm btn-ghost js-edit-note" data-mac="${esc(d.mac)}">📝 Note</button>
            </div>
          </td>
        </tr>
      `;
    }).join('');

    tbody.querySelectorAll('.js-toggle-trust').forEach((btn) => {
      btn.addEventListener('click', () => toggleTrust(btn.dataset.mac, btn.dataset.next));
    });
    tbody.querySelectorAll('.js-open-graph').forEach((btn) => {
      btn.addEventListener('click', () => openDeviceGraphs(btn.dataset.mac));
    });
    tbody.querySelectorAll('.js-edit-note').forEach((btn) => {
      btn.addEventListener('click', () => editDeviceNote(btn.dataset.mac));
    });
  }

  async function toggleTrust(mac, nextTrust) {
    try {
      const res = await api(`/api/devices/${encodeURIComponent(mac)}/tag`, {
        method: 'PATCH',
        body: JSON.stringify({ trust: nextTrust }),
      });
      if (res.device) {
        upsertLocalDevice(res.device);
        toast(`${res.device.name} marqué comme ${nextTrust === 'known' ? 'CONNU' : 'INCONNU'}`);
      }
      await refreshOverviewAndTopology();
    } catch (e) {
      toast(`Erreur : ${e.message}`, true);
    }
  }

  async function editDeviceNote(mac) {
    const dev = state.devices.find((d) => d.mac === mac);
    if (!dev) return;
    const note = window.prompt(`Note pour ${dev.name} (${dev.mac}) :`, dev.note || '');
    if (note === null) return;
    try {
      const res = await api(`/api/devices/${encodeURIComponent(mac)}/tag`, {
        method: 'PATCH',
        body: JSON.stringify({ trust: dev.trust, note }),
      });
      if (res.device) {
        upsertLocalDevice(res.device);
        toast('Note enregistrée');
      }
    } catch (e) {
      toast(`Erreur : ${e.message}`, true);
    }
  }

  function upsertLocalDevice(updated) {
    const idx = state.devices.findIndex((d) => d.mac === updated.mac);
    if (idx >= 0) state.devices[idx] = updated;
    else state.devices.unshift(updated);
    renderDevicesTable();
    populateGraphDevicePicker();
    if (state.selectedMac === updated.mac && state.graphDetail) {
      state.graphDetail.device = updated;
      renderGraphMeta();
    }
  }

  // ---------------- Presence & Bandwidth Charts ----------------
  function populateGraphDevicePicker() {
    const sel = $('graph-device-select');
    if (!state.devices.length) return;
    if (!state.selectedMac || !state.devices.some((d) => d.mac === state.selectedMac)) {
      const activeFirst = state.devices.find((d) => d.active) || state.devices[0];
      state.selectedMac = activeFirst.mac;
    }
    sel.innerHTML = state.devices
      .map((d) => `<option value="${esc(d.mac)}" ${d.mac === state.selectedMac ? 'selected' : ''}>${d.active ? '🟢' : '⚪'} ${esc(d.name)} (${esc(d.ipAddress || d.mac)})</option>`)
      .join('');
  }

  async function loadSelectedDeviceGraphs() {
    populateGraphDevicePicker();
    if (!state.selectedMac) return;
    try {
      const detail = await api(`/api/devices/${encodeURIComponent(state.selectedMac)}?hours=${state.graphHours}`);
      state.graphDetail = detail;
      renderGraphMeta();
      renderCharts();
    } catch (e) {
      toast(`Impossible de charger les graphes : ${e.message}`, true);
    }
  }

  function renderGraphMeta() {
    const detail = state.graphDetail;
    if (!detail || !detail.device) return;
    const d = detail.device;
    const isKnown = d.trust === 'known';

    const btn = $('graph-toggle-trust');
    btn.className = `btn btn-sm ${isKnown ? 'btn-known' : 'btn-unknown'}`;
    btn.textContent = isKnown ? '✓ Connu (cliquer pour Inconnu)' : '⚠ Inconnu (marquer Connu)';
    btn.onclick = () => toggleTrust(d.mac, isKnown ? 'unknown' : 'known');

    $('graph-device-meta').innerHTML = `
      <span><strong>MAC :</strong> <code class="mono">${esc(d.mac)}</code></span>
      <span><strong>IP :</strong> <code class="mono">${esc(d.ipAddress || '—')}</code></span>
      <span><strong>Lien :</strong> ${esc(d.interfaceName || d.linkType)}${d.rssi != null ? ` (${d.rssi} dBm)` : ''}</span>
      <span><strong>Première vue :</strong> ${esc(formatDateTime(d.firstSeenMs))}</span>
      <span><strong>Dernière activité :</strong> ${esc(formatDateTime(d.lastSeenMs))}</span>
    `;
    $('presence-uptime-badge').textContent = `Disponibilité (${detail.hours}h) : ${(detail.uptimePercent || 0).toFixed(1)} %`;
  }

  function renderCharts() {
    if (!state.graphDetail) return;
    drawPresenceChart(state.graphDetail.presence || []);
    drawBandwidthChart(state.graphDetail.bandwidth || []);
  }

  function prepCanvas(canvas) {
    const rect = canvas.parentElement.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const w = Math.max(300, rect.width - 16);
    const h = Math.max(80, rect.height - 16);
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    const ctx = canvas.getContext('2d');
    ctx.scale(dpr, dpr);
    return { ctx, w, h };
  }

  function drawPresenceChart(spans) {
    const canvas = $('presence-canvas');
    const tooltip = $('presence-tooltip');
    const { ctx, w, h } = prepCanvas(canvas);
    ctx.clearRect(0, 0, w, h);

    const muted = getComputedStyle(document.documentElement).getPropertyValue('--muted').trim() || '#94a3b8';
    if (!spans.length) {
      ctx.fillStyle = muted;
      ctx.font = '13px sans-serif';
      ctx.fillText('Aucune donnée de présence sur cette période.', 16, h / 2);
      return;
    }

    const padL = 12, padR = 12, padT = 14, barH = h - 44;
    const minTs = spans[0].startMs;
    const maxTs = spans[spans.length - 1].endMs;
    const spanMs = Math.max(1, maxTs - minTs);
    const plotW = w - padL - padR;

    spans.forEach((s) => {
      const x1 = padL + ((s.startMs - minTs) / spanMs) * plotW;
      const x2 = padL + ((s.endMs - minTs) / spanMs) * plotW;
      ctx.fillStyle = s.online ? '#22c55e' : '#334155';
      ctx.fillRect(x1, padT, Math.max(1.5, x2 - x1), barH);
    });

    // Time ticks
    ctx.fillStyle = muted;
    ctx.font = '11px monospace';
    const ticks = 5;
    for (let i = 0; i <= ticks; i++) {
      const ts = minTs + (spanMs * i) / ticks;
      const x = padL + (plotW * i) / ticks;
      const lbl = formatDateTime(ts);
      const align = i === 0 ? 'left' : (i === ticks ? 'right' : 'center');
      ctx.textAlign = align;
      ctx.fillText(lbl, x, h - 8);
    }

    canvas.onmousemove = (e) => {
      const r = canvas.getBoundingClientRect();
      const mx = e.clientX - r.left;
      const ratio = (mx - padL) / plotW;
      if (ratio < 0 || ratio > 1) { tooltip.classList.add('hidden'); return; }
      const ts = minTs + ratio * spanMs;
      const hit = spans.find((s) => ts >= s.startMs && ts <= s.endMs);
      if (!hit) { tooltip.classList.add('hidden'); return; }
      const mins = Math.max(1, Math.round((hit.endMs - hit.startMs) / 60000));
      tooltip.textContent = `${hit.online ? '🟢 En ligne' : '⚪ Hors ligne'} · ${formatDateTime(hit.startMs)} → ${formatDateTime(hit.endMs)} (${mins} min)`;
      tooltip.style.left = Math.min(r.width - 260, Math.max(8, mx + 10)) + 'px';
      tooltip.style.top = '8px';
      tooltip.classList.remove('hidden');
    };
    canvas.onmouseleave = () => tooltip.classList.add('hidden');
  }

  function drawBandwidthChart(points) {
    const canvas = $('bandwidth-canvas');
    const tooltip = $('bandwidth-tooltip');
    const { ctx, w, h } = prepCanvas(canvas);
    ctx.clearRect(0, 0, w, h);

    const muted = getComputedStyle(document.documentElement).getPropertyValue('--muted').trim() || '#94a3b8';
    const border = getComputedStyle(document.documentElement).getPropertyValue('--border').trim() || '#263145';

    if (!points.length) {
      $('bw-summary-stats').textContent = 'En attente d\'échantillons...';
      ctx.fillStyle = muted;
      ctx.font = '13px sans-serif';
      ctx.fillText('Aucun échantillon de bande passante sur cette période.', 16, h / 2);
      return;
    }

    const maxRx = Math.max(...points.map((p) => p.rxBytesPerSec || 0), 0);
    const maxTx = Math.max(...points.map((p) => p.txBytesPerSec || 0), 0);
    const avgRx = points.reduce((s, p) => s + (p.rxBytesPerSec || 0), 0) / points.length;
    const avgTx = points.reduce((s, p) => s + (p.txBytesPerSec || 0), 0) / points.length;
    $('bw-summary-stats').innerHTML = `
      <span style="color:#06b6d4">↓ Pic ${formatRate(maxRx)} · Moy ${formatRate(avgRx)}</span>
      <span style="color:#ff7900">↑ Pic ${formatRate(maxTx)} · Moy ${formatRate(avgTx)}</span>
    `;

    const padL = 74, padR = 16, padT = 16, padB = 30;
    const plotW = w - padL - padR;
    const plotH = h - padT - padB;
    const maxVal = Math.max(maxRx, maxTx, 1024) * 1.15;
    const minTs = points[0].timestampMs;
    const maxTs = Math.max(points[points.length - 1].timestampMs, minTs + 1000);
    const spanMs = maxTs - minTs;

    const xOf = (ts) => padL + ((ts - minTs) / spanMs) * plotW;
    const yOf = (val) => padT + plotH - (val / maxVal) * plotH;

    // Horizontal gridlines
    ctx.strokeStyle = border;
    ctx.fillStyle = muted;
    ctx.font = '11px monospace';
    ctx.textAlign = 'right';
    for (let i = 0; i <= 4; i++) {
      const val = (maxVal * i) / 4;
      const y = yOf(val);
      ctx.beginPath();
      ctx.moveTo(padL, y);
      ctx.lineTo(padL + plotW, y);
      ctx.stroke();
      ctx.fillText(formatRate(val), padL - 8, y + 4);
    }

    // Time axis
    ctx.textAlign = 'center';
    for (let i = 0; i <= 4; i++) {
      const ts = minTs + (spanMs * i) / 4;
      const x = xOf(ts);
      ctx.fillText(formatDateTime(ts), x, h - 8);
    }

    function drawSeries(key, strokeColor, fillColor) {
      ctx.beginPath();
      points.forEach((pt, idx) => {
        const x = xOf(pt.timestampMs);
        const y = yOf(pt[key] || 0);
        if (idx === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      });
      ctx.strokeStyle = strokeColor;
      ctx.lineWidth = 2;
      ctx.stroke();

      // Fill under curve
      ctx.lineTo(xOf(points[points.length - 1].timestampMs), padT + plotH);
      ctx.lineTo(xOf(points[0].timestampMs), padT + plotH);
      ctx.closePath();
      ctx.fillStyle = fillColor;
      ctx.fill();
    }

    drawSeries('rxBytesPerSec', '#06b6d4', 'rgba(6, 182, 212, 0.16)');
    drawSeries('txBytesPerSec', '#ff7900', 'rgba(255, 121, 0, 0.14)');

    canvas.onmousemove = (e) => {
      const r = canvas.getBoundingClientRect();
      const mx = e.clientX - r.left;
      const ratio = (mx - padL) / plotW;
      if (ratio < 0 || ratio > 1) { tooltip.classList.add('hidden'); return; }
      const targetTs = minTs + ratio * spanMs;
      let nearest = points[0];
      let best = Math.abs(points[0].timestampMs - targetTs);
      for (const pt of points) {
        const d = Math.abs(pt.timestampMs - targetTs);
        if (d < best) { best = d; nearest = pt; }
      }
      tooltip.innerHTML = `<strong>${formatDateTime(nearest.timestampMs)}</strong><br/>↓ ${formatRate(nearest.rxBytesPerSec)} · ↑ ${formatRate(nearest.txBytesPerSec)}`;
      tooltip.style.left = Math.min(r.width - 190, Math.max(padL, mx + 12)) + 'px';
      tooltip.style.top = '12px';
      tooltip.classList.remove('hidden');
    };
    canvas.onmouseleave = () => tooltip.classList.add('hidden');
  }

  // ---------------- Events Table ----------------
  async function loadEvents() {
    try {
      const res = await api('/api/events?limit=150');
      state.events = res.events || [];
      renderEventsTable();
    } catch (e) {
      toast(`Erreur événements : ${e.message}`, true);
    }
  }

  function renderEventsTable() {
    const tbody = $('events-tbody');
    const q = state.eventSearch.trim().toLowerCase();
    const list = state.events.filter((ev) => {
      if (!q) return true;
      return (ev.deviceName || '').toLowerCase().includes(q) ||
        (ev.deviceMac || '').toLowerCase().includes(q) ||
        (ev.reason || '').toLowerCase().includes(q) ||
        (ev.summary || '').toLowerCase().includes(q);
    });

    if (!list.length) {
      tbody.innerHTML = '<tr><td colspan="5" class="muted" style="text-align:center;padding:24px;">Aucun événement enregistré.</td></tr>';
      return;
    }

    tbody.innerHTML = list.map((ev, idx) => {
      const reasonCls = ev.reason === 'new_device' ? 'pill-amber'
        : ev.reason === 'email_sent' ? 'pill-green'
        : ev.reason === 'email_error' ? 'pill-red'
        : 'pill-neutral';
      return `
        <tr>
          <td class="mono">${esc(formatTime(ev.timestampMs))}</td>
          <td><span class="pill ${reasonCls}">${esc(ev.reason)}</span></td>
          <td>
            <div class="dev-name-main">${esc(ev.deviceName)}</div>
            <div class="muted-sm mono">${esc(ev.deviceMac)}</div>
          </td>
          <td>${esc(ev.summary)}</td>
          <td><button class="btn btn-sm btn-ghost js-show-raw" data-idx="${idx}">JSON</button></td>
        </tr>
      `;
    }).join('');

    tbody.querySelectorAll('.js-show-raw').forEach((btn) => {
      btn.addEventListener('click', () => {
        const ev = list[Number(btn.dataset.idx)];
        let pretty = ev.rawJson || '{}';
        try { pretty = JSON.stringify(JSON.parse(pretty), null, 2); } catch (_) {}
        showModal(`Événement : ${ev.reason} (${ev.deviceMac})`, `<pre class="modal-pre">${esc(pretty)}</pre>`);
      });
    });
  }

  // ---------------- Config Forms ----------------
  async function loadConfig() {
    try {
      const [lb, smtp] = await Promise.all([api('/api/config/livebox'), api('/api/config/smtp')]);
      const lc = lb.config || {};
      $('cfg-lb-url').value = lc.url || 'http://livebox.home/';
      $('cfg-lb-user').value = lc.username || 'admin';
      $('cfg-lb-pass').value = '';
      $('cfg-lb-demo').checked = !!lc.demoMode;
      $('cfg-lb-pass-hint').textContent = lc.hasPassword
        ? '✓ Un mot de passe chiffré est enregistré dans le coffre.'
        : 'Aucun mot de passe enregistré pour l\'instant.';
      $('vault-badge').textContent = `🔒 ${lb.vault?.algorithm || 'AES-256-GCM'} (${lb.vault?.keySource || 'vault'})`;

      const sc = smtp.config || {};
      $('cfg-smtp-enabled').checked = !!sc.enabled;
      $('cfg-smtp-host').value = sc.host || '';
      $('cfg-smtp-port').value = sc.port || 587;
      $('cfg-smtp-user').value = sc.username || '';
      $('cfg-smtp-pass').value = '';
      $('cfg-smtp-pass').placeholder = sc.hasPassword ? '•••••••• (enregistré — laisser vide pour conserver)' : 'Mot de passe SMTP';
      $('cfg-smtp-from').value = sc.fromAddress || '';
      $('cfg-smtp-to').value = sc.toAddresses || '';
      $('cfg-smtp-ssl').checked = !!sc.useSsl;
      $('cfg-smtp-insecure').checked = !!sc.allowInsecure;
    } catch (e) {
      toast(`Erreur config : ${e.message}`, true);
    }
  }

  function initConfigForms() {
    $('livebox-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const msg = $('cfg-lb-msg');
      msg.textContent = 'Enregistrement...';
      try {
        await api('/api/config/livebox', {
          method: 'POST',
          body: JSON.stringify({
            url: $('cfg-lb-url').value,
            username: $('cfg-lb-user').value,
            password: $('cfg-lb-pass').value || undefined,
            demoMode: $('cfg-lb-demo').checked,
          }),
        });
        $('cfg-lb-pass').value = '';
        msg.textContent = '✓ Enregistré et chiffré !';
        msg.className = 'form-msg text-green';
        await loadAll();
      } catch (err) {
        msg.textContent = `✗ ${err.message}`;
        msg.className = 'form-msg text-red';
      }
    });

    $('smtp-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const msg = $('cfg-smtp-msg');
      msg.textContent = 'Enregistrement...';
      try {
        await api('/api/config/smtp', {
          method: 'POST',
          body: JSON.stringify(readSmtpFormPayload()),
        });
        $('cfg-smtp-pass').value = '';
        msg.textContent = '✓ Configuration SMTP chiffrée et enregistrée !';
        msg.className = 'form-msg text-green';
      } catch (err) {
        msg.textContent = `✗ ${err.message}`;
        msg.className = 'form-msg text-red';
      }
    });

    $('btn-smtp-test').addEventListener('click', async () => {
      const msg = $('cfg-smtp-msg');
      msg.textContent = 'Envoi du mail de test...';
      try {
        const res = await api('/api/config/smtp_test', {
          method: 'POST',
          body: JSON.stringify(readSmtpFormPayload()),
        });
        msg.textContent = `✓ ${res.message || 'Email envoyé !'}`;
        msg.className = 'form-msg text-green';
        toast('Email de test envoyé avec succès !');
      } catch (err) {
        msg.textContent = `✗ ${err.message}`;
        msg.className = 'form-msg text-red';
      }
    });
  }

  function readSmtpFormPayload() {
    return {
      enabled: $('cfg-smtp-enabled').checked,
      host: $('cfg-smtp-host').value,
      port: Number($('cfg-smtp-port').value) || 587,
      useSsl: $('cfg-smtp-ssl').checked,
      allowInsecure: $('cfg-smtp-insecure').checked,
      username: $('cfg-smtp-user').value,
      password: $('cfg-smtp-pass').value || undefined,
      fromAddress: $('cfg-smtp-from').value,
      toAddresses: $('cfg-smtp-to').value,
    };
  }

  // ---------------- Modal ----------------
  function showModal(title, html) {
    $('modal-title').textContent = title;
    $('modal-body').innerHTML = html;
    $('modal-backdrop').classList.remove('hidden');
  }

  // ---------------- SSE Real-Time Stream ----------------
  function connectSse() {
    if (state.sse) state.sse.close();
    const badge = $('sse-badge');
    const es = new EventSource('/api/stream');
    state.sse = es;

    es.onopen = () => {
      badge.className = 'pill pill-green';
      badge.innerHTML = '<span class="dot dot-green"></span> Flux temps réel';
    };

    es.onerror = () => {
      badge.className = 'pill pill-amber';
      badge.innerHTML = '<span class="dot dot-amber"></span> Reconnexion flux...';
    };

    es.addEventListener('overview', (e) => {
      state.overview = JSON.parse(e.data);
      renderOverview();
    });

    es.addEventListener('status', () => refreshOverviewAndTopology());

    es.addEventListener('device_update', (e) => {
      upsertLocalDevice(JSON.parse(e.data));
      refreshOverviewAndTopology();
    });

    es.addEventListener('new_device', (e) => {
      const payload = JSON.parse(e.data);
      toast(`🚨 ${payload.message || 'Nouvel équipement inconnu détecté !'}`, true);
      loadAll();
    });

    es.addEventListener('event', (e) => {
      const ev = JSON.parse(e.data);
      state.events.unshift(ev);
      if (state.events.length > 250) state.events.pop();
      renderEventsTable();
    });

    es.addEventListener('topology', (e) => {
      state.topology = JSON.parse(e.data);
      renderTopology();
    });

    es.addEventListener('tick', () => {
      // Lightweight periodic refresh of rates & overview
      refreshDevicesAndOverview();
    });

    es.addEventListener('bandwidth', (e) => {
      const b = JSON.parse(e.data);
      const dev = state.devices.find((d) => d.mac === b.mac);
      if (dev) {
        dev.rxBytesPerSec = b.rxBytesPerSec;
        dev.txBytesPerSec = b.txBytesPerSec;
        renderDevicesTable();
      }
    });
  }

  async function refreshDevicesAndOverview() {
    try {
      const [ov, devs] = await Promise.all([api('/api/overview'), api('/api/devices')]);
      state.overview = ov;
      state.devices = devs.devices || [];
      renderOverview();
      renderDevicesTable();
      if (document.getElementById('tab-graphs').classList.contains('active')) {
        loadSelectedDeviceGraphs();
      }
    } catch (_) {}
  }

  async function refreshOverviewAndTopology() {
    try {
      const [ov, topo] = await Promise.all([api('/api/overview'), api('/api/topology')]);
      state.overview = ov;
      state.topology = topo.topology;
      renderOverview();
      renderTopology();
    } catch (_) {}
  }

  async function loadAll() {
    try {
      const [ov, devs, topo, evs] = await Promise.all([
        api('/api/overview'),
        api('/api/devices'),
        api('/api/topology'),
        api('/api/events?limit=150'),
      ]);
      state.overview = ov;
      state.devices = devs.devices || [];
      state.topology = topo.topology;
      state.events = evs.events || [];
      renderOverview();
      renderTopology();
      renderDevicesTable();
      populateGraphDevicePicker();
      renderEventsTable();
    } catch (e) {
      toast(`Erreur de chargement : ${e.message}`, true);
    }
  }

  // ---------------- Boot ----------------
  function init() {
    initTheme();
    initConfigForms();

    document.querySelectorAll('.tab').forEach((btn) => {
      btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    $('device-filters').querySelectorAll('.chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        $('device-filters').querySelectorAll('.chip').forEach((c) => c.classList.remove('active'));
        chip.classList.add('active');
        state.filter = chip.dataset.filter;
        renderDevicesTable();
      });
    });

    $('device-search').addEventListener('input', (e) => {
      state.search = e.target.value;
      renderDevicesTable();
    });

    $('device-sort').addEventListener('change', (e) => {
      state.sort = e.target.value;
      renderDevicesTable();
    });

    $('graph-device-select').addEventListener('change', (e) => {
      state.selectedMac = e.target.value;
      loadSelectedDeviceGraphs();
    });

    $('graph-range-chips').querySelectorAll('.chip').forEach((chip) => {
      chip.addEventListener('click', () => {
        $('graph-range-chips').querySelectorAll('.chip').forEach((c) => c.classList.remove('active'));
        chip.classList.add('active');
        state.graphHours = Number(chip.dataset.hours) || 24;
        loadSelectedDeviceGraphs();
      });
    });

    $('event-search').addEventListener('input', (e) => {
      state.eventSearch = e.target.value;
      renderEventsTable();
    });

    $('btn-refresh-events').addEventListener('click', loadEvents);
    $('btn-refresh-topo').addEventListener('click', refreshOverviewAndTopology);

    $('btn-sim-device').addEventListener('click', async () => {
      try {
        await api('/api/demo/new_device', { method: 'POST' });
      } catch (e) {
        toast(`Erreur simulation : ${e.message}`, true);
      }
    });

    $('modal-close').addEventListener('click', () => $('modal-backdrop').classList.add('hidden'));
    $('modal-backdrop').addEventListener('click', (e) => {
      if (e.target === $('modal-backdrop')) $('modal-backdrop').classList.add('hidden');
    });

    window.addEventListener('resize', () => {
      if (state.graphDetail && document.getElementById('tab-graphs').classList.contains('active')) {
        renderCharts();
      }
    });

    loadAll();
    connectSse();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
