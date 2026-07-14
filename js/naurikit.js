/**
 * naurikit.js — JavaScript bridge injected into every NauriKit WebView
 *
 * This script is injected BEFORE the page loads, so it's always available.
 * It provides:
 *   - window.__naurikit.invoke(cmd, payload) → Promise
 *   - window.naurikit (user-facing alias)
 *
 * IPC Protocol:
 *   JS → Native: postWebMessage({ id, cmd, payload })
 *   Native → JS: __naurikit.__resolve(id, result) / __reject(id, err)
 */

(function () {
  'use strict';

  // ── Pending promise registry ──────────────────────────────────────────────
  const _pending = new Map();
  let _idCounter = 0;

  function generateId() {
    return `nk_${Date.now()}_${_idCounter++}`;
  }

  // ── Core bridge ───────────────────────────────────────────────────────────
  const __naurikit = {
    /**
     * Send a command to the Zig backend.
     * @param {string} cmd  - Command name registered with webview.onCommand()
     * @param {any}    payload - JSON-serializable payload
     * @returns {Promise<any>}
     */
    invoke(cmd, payload = null) {
      return new Promise((resolve, reject) => {
        const id = generateId();
        _pending.set(id, { resolve, reject });

        const message = JSON.stringify({ id, cmd, payload });

        // WebView2 (Windows) uses postMessage
        if (window.chrome && window.chrome.webview) {
          window.chrome.webview.postMessage(message);
        }
        // WebKitGTK (Linux) uses webkit message handlers
        else if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.naurikit) {
          window.webkit.messageHandlers.naurikit.postMessage(message);
        }
        else {
          reject(new Error('NauriKit: no WebView bridge available'));
          _pending.delete(id);
        }
      });
    },

    /**
     * Called by the Zig backend to resolve a pending promise.
     * @internal
     */
    __resolve(id, result) {
      const p = _pending.get(id);
      if (p) {
        _pending.delete(id);
        p.resolve(result);
      }
    },

    /**
     * Called by the Zig backend to reject a pending promise.
     * @internal
     */
    __reject(id, error) {
      const p = _pending.get(id);
      if (p) {
        _pending.delete(id);
        p.reject(new Error(error));
      }
    },

    // ── Event system ─────────────────────────────────────────────────────────
    _listeners: new Map(),

    /**
     * Listen for events emitted by the Zig backend.
     * @param {string}   event
     * @param {Function} handler
     * @returns {Function} unsubscribe function
     */
    on(event, handler) {
      if (!this._listeners.has(event)) {
        this._listeners.set(event, new Set());
      }
      this._listeners.get(event).add(handler);
      return () => this.off(event, handler);
    },

    off(event, handler) {
      this._listeners.get(event)?.delete(handler);
    },

    /**
     * @internal — called from Zig to emit events to JS
     */
    __emit(event, data) {
      const handlers = this._listeners.get(event);
      if (handlers) {
        for (const h of handlers) {
          try { h(data); } catch (e) { console.error('[NauriKit] event handler error:', e); }
        }
      }
    },

    // ── Convenience helpers ───────────────────────────────────────────────────

    /** Read a file and return its contents as a string */
    readFile: (path) => __naurikit.invoke('fs_read', { path }),

    /** Write a string to a file */
    writeFile: (path, contents) => __naurikit.invoke('fs_write', { path, contents }),

    /** Open a file picker dialog */
    openFile: (opts = {}) => __naurikit.invoke('dialog_open_file', opts),

    /** Open a folder picker */
    openFolder: (opts = {}) => __naurikit.invoke('dialog_open_folder', opts),

    /** Save file dialog */
    saveFile: (opts = {}) => __naurikit.invoke('dialog_save_file', opts),

    /** Show a message box */
    message: (title, text, kind = 'info') =>
      __naurikit.invoke('dialog_message', { title, text, kind }),

    /** Get app version */
    version: () => __naurikit.invoke('app_version', null),

    /** Quit the application */
    quit: (code = 0) => __naurikit.invoke('app_quit', { code }),

    /** Minimize the window */
    minimize: () => __naurikit.invoke('window_minimize', null),

    /** Maximize the window */
    maximize: () => __naurikit.invoke('window_maximize', null),

    /** Restore the window */
    restore: () => __naurikit.invoke('window_restore', null),

    /** Set the window title */
    setTitle: (title) => __naurikit.invoke('window_set_title', { title }),

    /** Toggle DevTools */
    openDevTools: () => __naurikit.invoke('window_devtools', null),
  };

  // ── Expose on window ──────────────────────────────────────────────────────
  Object.defineProperty(window, '__naurikit', {
    value: __naurikit,
    writable: false,
    configurable: false,
  });

  // User-facing alias (cleaner API)
  Object.defineProperty(window, 'naurikit', {
    value: __naurikit,
    writable: false,
    configurable: false,
  });

  // Freeze to prevent tampering
  Object.freeze(__naurikit);

  console.log('[NauriKit] Bridge initialized ✓');
})();
