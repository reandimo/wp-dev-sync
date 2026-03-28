# Configuration

All configuration lives in a `.env` file in your project root. Run `wp-dev-sync init` to create one from the template.

## Full reference

```bash
# =============================================================================
# WP Dev Sync — Configuration
# =============================================================================

# ── Paths ────────────────────────────────────────────────────
# Local directory to sync (relative to .env location, or absolute)
LOCAL_PATH=./wp-content/themes/my-theme

# Remote directory on the server (absolute path)
REMOTE_PATH=/var/www/html/wp-content/themes/my-theme

# ── Connection ───────────────────────────────────────────────
# Protocol: ssh or ftp
SYNC_PROTOCOL=ssh

# Server credentials
REMOTE_USER=username
REMOTE_HOST=myserver.com
REMOTE_PORT=22              # 22 for SSH, 21 for FTP

# FTP only (ignored when SYNC_PROTOCOL=ssh)
REMOTE_PASSWORD=mypassword

# ── Behavior ─────────────────────────────────────────────────
# Comma-separated list of patterns to exclude from sync
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,public/hot

# Delete remote files not present locally (mirror mode)
SYNC_DELETE=false

# ── Tunnel (optional) ───────────────────────────────────────
# TUNNEL_TOOL=cloudflared
# TUNNEL_DOMAIN=mysite.com
```

## Variable details

### LOCAL_PATH

The local directory to sync. Can be relative (to the `.env` location) or absolute.

```bash
# Relative
LOCAL_PATH=./wp-content/themes/my-theme

# Absolute
LOCAL_PATH=/c/projects/mysite/wp-content/themes/my-theme
```

WP Dev Sync resolves relative paths to absolute at runtime. If the path doesn't exist, the CLI exits with an error.

### REMOTE_PATH

The absolute path on the remote server where files should be synced to.

```bash
# cPanel / shared hosting
REMOTE_PATH=/home/username/public_html/wp-content/themes/my-theme

# VPS / dedicated
REMOTE_PATH=/var/www/html/wp-content/themes/my-theme

# Bedrock
REMOTE_PATH=/var/www/mysite/current/web/app/themes/my-theme
```

### SYNC_PROTOCOL

Either `ssh` or `ftp`. Determines which tool is used for syncing.

| Protocol | Tool | Default Port | Auth |
|----------|------|-------------|------|
| `ssh` | rsync over SSH | 22 | SSH key (recommended) or password |
| `ftp` | lftp | 21 | Username + password |

### REMOTE_PORT

Port for the connection. Defaults to `22` for SSH or `21` for FTP if not set.

Some hosting providers use non-standard ports:

| Host | SSH Port | FTP Port |
|------|----------|----------|
| Most VPS/dedicated | 22 | 21 |
| SiteGround | 18765 | 21 |
| GoDaddy | 22 | 21 |
| Bluehost | 2222 | 21 |

### SYNC_EXCLUDE

Comma-separated list of files/directories to exclude from sync. Supports glob patterns.

```bash
# Default
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,public/hot

# Extended (exclude build artifacts and fonts)
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,public/hot,public/fonts,vendor
```

### SYNC_DELETE

Controls whether files deleted locally should also be deleted on the remote server.

| Value | Behavior | Risk |
|-------|----------|------|
| `false` (default) | Only uploads new/changed files. Never deletes anything remotely. | Safe |
| `true` | Mirrors local state exactly. Remote files not present locally are deleted. | Use with caution |

**When to use `true`:**
- You're the only developer working on the theme
- You want an exact mirror of your local state
- You're syncing to a staging server, not production

**When to keep `false`:**
- Multiple developers may upload files directly to the server
- The remote has user-uploaded content in the theme directory
- You're syncing to a production server

### TUNNEL_TOOL

Which tunnel tool to use. Either `cloudflared` (default) or `ngrok`.

### TUNNEL_DOMAIN

The domain of your remote site. Used as the origin URL for the tunnel.

```bash
TUNNEL_DOMAIN=staging.mysite.com
```

## Special characters in passwords

The `.env` parser handles special characters safely. You can use parentheses, ampersands, dollar signs, and other special characters in `REMOTE_PASSWORD` without escaping:

```bash
REMOTE_PASSWORD=my$ecure(p@ss)w0rd&more
```

If your password contains a `#` character, wrap it in quotes:

```bash
REMOTE_PASSWORD="pass#word"
```

## Multiple environments

You can maintain different `.env` files for different servers:

```bash
# Rename and switch as needed
cp .env .env.staging
cp .env .env.production

# Use one
cp .env.staging .env
wp-dev-sync push
```
