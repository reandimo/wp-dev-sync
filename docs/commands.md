# Commands

## wp-sync init

Creates a `.env` file in the current directory from the built-in template.

```bash
wp-sync init
```

If a `.env` file already exists, it warns you and exits without overwriting.

**Use this as the first step** when setting up WP Sync in a new project.

---

## wp-sync setup

Runs a comprehensive preflight check to verify your environment is ready.

```bash
wp-sync setup
```

**What it checks:**

1. **System info** — OS, protocol, host, user, port
2. **Dependencies** — rsync/lftp, ssh, file watchers
3. **Tunnel tools** — cloudflared, ngrok (optional)
4. **Connection test** — Attempts to connect to the remote server

Run this after configuring your `.env` to make sure everything works before syncing.

---

## wp-sync watch

Starts a file watcher that automatically syncs changes to the remote server.

```bash
wp-sync watch
```

**What it does:**

1. Performs an initial full sync (push)
2. Starts watching `LOCAL_PATH` for file changes
3. On every change, runs a sync push
4. Continues until you press `Ctrl+C`

The watcher selection is automatic based on your OS:

| OS | Watcher | Latency |
|----|---------|---------|
| macOS | fswatch | ~0.5s |
| Linux | inotifywait | ~0.5s |
| Windows | Polling (every 2s) | ~2s |

**This is the main command you'll use during development.** Start it, edit files in your editor, and they appear on the server automatically.

---

## wp-sync push

One-time upload of all files from `LOCAL_PATH` to `REMOTE_PATH`.

```bash
wp-sync push
```

**Displays:**
- Local path, protocol, target server, remote path
- Whether `SYNC_DELETE` is active
- File-by-file transfer log
- Success confirmation

**Use cases:**
- Initial deployment
- Manual sync after making many changes offline
- When you don't need continuous watching

---

## wp-sync pull

One-time download of all files from `REMOTE_PATH` to `LOCAL_PATH`.

```bash
wp-sync pull
```

**Use cases:**
- Pulling changes made directly on the server
- Initial download of an existing theme
- Syncing changes from another developer who uploaded via FTP

**Note:** Pull never uses `--delete` — it won't remove your local files that don't exist on the server.

---

## wp-sync tunnel

Opens a public tunnel to your remote site for previewing.

```bash
wp-sync tunnel
```

Requires `TUNNEL_TOOL` and `TUNNEL_DOMAIN` in `.env`.

**Supported tools:**
- `cloudflared` — Cloudflare Tunnel (free, no account required for quick tunnels)
- `ngrok` — ngrok (free tier available)

**Use case:** Share a preview URL with a client without exposing the server's real IP or configuring DNS.

---

## wp-sync help

Shows all available commands and quick start guide.

```bash
wp-sync help
wp-sync --help
wp-sync -h
```

---

## wp-sync version

Shows the current version.

```bash
wp-sync version
wp-sync --version
wp-sync -v
```

---

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Error (missing `.env`, missing dependency, connection failed, etc.) |

All error messages are displayed in a red error box with actionable instructions.
