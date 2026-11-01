/* The browser owns persistence. Every write is fenced by a transactionally checked
 * tab identity; a suspended tab cannot overwrite a garden after takeover. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const token = crypto.randomUUID();
  const channel = typeof BroadcastChannel === 'function' ? new BroadcastChannel('purrimeter-garden') : null;
  let db, callback, engine, releaseLock, started = false, active = false, volatile = false, sessionAccepted = false;
  let initial = '', current = '', saving = Promise.resolve(), lastSaved = '', pendingReload = false;
  let settings = {};
  function emit(type, value = '') { if (callback) callback(type, value); }
  function gate(message) { $('gate').hidden = false; $('message').textContent = message; $('progress').hidden = true; }
  function storageError() {
    if (!active) return;
    volatile = true; $('save-warning').hidden = false; $('session').hidden = false;
    emit('save_error');
  }
  async function openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('purrimeter-garden', 1);
      request.onupgradeneeded = () => request.result.createObjectStore('state');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      request.onblocked = () => reject(new Error('Storage is in use by an older page.'));
    });
  }
  function claim() {
    return new Promise((resolve, reject) => {
      const tx = db.transaction('state', 'readwrite'), store = tx.objectStore('state');
      const read = store.get('garden'); read.onsuccess = () => { initial = read.result || ''; current = initial; };
      const prefs = store.get('settings'); prefs.onsuccess = () => { settings = prefs.result || {}; };
      store.put(token, 'owner');
      tx.oncomplete = resolve; tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error);
    });
  }
  function write(snapshot) {
    return new Promise((resolve, reject) => {
      const tx = db.transaction('state', 'readwrite'), store = tx.objectStore('state');
      let owned = false;
      const request = store.get('owner');
      request.onsuccess = () => {
        owned = request.result === token;
        if (owned) { if (snapshot) store.put(snapshot, 'garden'); store.put(settings, 'settings'); }
      };
      tx.oncomplete = () => { if (!owned) { relinquish(); reject(new Error('Another tab owns this garden.')); } else resolve(); };
      tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error);
    });
  }
  function persist(snapshot = current) {
    if (!active) return Promise.resolve(false);
    if (snapshot) current = snapshot;
    if (volatile || !db) return Promise.resolve(false);
    const captured = current;
    saving = saving.then(() => write(captured)).then(() => { lastSaved = captured; emit('saved'); return true; }).catch(() => { storageError(); return false; });
    return saving;
  }
  function relinquish() {
    if (!active) return;
    emit('hidden'); emit('lost'); active = false;
    if (releaseLock) { releaseLock(); releaseLock = null; }
    gate('Your garden is open in another tab. Return here by reloading and choosing Play in this tab.');
    $('retry').hidden = false;
  }
  if (channel) channel.onmessage = async event => {
    if (event.data.type === 'flush' && active) { emit('hidden'); await persist(); channel.postMessage({ type: 'flushed', to: event.data.from }); }
    if (event.data.type === 'claimed' && event.data.owner !== token) relinquish();
  };
  function fit() {
    const rect = $('stage').getBoundingClientRect();
    // One game unit per CSS pixel keeps controls readable on high-DPI phones.
    $('canvas').width = Math.max(1, Math.round(rect.width));
    $('canvas').height = Math.max(1, Math.round(rect.height));
    emit('resize', JSON.stringify([rect.width, rect.height]));
  }
  new ResizeObserver(fit).observe($('stage'));
  if (window.visualViewport) {
    const keyboardFit = () => {
      // iOS overlays its keyboard without resizing the layout viewport.
      // Keep chat and form actions inside the visible viewport.
      document.documentElement.style.setProperty('--visible-height', `${visualViewport.height}px`);
      fit();
    };
    visualViewport.addEventListener('resize', keyboardFit); keyboardFit();
  }
  async function start() {
    if (started) { location.reload(); return; }
    started = true; active = true;
    $('takeover').hidden = true; $('continue').hidden = true;
    gate('Loading your garden…'); $('progress').hidden = false;
    try {
      fit();
      engine = new Engine(window.PURRIMETER_CONFIG);
      await engine.startGame({ canvas: $('canvas'), canvasResizePolicy: 0,
        onProgress: (done, total) => { if (total > 0) { $('progress').max = total; $('progress').value = done; } },
        onExit: () => { active = false; if (releaseLock) releaseLock(); }
      });
      $('gate').hidden = true;
      if (volatile) { $('save-warning').hidden = false; $('session').hidden = true; }
      $('canvas').focus();
    } catch (error) { gate('The garden could not load. Check your connection and try again. ' + error.message); $('retry').hidden = false; }
  }
  async function takeLock(steal = false) {
    if (!navigator.locks) throw new Error('This browser cannot protect shared saves.');
    // A forced takeover still fences IndexedDB writes, even if the old tab is frozen.
    navigator.locks.request('purrimeter-active-game', steal ? { steal: true } : { ifAvailable: true }, async lock => {
      if (!lock) { gate('Your garden is already open in another tab. Taking over pauses that tab.'); $('takeover').hidden = false; return; }
      const held = new Promise(resolve => { releaseLock = resolve; });
      try { await claim(); channel?.postMessage({ type: 'claimed', owner: token }); await start(); await held; }
      catch (_) { gate('This browser cannot keep an autosave. You can still play and export a backup.'); $('continue').hidden = false; releaseLock(); }
    }).catch(() => { if (active) relinquish(); });
  }
  window.PurrimeterBrowser = {
    initial: () => initial,
    touch: () => navigator.maxTouchPoints > 0,
    active: () => active,
    settings: name => settings[name] || '',
    setSettings: (name, value) => { if (active) { settings[name] = value; persist(); } },
    subscribe: cb => { callback = cb; if (document.hidden) emit('hidden'); },
    save: snapshot => { persist(snapshot); },
    commitSave: async snapshot => {
      if (active && volatile && sessionAccepted) { current = snapshot; emit('draft_saved', 'session'); return; }
      emit('draft_saved', await persist(snapshot) ? 'ok' : 'failed');
    },
    sessionOnly: () => volatile && sessionAccepted,
    exportSave: snapshot => {
      const url = URL.createObjectURL(new Blob([snapshot], { type: 'application/json' }));
      const link = document.createElement('a'); link.href = url; link.download = 'purrimeter-save.json'; link.click();
      setTimeout(() => URL.revokeObjectURL(url), 60000);
    },
    importSave: () => { $('import-file').value = ''; $('import-file').click(); },
    reload: async snapshot => {
      if (pendingReload) return;
      pendingReload = true;
      const ok = await persist(snapshot);
      if (ok) location.reload();
      else { pendingReload = false; emit('reload_failed'); }
    },
    saveState: () => volatile ? 'unavailable' : (lastSaved === current && current ? 'saved' : 'saving')
  };
  $('import-file').addEventListener('change', async event => {
    const file = event.target.files[0]; if (!file) return;
    if (file.size > 8 * 1024 * 1024) { emit('import_error', 'That save is too large (maximum 8 MB).'); return; }
    try { emit('import', await file.text()); } catch (_) { emit('import_error', 'The file could not be read.'); }
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden) { emit('hidden'); persist(); } else { emit('visible'); fit(); } });
  window.addEventListener('pagehide', () => { emit('hidden'); persist(); });
  $('backup').onclick = () => emit('export');
  $('session').onclick = () => { sessionAccepted = true; $('session').hidden = true; emit('session'); };
  $('continue').onclick = () => { volatile = true; sessionAccepted = true; start(); };
  $('retry').onclick = () => location.reload();
  $('takeover').onclick = async () => {
    $('takeover').disabled = true;
    if (channel) {
      await new Promise(resolve => {
        const listener = event => { if (event.data.type === 'flushed' && event.data.to === token) { channel.removeEventListener('message', listener); resolve(); } };
        channel.addEventListener('message', listener); channel.postMessage({ type: 'flush', from: token });
        setTimeout(() => { channel.removeEventListener('message', listener); resolve(); }, 1200);
      });
    }
    await takeLock(true);
  };
  (async () => {
    try { db = await openDatabase(); await takeLock(); }
    catch (_) { gate('This browser cannot keep an autosave. You can still play and export a backup.'); $('continue').hidden = false; }
  })();
})();
