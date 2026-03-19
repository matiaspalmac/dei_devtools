// ═══════════════════════════════════════════════
// dei_devtools | App.js - Main NUI Application
// ═══════════════════════════════════════════════

(() => {
    'use strict';

    // ── State ──
    const state = {
        visible: false,
        minimized: false,
        activeTab: 'resmon',
        superAdmin: false,
        isPaused: false,
        consoleScope: 'client',
        consoleMode: 'command',
        commandHistory: [],
        historyIndex: -1,
        resmonSort: 'name',
        eventFilter: 'all',
        eventEntries: [],
        nuiEntries: [],
        networkHistory: [],
        playerCoords: null,
        playerHeading: null,
        dragOffset: { x: 0, y: 0 },
        isDragging: false,
        isBrowser: !window.invokeNative
    };

    // ── DOM Cache ──
    const $ = id => document.getElementById(id);
    const el = {
        devtools: $('devtools'),
        devtoolsMin: $('devtoolsMin'),
        dragHandle: $('dragHandle'),
        opacitySlider: $('opacitySlider'),
        btnMinimize: $('btnMinimize'),
        btnClose: $('btnClose'),
        tabConsole: $('tabConsole'),
        // Resmon
        serverTick: $('serverTick'),
        resCount: $('resCount'),
        resmonSearch: $('resmonSearch'),
        resmonList: $('resmonList'),
        // Events
        btnPause: $('btnPause'),
        btnClearEvents: $('btnClearEvents'),
        eventSearch: $('eventSearch'),
        eventList: $('eventList'),
        watchEventInput: $('watchEventInput'),
        btnWatchEvent: $('btnWatchEvent'),
        // Entities
        countPeds: $('countPeds'),
        countVehs: $('countVehs'),
        countObjs: $('countObjs'),
        countPickups: $('countPickups'),
        countTotal: $('countTotal'),
        entityWarning: $('entityWarning'),
        btnRaycast: $('btnRaycast'),
        entityList: $('entityList'),
        entityDetail: $('entityDetail'),
        // Player
        playerX: $('playerX'),
        playerY: $('playerY'),
        playerZ: $('playerZ'),
        playerHeading: $('playerHeading'),
        playerHealth: $('playerHealth'),
        playerArmor: $('playerArmor'),
        playerSpeed: $('playerSpeed'),
        playerServerId: $('playerServerId'),
        playerClientId: $('playerClientId'),
        playerJob: $('playerJob'),
        playerFramework: $('playerFramework'),
        vehicleSection: $('vehicleSection'),
        vehicleData: $('vehicleData'),
        identifiersList: $('identifiersList'),
        btnCopyCoords: $('btnCopyCoords'),
        btnCopyHeading: $('btnCopyHeading'),
        // Network
        netPing: $('netPing'),
        netEps: $('netEps'),
        netChart: $('netChart'),
        netEndpoint: $('netEndpoint'),
        netIncoming: $('netIncoming'),
        netOutgoing: $('netOutgoing'),
        // NUI
        nuiCount: $('nuiCount'),
        nuiSearch: $('nuiSearch'),
        nuiList: $('nuiList'),
        // Console
        consoleOutput: $('consoleOutput'),
        consoleInput: $('consoleInput'),
        btnExecute: $('btnExecute')
    };

    // ── NUI Communication ──
    function post(event, data = {}) {
        if (state.isBrowser) return Promise.resolve({});
        return fetch(`https://dei_devtools/${event}`, {
            method: 'POST',
            body: JSON.stringify(data)
        }).catch(() => {});
    }

    // ── Message Handler ──
    window.addEventListener('message', (evt) => {
        const { action } = evt.data;
        if (!action) return;

        const handlers = {
            toggle: handleToggle,
            setTheme: handleTheme,
            authResult: handleAuth,
            resmonData: renderResmon,
            eventLogData: renderEventLog,
            eventEntry: addEventEntry,
            entityData: renderEntities,
            entityInspect: renderEntityDetail,
            playerData: renderPlayerData,
            playerServerData: renderPlayerServerData,
            netStatsData: renderNetStats,
            networkHistory: renderNetworkChart,
            nuiLogData: renderNuiLog,
            nuiEntry: addNuiEntry,
            consoleOutput: addConsoleOutput
        };

        if (handlers[action]) handlers[action](evt.data);
    });

    // ── Toggle ──
    function handleToggle(data) {
        state.visible = data.show;
        if (data.show) {
            el.devtools.classList.remove('hidden');
            el.devtools.classList.add('visible');
            el.devtoolsMin.classList.add('hidden');
            state.minimized = false;
            if (data.theme) handleTheme(data);
            if (data.superAdmin) {
                state.superAdmin = true;
                el.tabConsole.style.display = '';
            }
            if (data.opacity) {
                el.opacitySlider.value = data.opacity;
                el.devtools.style.opacity = data.opacity / 100;
            }
        } else {
            el.devtools.classList.add('hidden');
            el.devtools.classList.remove('visible');
            el.devtoolsMin.classList.add('hidden');
        }
    }

    function handleTheme(data) {
        document.body.setAttribute('data-theme', data.theme || 'dark');
        if (data.lightMode) {
            document.body.classList.add('light-mode');
        } else {
            document.body.classList.remove('light-mode');
        }
    }

    function handleAuth(data) {
        if (data.superAdmin) {
            state.superAdmin = true;
            el.tabConsole.style.display = '';
        }
    }

    // ── Tab Management ──
    document.querySelectorAll('.dt-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            const tabName = tab.dataset.tab;
            state.activeTab = tabName;

            document.querySelectorAll('.dt-tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');

            document.querySelectorAll('.dt-panel').forEach(p => p.classList.remove('active'));
            const panel = $(`panel-${tabName}`);
            if (panel) panel.classList.add('active');

            post('tabChange', { tab: tabName });
        });
    });

    // ── Header Controls ──
    el.btnClose.addEventListener('click', () => {
        state.visible = false;
        el.devtools.classList.add('hidden');
        el.devtools.classList.remove('visible');
        post('close');
    });

    el.btnMinimize.addEventListener('click', () => {
        state.minimized = true;
        el.devtools.classList.add('hidden');
        el.devtools.classList.remove('visible');
        el.devtoolsMin.classList.remove('hidden');
    });

    el.devtoolsMin.addEventListener('click', () => {
        state.minimized = false;
        el.devtools.classList.remove('hidden');
        el.devtools.classList.add('visible');
        el.devtoolsMin.classList.add('hidden');
    });

    el.opacitySlider.addEventListener('input', () => {
        el.devtools.style.opacity = el.opacitySlider.value / 100;
    });

    // ── Drag ──
    el.dragHandle.addEventListener('mousedown', (e) => {
        if (e.target.closest('.dt-controls')) return;
        state.isDragging = true;
        const rect = el.devtools.getBoundingClientRect();
        state.dragOffset.x = e.clientX - rect.left;
        state.dragOffset.y = e.clientY - rect.top;
        el.devtools.style.transition = 'none';
    });

    window.addEventListener('mousemove', (e) => {
        if (!state.isDragging) return;
        const x = e.clientX - state.dragOffset.x;
        const y = e.clientY - state.dragOffset.y;
        el.devtools.style.left = x + 'px';
        el.devtools.style.top = y + 'px';
        el.devtools.style.right = 'auto';
    });

    window.addEventListener('mouseup', () => {
        if (state.isDragging) {
            state.isDragging = false;
            el.devtools.style.transition = '';
        }
    });

    // ── Keyboard ──
    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && state.visible) {
            state.visible = false;
            el.devtools.classList.add('hidden');
            el.devtools.classList.remove('visible');
            post('close');
        }
    });

    // ══════════════════════════════════
    // RESMON TAB
    // ══════════════════════════════════

    let resmonData = [];

    document.querySelectorAll('.sort-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.sort-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.resmonSort = btn.dataset.sort;
            renderResmonList();
        });
    });

    el.resmonSearch.addEventListener('input', renderResmonList);

    function renderResmon(data) {
        resmonData = data.resources || [];
        const avgTick = data.avgTick || 0;
        el.serverTick.textContent = avgTick.toFixed(2) + ' ms';
        el.resCount.textContent = resmonData.length;
        renderResmonList();
    }

    function getResmonColor(ms) {
        if (ms < 0.05) return 'green';
        if (ms < 0.15) return 'yellow';
        if (ms < 0.30) return 'orange';
        return 'red';
    }

    function renderResmonList() {
        const search = el.resmonSearch.value.toLowerCase();
        let filtered = resmonData.filter(r => r.name.toLowerCase().includes(search));

        if (state.resmonSort === 'ms') {
            filtered.sort((a, b) => b.ms - a.ms);
        } else {
            filtered.sort((a, b) => a.name.localeCompare(b.name));
        }

        const maxMs = Math.max(...filtered.map(r => r.ms), 0.3);

        el.resmonList.innerHTML = filtered.map(r => {
            const color = getResmonColor(r.ms);
            const barWidth = Math.min((r.ms / maxMs) * 100, 100);
            return `<div class="resmon-item">
                <span class="resmon-name">${escHtml(r.name)}</span>
                <div class="resmon-bar"><div class="resmon-bar-fill bar-${color}" style="width:${barWidth}%"></div></div>
                <span class="resmon-ms resmon-${color}">${r.ms.toFixed(4)} ms</span>
            </div>`;
        }).join('');
    }

    // ══════════════════════════════════
    // EVENTS TAB
    // ══════════════════════════════════

    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.eventFilter = btn.dataset.filter;
            renderEventList();
        });
    });

    el.eventSearch.addEventListener('input', renderEventList);

    el.btnPause.addEventListener('click', () => {
        state.isPaused = !state.isPaused;
        el.btnPause.classList.toggle('active-state', state.isPaused);
        el.btnPause.innerHTML = state.isPaused
            ? `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg> Reanudar`
            : `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect></svg> Pausar`;
        post('togglePause');
    });

    el.btnClearEvents.addEventListener('click', () => {
        state.eventEntries = [];
        el.eventList.innerHTML = '';
        post('clearEventLog');
    });

    el.btnWatchEvent.addEventListener('click', () => {
        const name = el.watchEventInput.value.trim();
        if (name) {
            post('watchEvent', { eventName: name });
            el.watchEventInput.value = '';
            addConsoleOutput({ data: { type: 'info', text: `Watching event: ${name}` } });
        }
    });

    function renderEventLog(data) {
        state.eventEntries = data.entries || [];
        renderEventList();
    }

    function addEventEntry(data) {
        if (state.isPaused) return;
        const entry = data.entry;
        state.eventEntries.push(entry);
        if (state.eventEntries.length > 200) state.eventEntries.shift();
        if (state.activeTab === 'events') renderEventList();
    }

    function renderEventList() {
        const search = el.eventSearch.value.toLowerCase();
        let entries = state.eventEntries.filter(e => {
            if (search && !e.name.toLowerCase().includes(search)) return false;
            if (state.eventFilter !== 'all' && e.direction !== state.eventFilter) return false;
            return true;
        });

        // Show newest first
        entries = entries.slice().reverse().slice(0, 100);

        el.eventList.innerHTML = entries.map(e => {
            const badgeClass = e.direction === 'c2s' ? 'badge-c2s' : 'badge-s2c';
            const badgeText = e.direction === 'c2s' ? 'C → S' : 'S → C';
            return `<div class="event-item">
                <div class="event-top">
                    <span class="event-badge ${badgeClass}">${badgeText}</span>
                    <span class="event-name">${escHtml(e.name)}</span>
                    <span class="event-time">${e.time || '--'}</span>
                </div>
                <div class="event-meta">
                    <span>Source: ${e.source || '-'}</span>
                    <span>Size: ${formatBytes(e.size || 0)}</span>
                </div>
            </div>`;
        }).join('');
    }

    // ══════════════════════════════════
    // ENTITIES TAB
    // ══════════════════════════════════

    el.btnRaycast.addEventListener('click', () => {
        post('raycastInspect');
    });

    function renderEntities(data) {
        const c = data.counts || {};
        el.countPeds.textContent = c.peds || 0;
        el.countVehs.textContent = c.vehicles || 0;
        el.countObjs.textContent = c.objects || 0;
        el.countPickups.textContent = c.pickups || 0;
        el.countTotal.textContent = c.total || 0;

        // Warning threshold
        if ((c.total || 0) > 500) {
            el.entityWarning.classList.remove('hidden');
        } else {
            el.entityWarning.classList.add('hidden');
        }

        const nearby = data.nearby || [];
        el.entityList.innerHTML = nearby.map(e => {
            const typeClass = `type-${e.type}`;
            const typeLabel = e.type.charAt(0).toUpperCase() + e.type.slice(1);
            return `<div class="entity-item" onclick="window.inspectEntity(${e.netId}, '${e.type}')">
                <span class="entity-type-badge ${typeClass}">${typeLabel}</span>
                <div class="entity-info">
                    <span class="entity-model">0x${(e.model >>> 0).toString(16).toUpperCase()}</span>
                    <span class="entity-sub">Net: ${e.netId} | Owner: ${e.owner}</span>
                </div>
                <span class="entity-dist">${e.distance}m</span>
            </div>`;
        }).join('');
    }

    window.inspectEntity = (netId, type) => {
        post('inspectEntity', { netId, entityType: type });
    };

    function renderEntityDetail(data) {
        if (!data.data) {
            el.entityDetail.classList.add('hidden');
            return;
        }
        const d = data.data;
        el.entityDetail.classList.remove('hidden');

        let html = `<h4>Entity Inspector</h4><div class="data-grid">`;
        html += dataRow('Type', d.entityType);
        html += dataRow('Model', d.modelName);
        html += dataRow('Health', `${d.health} / ${d.maxHealth}`);
        html += dataRow('Coords', `${d.coords.x}, ${d.coords.y}, ${d.coords.z}`);
        html += dataRow('Heading', d.heading);
        html += dataRow('Speed', `${d.speed} km/h`);
        html += dataRow('Net ID', d.netId);
        if (d.plate) html += dataRow('Plate', d.plate);
        if (d.engineHealth !== undefined) html += dataRow('Engine', d.engineHealth);
        if (d.bodyHealth !== undefined) html += dataRow('Body', d.bodyHealth);
        html += `</div>`;

        el.entityDetail.innerHTML = html;
    }

    // ══════════════════════════════════
    // PLAYER TAB
    // ══════════════════════════════════

    function renderPlayerData(data) {
        const d = data.data;
        if (!d) return;
        state.playerCoords = d.coords;
        state.playerHeading = d.heading;

        el.playerX.textContent = d.coords.x;
        el.playerY.textContent = d.coords.y;
        el.playerZ.textContent = d.coords.z;
        el.playerHeading.textContent = d.heading;
        el.playerHealth.textContent = `${d.health} / ${d.maxHealth}`;
        el.playerArmor.textContent = d.armor;
        el.playerSpeed.textContent = `${d.speed} km/h`;
        el.playerServerId.textContent = d.serverId;
        el.playerClientId.textContent = d.clientId;

        // Vehicle
        if (d.vehicle) {
            el.vehicleSection.style.display = '';
            el.vehicleData.innerHTML =
                dataRow('Model', d.vehicle.displayName) +
                dataRow('Hash', d.vehicle.model) +
                dataRow('Plate', d.vehicle.plate) +
                dataRow('Speed', `${d.vehicle.speed} km/h`) +
                dataRow('RPM', d.vehicle.rpm) +
                dataRow('Gear', d.vehicle.gear) +
                dataRow('Engine', d.vehicle.engineHealth) +
                dataRow('Body', d.vehicle.bodyHealth) +
                dataRow('Fuel', `${d.vehicle.fuel}%`);
        } else {
            el.vehicleSection.style.display = 'none';
        }
    }

    function renderPlayerServerData(data) {
        const d = data.data;
        if (!d) return;
        el.playerJob.textContent = `${d.job} (${d.jobGrade})`;
        el.playerFramework.textContent = d.framework || '--';

        // Identifiers
        if (d.identifiers) {
            el.identifiersList.innerHTML = Object.entries(d.identifiers).map(([k, v]) =>
                dataRow(k, v)
            ).join('');
        }
    }

    el.btnCopyCoords.addEventListener('click', () => {
        if (state.playerCoords) {
            const text = `vector3(${state.playerCoords.x}, ${state.playerCoords.y}, ${state.playerCoords.z})`;
            copyText(text);
            flashCopied(el.btnCopyCoords);
        }
    });

    el.btnCopyHeading.addEventListener('click', () => {
        if (state.playerHeading !== null) {
            copyText(String(state.playerHeading));
            flashCopied(el.btnCopyHeading);
        }
    });

    // ══════════════════════════════════
    // NETWORK TAB
    // ══════════════════════════════════

    function renderNetStats(data) {
        const d = data.data;
        if (!d) return;
        el.netPing.textContent = `${d.ping} ms`;
        el.netEps.textContent = d.eventsPerSecond;
        el.netEndpoint.textContent = d.endpoint || '--';
    }

    function renderNetworkChart(data) {
        const history = data.history || [];
        state.networkHistory = history;

        const canvas = el.netChart;
        const ctx = canvas.getContext('2d');
        const w = canvas.width = canvas.offsetWidth * 2;
        const h = canvas.height = 280;
        ctx.clearRect(0, 0, w, h);

        if (history.length < 2) {
            ctx.fillStyle = 'rgba(255,255,255,0.1)';
            ctx.font = '22px Gilroy';
            ctx.textAlign = 'center';
            ctx.fillText('Esperando datos...', w / 2, h / 2);
            return;
        }

        const values = history.map(h => (h.incoming || 0) + (h.outgoing || 0));
        const max = Math.max(...values, 5);
        const padding = { top: 20, right: 20, bottom: 30, left: 40 };
        const plotW = w - padding.left - padding.right;
        const plotH = h - padding.top - padding.bottom;

        // Grid lines
        ctx.strokeStyle = 'rgba(255,255,255,0.05)';
        ctx.lineWidth = 1;
        for (let i = 0; i <= 4; i++) {
            const y = padding.top + (plotH / 4) * i;
            ctx.beginPath();
            ctx.moveTo(padding.left, y);
            ctx.lineTo(w - padding.right, y);
            ctx.stroke();

            ctx.fillStyle = 'rgba(255,255,255,0.2)';
            ctx.font = '18px Gilroy';
            ctx.textAlign = 'right';
            const label = Math.round(max - (max / 4) * i);
            ctx.fillText(label, padding.left - 8, y + 5);
        }

        // Line
        const gradient = ctx.createLinearGradient(0, padding.top, 0, h - padding.bottom);
        gradient.addColorStop(0, 'rgba(59,130,246,0.4)');
        gradient.addColorStop(1, 'rgba(59,130,246,0)');

        ctx.beginPath();
        values.forEach((v, i) => {
            const x = padding.left + (i / (values.length - 1)) * plotW;
            const y = padding.top + plotH - (v / max) * plotH;
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        });

        // Fill area
        ctx.strokeStyle = '#3b82f6';
        ctx.lineWidth = 3;
        ctx.stroke();

        ctx.lineTo(padding.left + plotW, padding.top + plotH);
        ctx.lineTo(padding.left, padding.top + plotH);
        ctx.closePath();
        ctx.fillStyle = gradient;
        ctx.fill();

        // Dots
        values.forEach((v, i) => {
            const x = padding.left + (i / (values.length - 1)) * plotW;
            const y = padding.top + plotH - (v / max) * plotH;
            ctx.beginPath();
            ctx.arc(x, y, 4, 0, Math.PI * 2);
            ctx.fillStyle = '#3b82f6';
            ctx.fill();
        });

        // Update stats
        if (history.length > 0) {
            const last = history[history.length - 1];
            el.netIncoming.textContent = last.incoming || 0;
            el.netOutgoing.textContent = last.outgoing || 0;
            el.netEps.textContent = (last.incoming || 0) + (last.outgoing || 0);
        }
    }

    // ══════════════════════════════════
    // NUI TAB
    // ══════════════════════════════════

    el.nuiSearch.addEventListener('input', renderNuiList);

    function renderNuiLog(data) {
        state.nuiEntries = data.entries || [];
        el.nuiCount.textContent = state.nuiEntries.length;
        renderNuiList();
    }

    function addNuiEntry(data) {
        state.nuiEntries.push(data.entry);
        if (state.nuiEntries.length > 100) state.nuiEntries.shift();
        el.nuiCount.textContent = state.nuiEntries.length;
        if (state.activeTab === 'nui') renderNuiList();
    }

    function renderNuiList() {
        const search = el.nuiSearch.value.toLowerCase();
        let entries = state.nuiEntries.filter(e => {
            if (search && !(e.resource || '').toLowerCase().includes(search) && !(e.action || '').toLowerCase().includes(search)) return false;
            return true;
        });

        entries = entries.slice().reverse().slice(0, 100);

        el.nuiList.innerHTML = entries.map((e, i) => {
            const payloadStr = e.payload ? JSON.stringify(e.payload, null, 2) : '{}';
            return `<div class="nui-item" onclick="this.classList.toggle('expanded')">
                <div class="nui-top">
                    <span class="nui-resource">${escHtml(e.resource || 'unknown')}</span>
                    <span class="nui-action">${escHtml(e.action || '--')}</span>
                    <span class="nui-time">${e.time || '--'}</span>
                </div>
                <div style="display:flex;gap:8px;font-size:9px;color:var(--text-muted)">
                    <span class="nui-size">Size: ${formatBytes(e.size || 0)}</span>
                </div>
                <div class="nui-payload">${escHtml(payloadStr)}</div>
            </div>`;
        }).join('');
    }

    // ══════════════════════════════════
    // CONSOLE TAB
    // ══════════════════════════════════

    document.querySelectorAll('.scope-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.scope-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.consoleScope = btn.dataset.scope;
        });
    });

    document.querySelectorAll('.mode-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            state.consoleMode = btn.dataset.mode;
            el.consoleInput.placeholder = btn.dataset.mode === 'lua' ? 'Escribir codigo Lua...' : 'Escribir comando...';
        });
    });

    el.btnExecute.addEventListener('click', executeConsole);

    el.consoleInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            executeConsole();
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (state.commandHistory.length > 0) {
                if (state.historyIndex < state.commandHistory.length - 1) {
                    state.historyIndex++;
                }
                el.consoleInput.value = state.commandHistory[state.commandHistory.length - 1 - state.historyIndex];
            }
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (state.historyIndex > 0) {
                state.historyIndex--;
                el.consoleInput.value = state.commandHistory[state.commandHistory.length - 1 - state.historyIndex];
            } else {
                state.historyIndex = -1;
                el.consoleInput.value = '';
            }
        }
    });

    function executeConsole() {
        const val = el.consoleInput.value.trim();
        if (!val) return;

        state.commandHistory.push(val);
        state.historyIndex = -1;

        addConsoleLine(`> ${val}`, 'input');
        el.consoleInput.value = '';

        if (state.consoleMode === 'command') {
            post('executeCommand', { command: val, scope: state.consoleScope });
        } else {
            post('executeLua', { code: val, scope: state.consoleScope });
        }
    }

    function addConsoleOutput(data) {
        const d = data.data;
        if (d) {
            addConsoleLine(d.text, d.type || 'info');
        }
    }

    function addConsoleLine(text, type = 'info') {
        const line = document.createElement('div');
        line.className = `console-line ${type}`;
        line.textContent = text;
        el.consoleOutput.appendChild(line);
        el.consoleOutput.scrollTop = el.consoleOutput.scrollHeight;

        // Limit lines
        while (el.consoleOutput.children.length > 200) {
            el.consoleOutput.removeChild(el.consoleOutput.firstChild);
        }
    }

    // ══════════════════════════════════
    // UTILITIES
    // ══════════════════════════════════

    function escHtml(str) {
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    function formatBytes(bytes) {
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / 1048576).toFixed(1) + ' MB';
    }

    function dataRow(label, value) {
        return `<div class="data-row"><span class="data-label">${escHtml(String(label))}</span><span class="data-value">${escHtml(String(value))}</span></div>`;
    }

    function copyText(text) {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(text).catch(() => {});
        } else {
            const ta = document.createElement('textarea');
            ta.value = text;
            document.body.appendChild(ta);
            ta.select();
            document.execCommand('copy');
            document.body.removeChild(ta);
        }
    }

    function flashCopied(btn) {
        btn.classList.add('copied');
        const orig = btn.innerHTML;
        const svg = btn.querySelector('svg').outerHTML;
        btn.innerHTML = svg + ' Copiado!';
        setTimeout(() => {
            btn.classList.remove('copied');
            btn.innerHTML = orig;
        }, 1500);
    }

    // ══════════════════════════════════
    // PREVIEW MODE (IS_BROWSER)
    // ══════════════════════════════════

    if (state.isBrowser) {
        document.body.style.background = '#1a1a2e';
        state.superAdmin = true;
        el.tabConsole.style.display = '';

        handleToggle({ show: true, theme: 'dark', lightMode: false, superAdmin: true, opacity: 90 });

        // Mock resmon
        const mockResources = [
            { name: 'es_extended', ms: 0.023, state: 'started' },
            { name: 'dei_hud', ms: 0.012, state: 'started' },
            { name: 'dei_devtools', ms: 0.008, state: 'started' },
            { name: 'esx_basicneeds', ms: 0.045, state: 'started' },
            { name: 'esx_society', ms: 0.067, state: 'started' },
            { name: 'esx_jobs', ms: 0.134, state: 'started' },
            { name: 'mysql-async', ms: 0.189, state: 'started' },
            { name: 'esx_vehicleshop', ms: 0.256, state: 'started' },
            { name: 'esx_property', ms: 0.312, state: 'started' },
            { name: 'mythic_notify', ms: 0.021, state: 'started' }
        ];
        renderResmon({ resources: mockResources, avgTick: 4.72 });

        // Mock events
        const mockEvents = [
            { time: '14:23:01', name: 'esx:playerLoaded', source: 1, direction: 's2c', size: 2048 },
            { time: '14:23:02', name: 'esx_basicneeds:onTick', source: 1, direction: 'c2s', size: 128 },
            { time: '14:23:03', name: 'esx:setJob', source: -1, direction: 's2c', size: 256 },
            { time: '14:23:05', name: 'dei_hud:updateMoney', source: 1, direction: 's2c', size: 64 },
            { time: '14:23:06', name: 'esx_society:withdraw', source: 1, direction: 'c2s', size: 96 },
            { time: '14:23:08', name: 'baseevents:onPlayerDied', source: 1, direction: 'c2s', size: 512 },
            { time: '14:23:10', name: 'esx:getSharedObject', source: 1, direction: 'c2s', size: 32 },
            { time: '14:23:12', name: 'dei_hud:updateStatus', source: -1, direction: 's2c', size: 128 }
        ];
        state.eventEntries = mockEvents;
        renderEventList();

        // Mock entities
        renderEntities({
            counts: { peds: 47, vehicles: 23, objects: 156, pickups: 3, total: 229 },
            nearby: [
                { type: 'vehicle', model: 0xB779A091, netId: 142, distance: 5.2, owner: 1, health: 1000, coords: { x: 215.3, y: -810.5, z: 30.7 } },
                { type: 'ped', model: 0xA8683715, netId: 89, distance: 12.8, owner: 2, health: 200, coords: { x: 220.1, y: -815.2, z: 30.7 } },
                { type: 'object', model: 0xFE1A926D, netId: -1, distance: 18.4, owner: -1, health: 0, coords: { x: 225.6, y: -805.8, z: 30.7 } },
                { type: 'vehicle', model: 0x4C80EB0E, netId: 156, distance: 24.1, owner: 1, health: 850, coords: { x: 230.0, y: -820.3, z: 30.7 } },
                { type: 'ped', model: 0x6C1F4B85, netId: 201, distance: 35.6, owner: 3, health: 150, coords: { x: 240.2, y: -800.1, z: 31.2 } }
            ]
        });

        // Mock player
        renderPlayerData({
            data: {
                coords: { x: 215.32, y: -810.54, z: 30.73 },
                heading: 156.42,
                health: 200,
                maxHealth: 200,
                armor: 50,
                speed: 0.0,
                serverId: 1,
                clientId: 0,
                vehicle: {
                    displayName: 'SULTAN',
                    model: '0xB779A091',
                    plate: 'DEI 001',
                    speed: 0.0,
                    rpm: 0.0,
                    gear: 0,
                    engineHealth: 1000,
                    bodyHealth: 1000,
                    fuel: 68.5
                }
            }
        });
        renderPlayerServerData({
            data: {
                serverId: 1,
                job: 'police',
                jobGrade: 'chief',
                identifiers: {
                    steam: 'steam:110000112345678',
                    license: 'license:abcdef1234567890',
                    discord: 'discord:123456789012345',
                    name: 'DeiDev'
                },
                playerCount: 32,
                maxPlayers: 64,
                framework: 'esx'
            }
        });

        // Mock network
        renderNetStats({ data: { ping: 42, eventsPerSecond: 18, endpoint: '192.168.1.100:30120' } });

        const mockNetHistory = [];
        for (let i = 0; i < 30; i++) {
            mockNetHistory.push({
                time: Date.now() - (30 - i) * 1000,
                incoming: Math.floor(Math.random() * 20) + 5,
                outgoing: Math.floor(Math.random() * 10) + 2
            });
        }
        renderNetworkChart({ history: mockNetHistory });

        // Mock NUI
        state.nuiEntries = [
            { time: '14:23:01', resource: 'dei_hud', action: 'updateHealth', size: 48, payload: { health: 200, maxHealth: 200 } },
            { time: '14:23:02', resource: 'dei_hud', action: 'updateMoney', size: 64, payload: { cash: 15000, bank: 250000 } },
            { time: '14:23:03', resource: 'dei_notifys', action: 'showNotify', size: 128, payload: { type: 'success', message: 'Item comprado', duration: 3000 } },
            { time: '14:23:05', resource: 'dei_pausemenu', action: 'setPlayerData', size: 256, payload: { name: 'DeiDev', job: 'police' } }
        ];
        el.nuiCount.textContent = state.nuiEntries.length;
        renderNuiList();

        // Mock console
        addConsoleLine('Dei DevTools v1.0 - Preview Mode', 'info');
        addConsoleLine('Consola lista. Escribe un comando o codigo Lua.', 'success');
    }
})();
