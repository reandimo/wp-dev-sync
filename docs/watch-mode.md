# Watch Mode

`wp-dev-sync watch` is the core command for development. It monitors your local files and syncs changes to the remote server automatically.

## How it works

```
┌──────────────────────────────────────────────────┐
│  wp-dev-sync watch                                   │
│                                                  │
│  1. Initial sync (full push)                     │
│  2. Start file watcher on LOCAL_PATH             │
│  3. On file change → sync_push()                 │
│  4. Repeat until Ctrl+C                          │
└──────────────────────────────────────────────────┘
```

## File watchers

WP Dev Sync selects the best available watcher for your OS:

### macOS — fswatch

Uses the native FSEvents API for near-instant change detection.

```bash
# Install
brew install fswatch
```

- Latency: ~0.5 seconds
- Excludes: `.git`, `node_modules`, `.DS_Store`
- Uses `-o` flag (batch output) to avoid duplicate syncs

### Linux — inotifywait

Uses the kernel's inotify subsystem.

```bash
# Install
sudo apt install inotify-tools
```

- Latency: ~0.5 seconds
- Monitors: modify, create, delete, move events
- Excludes: `.git`, `node_modules`
- Includes a 0.5s debounce to batch rapid changes

### Windows — Polling

Git Bash doesn't have native file watching, so WP Dev Sync falls back to polling.

- Interval: every 2 seconds
- No additional dependencies required
- Calls `sync_push()` on every poll cycle
- rsync/lftp handle the diff detection (unchanged files aren't re-uploaded)

**Note:** While polling is slower than native watchers, the actual sync is still fast because rsync only transfers changes.

## Watcher fallback

If a native watcher isn't installed, WP Dev Sync automatically falls back to polling mode. You'll see this in the output:

```
  Watcher:       polling
```

The `wp-dev-sync setup` command warns you if a native watcher is available but not installed.

## What gets watched

Only the directory specified in `LOCAL_PATH` is watched. Files matching `SYNC_EXCLUDE` patterns are excluded from the actual sync (but the watcher itself may still detect changes to them — they're simply not uploaded).

## Practical tips

### Pair with Vite HMR

If you're using Vite for CSS/JS bundling, run both simultaneously:

```bash
# Terminal 1: Vite dev server
npm run dev

# Terminal 2: WP Dev Sync watch
wp-dev-sync watch
```

Vite handles hot module replacement for styles, while WP Dev Sync pushes PHP template changes to the server.

### Exclude build output

If your build tool outputs to a directory like `public/` or `dist/`, exclude it to avoid syncing intermediate build artifacts:

```bash
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,public/hot,public/.vite
```

### Large initial syncs

The first time you run `wp-dev-sync watch`, the initial sync transfers all files. If your theme is large, this may take a moment. Subsequent syncs are incremental and much faster.

### Ctrl+C handling

Pressing `Ctrl+C` gracefully stops the watcher. No cleanup is needed — there's no state to corrupt.
