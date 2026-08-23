#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');

// ---- Configuration (override via env vars if needed) ----------------------
const INBOX_DIR = process.env.METUBE_INBOX
    || path.join(os.homedir(), 'Music', 'inbox-metube');
const STATE_DIR = process.env.METUBE_STATE_DIR
    || path.join(INBOX_DIR, '.metube'); // matches MeTube's default STATE_DIR
const BEET_BIN = process.env.BEET_BIN
    || path.join(os.homedir(), '.local', 'bin', 'beet');
const IMPORTED_STORE = process.env.IMPORT_STATE_FILE
    || path.join(os.homedir(), '.local', 'state', 'metube-beet-import', 'imported-keys.json');
const NOTIFIED_ERRORS_STORE = process.env.NOTIFIED_ERRORS_FILE
    || path.join(os.homedir(), '.local', 'state', 'metube-beet-import', 'notified-errors.json');
const LOCK_DIR = path.join(os.tmpdir(), 'metube-beet-import.lock');

function log(...args) {
    const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
    console.log(`[${ts}]`, ...args);
}

// ---- Simple cross-run lock (atomic mkdir - no extra deps needed) ----------
function acquireLock() {
    try {
        fs.mkdirSync(LOCK_DIR);
        return true;
    } catch (err) {
        if (err.code === 'EEXIST') return false;
        throw err;
    }
}
function releaseLock() {
    try { fs.rmdirSync(LOCK_DIR); } catch (_) { /* already gone, fine */ }
}

// ---- MeTube state file helpers ---------------------------------------------
function readStateItems(filename) {
    const p = path.join(STATE_DIR, filename);
    if (!fs.existsSync(p)) return [];
    let raw;
    try {
        raw = JSON.parse(fs.readFileSync(p, 'utf8'));
    } catch (err) {
        log(`⚠ Failed to parse ${filename}, treating as empty: ${err.message}`);
        return [];
    }
    // MeTube wraps state as { items: [...] } (possibly with other top-level
    // keys like schema_version) - tolerate a bare array too, just in case.
    const items = Array.isArray(raw) ? raw : raw.items;
    return Array.isArray(items) ? items : [];
}

function loadImportedKeys() {
    try {
        const raw = JSON.parse(fs.readFileSync(IMPORTED_STORE, 'utf8'));
        return new Set(Array.isArray(raw) ? raw : []);
    } catch (_) {
        return new Set();
    }
}
function saveImportedKeys(set) {
    fs.mkdirSync(path.dirname(IMPORTED_STORE), { recursive: true });
    fs.writeFileSync(IMPORTED_STORE, JSON.stringify([...set], null, 2));
}

function loadNotifiedErrorKeys() {
    try {
        const raw = JSON.parse(fs.readFileSync(NOTIFIED_ERRORS_STORE, 'utf8'));
        return new Set(Array.isArray(raw) ? raw : []);
    } catch (_) {
        return new Set();
    }
}
function saveNotifiedErrorKeys(set) {
    fs.mkdirSync(path.dirname(NOTIFIED_ERRORS_STORE), { recursive: true });
    fs.writeFileSync(NOTIFIED_ERRORS_STORE, JSON.stringify([...set], null, 2));
}

// Surface failed downloads once so they don't go unnoticed, without
// re-logging the same failure on every 3-minute cron tick. Runs regardless
// of the in-flight gate below, so you find out about failures as soon as
// MeTube reports them - not only once the rest of the batch also finishes.
function notifyNewFailures(completed) {
    const notified = loadNotifiedErrorKeys();
    let changed = false;
    for (const item of completed) {
        const info = item && item.info;
        if (info && info.status === 'error' && !notified.has(item.key)) {
            log(`✗ MeTube download failed (retry via UI): "${info.title || item.key}" - ${info.msg || info.error || 'no error message'}`);
            notified.add(item.key);
            changed = true;
        }
    }
    if (changed) saveNotifiedErrorKeys(notified);
}

// ---- beet invocation --------------------------------------------------------
function runBeetImport(args, label) {
    log(`Importing ${label} ...`);
    const spawnEnv = {
        ...process.env,
        // cron's PATH is minimal (often just /usr/bin:/bin). beet itself is
        // invoked via an absolute path below, but beets plugins may shell out
        // to other tools (ffmpeg, fpcalc, etc.) that also need to be findable.
        PATH: `${path.dirname(BEET_BIN)}:/usr/local/bin:/usr/bin:/bin:${process.env.PATH || ''}`,
    };
    const result = spawnSync(BEET_BIN, args, { env: spawnEnv, stdio: 'inherit' });
    if (result.error) {
        log(`✗ Failed to spawn beet (check BEET_BIN="${BEET_BIN}"): ${result.error.message}`);
        return false;
    }
    if (result.status !== 0) {
        log(`✗ beet exited with code ${result.status}`);
        return false;
    }
    log(`✓ Imported ${label}`);
    return true;
}

// ---- main -------------------------------------------------------------------
function main() {
    if (!acquireLock()) {
        log('Another import run is still in progress - skipping this invocation.');
        return;
    }

    try {
        const queue = readStateItems('queue.json');
        const pending = readStateItems('pending.json');
        const completed = readStateItems('completed.json');

        notifyNewFailures(completed);

        if (queue.length > 0 || pending.length > 0) {
            log(`⏳ ${queue.length} queued / ${pending.length} pending download(s) still in flight - skipping this run.`);
            return;
        }

        const importedKeys = loadImportedKeys();

        const candidates = completed.filter((item) => {
            const info = item && item.info;
            return info
                && info.status === 'finished'
                && info.filename
                && !importedKeys.has(item.key);
        });

        if (candidates.length === 0) {
            log('Nothing new to import.');
            return;
        }

        // Group by folder: a filename with a directory component is a
        // playlist/album track; a bare filename is a standalone singleton.
        const albums = new Map(); // relative folder path -> [items]
        const singles = [];

        for (const item of candidates) {
            const rel = item.info.filename;
            const dir = path.dirname(rel);
            if (dir === '.' || dir === '') {
                singles.push(item);
            } else {
                if (!albums.has(dir)) albums.set(dir, []);
                albums.get(dir).push(item);
            }
        }

        // --- Albums / playlist folders ---
        for (const [dir, items] of albums) {
            const absDir = path.join(INBOX_DIR, dir);
            if (!fs.existsSync(absDir)) {
                log(`⚠ Folder missing on disk (already cleaned up?), marking handled: ${dir}`);
                items.forEach((i) => importedKeys.add(i.key));
                continue;
            }
            const ok = runBeetImport(
                ['import', absDir, '--quiet', '--quiet-fallback=asis', '--from-scratch'],
                `album: ${dir}`,
            );
            if (ok) {
                items.forEach((i) => importedKeys.add(i.key));
            }
            // On failure, keys are left untouched so this album is retried next run.
        }

        // --- Standalone singles ---
        for (const item of singles) {
            const absFile = path.join(INBOX_DIR, item.info.filename);
            if (!fs.existsSync(absFile)) {
                log(`⚠ File missing on disk (already cleaned up?), marking handled: ${item.info.filename}`);
                importedKeys.add(item.key);
                continue;
            }
            const ok = runBeetImport(
                ['import', '--singleton', '-q', absFile],
                `singleton: ${item.info.filename}`,
            );
            if (ok) importedKeys.add(item.key);
        }

        saveImportedKeys(importedKeys);
    } finally {
        releaseLock();
    }
}

main();