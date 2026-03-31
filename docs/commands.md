# Commands

## npx wp-dev-sync init

Creates a `.env` file in the current directory from the built-in template.

```bash
npx wp-dev-sync init
```

If a `.env` file already exists, it warns you and exits without overwriting.

**Use this as the first step** when setting up WP Dev Sync in a new project.

---

## npx wp-dev-sync setup

Runs a comprehensive preflight check to verify your environment is ready.

```bash
npx wp-dev-sync setup
```

**What it checks:**

1. **System info** — OS, protocol, host, user, port
2. **Dependencies** — rsync/lftp, ssh, file watchers
3. **Tunnel tools** — cloudflared, ngrok (optional)
4. **Connection test** — Attempts to connect to the remote server

Run this after configuring your `.env` to make sure everything works before syncing.

---

## npx wp-dev-sync watch

Starts a file watcher that automatically syncs changes to the remote server.

```bash
npx wp-dev-sync watch
```

**What it does:**

1. Compares local and remote files (dry-run diff)
2. Shows smart reconciliation prompts for each category:
   - **Local-only files** — upload to remote or delete locally
   - **Remote-only files** — download to local or delete from remote
   - **Differing files** — keep local version or keep remote version
3. Syncs chosen files with a gradient progress bar
4. Starts watching `LOCAL_PATH` for file changes
5. On every change, runs a sync push
6. Continues until you press `Ctrl+C`

If all files are already in sync, the reconciliation step is skipped.

The watcher selection is automatic based on your OS:

| OS | Watcher | Latency |
|----|---------|---------|
| macOS | fswatch | ~0.5s |
| Linux | inotifywait | ~0.5s |
| Windows | Polling (every 2s) | ~2s |

**This is the main command you'll use during development.** Start it, edit files in your editor, and they appear on the server automatically.

---

## npx wp-dev-sync push

One-time upload of all files from `LOCAL_PATH` to `REMOTE_PATH`.

```bash
npx wp-dev-sync push
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

## npx wp-dev-sync pull

One-time download of all files from `REMOTE_PATH` to `LOCAL_PATH`.

```bash
npx wp-dev-sync pull
```

**Use cases:**
- Pulling changes made directly on the server
- Initial download of an existing theme
- Syncing changes from another developer who uploaded via FTP

**Note:** Pull never uses `--delete` — it won't remove your local files that don't exist on the server.

---

## npx wp-dev-sync diff

Compares local and remote files without syncing anything. Like `git status` for your server.

```bash
npx wp-dev-sync diff
```

**What it shows:**

Files are classified into three categories with color-coded output:

- **`+` Local only** (green) — files present locally but missing on the remote
- **`-` Remote only** (red) — files present on the remote but missing locally
- **`~` Modified** (yellow) — files that exist on both sides but differ

**Output includes:**
- File lists per category with counts
- Summary line with totals
- Suggested next action (`push` or `watch`)

**Use cases:**
- Quick check before pushing to see what would change
- Verifying a deployment was complete
- Spotting files that were modified directly on the server
- Auditing differences after someone else uploaded via FTP

---

## npx wp-dev-sync env

Manages multiple server environments (staging, production, etc.) so you can switch between them instantly.

```bash
npx wp-dev-sync env <subcommand>
```

**Subcommands:**

| Subcommand | Aliases | Description |
|------------|---------|-------------|
| `list` | `ls` | Show all environments with active indicator |
| `switch [name]` | `sw`, `use` | Switch to an environment (interactive if no name) |
| `create <name>` | `new`, `add` | Create environment from current `.env` |
| `delete <name>` | `rm`, `remove` | Delete an environment |
| `current` | | Print the active environment name |
| `help` | | Show usage guide |

**How it works:**

Environments are stored as `.env.<name>` files (e.g., `.env.staging`, `.env.production`). Switching copies the selected file to `.env`, so all other commands work unchanged.

```bash
# Create environments
npx wp-dev-sync env create staging
npx wp-dev-sync env create production

# Edit each file with server credentials
nano .env.staging
nano .env.production

# Switch between them
npx wp-dev-sync env switch staging        # by name
npx wp-dev-sync env switch                # interactive arrow-key picker

# Check which is active
npx wp-dev-sync env current
```

**Use cases:**
- Separate staging and production configs
- Client projects with multiple hosting environments
- Testing against different servers without manual `.env` edits
- Team members sharing environment configs via git (excluding passwords)

---

## npx wp-dev-sync tunnel

Opens a public tunnel to your remote site for previewing.

```bash
npx wp-dev-sync tunnel
```

Requires `TUNNEL_TOOL` and `TUNNEL_DOMAIN` in `.env`.

**Supported tools:**
- `cloudflared` — Cloudflare Tunnel (free, no account required for quick tunnels)
- `ngrok` — ngrok (free tier available)

**Use case:** Share a preview URL with a client without exposing the server's real IP or configuring DNS.

---

## npx wp-dev-sync help

Shows all available commands and quick start guide.

```bash
npx wp-dev-sync help
npx wp-dev-sync --help
npx wp-dev-sync -h
```

---

## npx wp-dev-sync version

Shows the current version.

```bash
npx wp-dev-sync version
npx wp-dev-sync --version
npx wp-dev-sync -v
```

---

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Error (missing `.env`, missing dependency, connection failed, etc.) |

All error messages are displayed in a red error box with actionable instructions.
