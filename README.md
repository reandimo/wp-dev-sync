# WP Sync

CLI for syncing WordPress themes to remote servers — the same workflow Shopify developers get with `shopify theme dev`, but for WordPress.

No more FTP clients, no more manual uploads. Save a file locally and it's on your server in seconds.

## Install

```bash
# Global install
npm install -g wp-sync

# Or use npx
npx wp-sync <command>
```

**Requirements:** bash (Git Bash on Windows), and either `rsync` (SSH) or `lftp` (FTP).

## Quick Start

```bash
# 1. Go to your WordPress project
cd /path/to/my-wordpress-site

# 2. Create .env config
wp-sync init

# 3. Edit .env with your server credentials
#    Set LOCAL_PATH, REMOTE_PATH, REMOTE_USER, REMOTE_HOST, etc.

# 4. Verify dependencies and connection
wp-sync setup

# 5. Start watching and syncing!
wp-sync watch
```

## Commands

| Command | Description |
|---------|-------------|
| `wp-sync watch` | Watch for changes + auto-sync (Ctrl+C to stop) |
| `wp-sync push` | One-time push to remote |
| `wp-sync pull` | One-time pull from remote |
| `wp-sync tunnel` | Open public tunnel to remote site |
| `wp-sync setup` | Check dependencies and test connection |
| `wp-sync init` | Create `.env` file from template |
| `wp-sync help` | Show help |

## Configuration

All config lives in a `.env` file in your project root:

```bash
# Local directory to sync (relative or absolute)
LOCAL_PATH=./wp-content/themes/my-theme

# Remote directory on the server
REMOTE_PATH=/var/www/html/wp-content/themes/my-theme

# Protocol: ssh or ftp
SYNC_PROTOCOL=ssh

# Server connection
REMOTE_USER=username
REMOTE_HOST=myserver.com
REMOTE_PORT=22              # 22 for SSH, 21 for FTP

# FTP only
REMOTE_PASSWORD=mypassword

# Sync behavior
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,public/hot
SYNC_DELETE=false           # true = mirror local state exactly
```

### Example Setups

**WordPress classic (cPanel/shared hosting):**
```bash
LOCAL_PATH=./wp-content/themes/my-theme
REMOTE_PATH=/home/user/public_html/wp-content/themes/my-theme
SYNC_PROTOCOL=ftp
REMOTE_PORT=21
```

**WordPress Bedrock:**
```bash
LOCAL_PATH=./app/web/app/themes/my-theme
REMOTE_PATH=/var/www/mysite/current/web/app/themes/my-theme
SYNC_PROTOCOL=ssh
REMOTE_PORT=22
```

**Full wp-content sync:**
```bash
LOCAL_PATH=./wp-content
REMOTE_PATH=/var/www/html/wp-content
SYNC_PROTOCOL=ssh
```

## Protocols

### SSH (rsync) — Recommended

Fast delta sync over SSH. Only changed bytes are transferred.

```bash
# Install rsync
choco install rsync          # Windows
brew install rsync           # macOS (usually pre-installed)
sudo apt install rsync       # Linux
```

**SSH key setup:**
```bash
ssh-keygen -t ed25519
ssh-copy-id -p 22 user@myserver.com
```

### FTP (lftp)

Mirror sync over FTP. Works with any hosting that provides FTP access.

```bash
# Install lftp
choco install lftp           # Windows
brew install lftp            # macOS
sudo apt install lftp        # Linux
```

## Watch Mode

`wp-sync watch` starts a file watcher that syncs on every change:

| OS | Watcher | Latency |
|----|---------|---------|
| macOS | fswatch | ~0.5s |
| Linux | inotifywait | ~0.5s |
| Windows | Polling | ~2s |

## SYNC_DELETE

| Value | Behavior |
|-------|----------|
| `false` (default) | Only uploads new/changed files. Never deletes remote files. |
| `true` | Mirrors local state exactly. Deletes remote files not present locally. |

## Tunnels

Expose the remote server through a public URL for client previews:

```bash
# In .env
TUNNEL_TOOL=cloudflared      # or: ngrok
TUNNEL_DOMAIN=mysite.com
```

```bash
# Install
choco install cloudflared    # or: choco install ngrok
```

## Troubleshooting

### rsync: command not found (Windows)
The CLI automatically adds common Chocolatey/Scoop paths. If it still fails:
```bash
export PATH="/c/ProgramData/chocolatey/bin:$PATH"
```

### SSH: Connection refused
- Verify SSH is enabled on your server
- Check the port — some hosts use 2222, 7822, etc.
- The SSH hostname may differ from FTP (`ssh.host.com` vs `ftp.host.com`)

### FTP: Login incorrect
- Verify credentials in `.env`
- Some hosts require the full email as username
- Check if your IP needs to be whitelisted

### Sync is slow
- SSH (rsync) is significantly faster than FTP — switch if possible
- Exclude large directories: `SYNC_EXCLUDE=.git,node_modules,public/fonts`
- On Windows, polling checks every 2s — this is normal

## Not just WordPress

While wp-sync is designed for WordPress theme development, it works with any directory you need to sync to a remote server. Just set `LOCAL_PATH` and `REMOTE_PATH` to whatever you need.

---

*By [Renan Diaz](https://reandimo.dev)*
