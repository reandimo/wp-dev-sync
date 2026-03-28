<p align="center">
  <img src="https://img.shields.io/badge/WordPress-Dev%20Sync-21759b?style=for-the-badge&logo=wordpress&logoColor=white" alt="WP Dev Sync" />
  <br />
  <img src="https://img.shields.io/badge/version-1.0.0-blue?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/protocols-SSH%20%7C%20FTP-orange?style=flat-square" alt="Protocols" />
</p>

<p align="center">
  <b>CLI for syncing WordPress themes to remote servers.</b><br/>
  The same workflow Shopify devs get with <code>shopify theme dev</code>, but for WordPress.
</p>

<p align="center">
  <a href="#-install">Install</a> ·
  <a href="#-quick-start">Quick Start</a> ·
  <a href="#-commands">Commands</a> ·
  <a href="#%EF%B8%8F-configuration">Configuration</a> ·
  <a href="docs/home.md">Wiki</a>
</p>

---

## The Problem

```
😩 The Old Way                          ✨ The WP Dev Sync Way
─────────────────────                   ─────────────────────
1. Edit theme file locally              1. Edit theme file locally
2. Open FileZilla                       2. That's it. It's already
3. Navigate to remote dir                  on your server.
4. Upload file manually
5. Refresh browser
6. Repeat 500 times a day
```

**No more FTP clients. No more manual uploads.** Save a file locally and it's on your server in seconds.

---

## 📦 Install

```bash
npm install -g wp-dev-sync
```

<details>
<summary><b>Other install methods</b></summary>

```bash
# Use without installing
npx wp-dev-sync <command>

# Manual install (clone + link)
git clone https://github.com/reandimo/wp-dev-sync.git
cd wp-dev-sync && npm link
```
</details>

> **Requirements:** Bash (Git Bash on Windows) + `rsync` (SSH) or `lftp` (FTP)

---

## 🚀 Quick Start

```bash
cd /path/to/my-wordpress-site     # 1. Go to your project

wp-dev-sync init                      # 2. Creates .env config file

nano .env                         # 3. Set your server credentials

wp-dev-sync setup                     # 4. Verify everything works

wp-dev-sync watch                     # 5. Start syncing! 🎉
```

That's it. Every file you save now appears on your server automatically.

---

## 📋 Commands

```
╭──────────────────────────────────────────────────────╮
│                                                      │
│   ⟳  watch     Watch + auto-sync on file changes    │
│   ↑  push      One-time upload to remote             │
│   ↓  pull      One-time download from remote         │
│   ★  tunnel    Public URL for client previews        │
│   ◆  setup     Preflight check (deps + connection)   │
│   ◇  init      Create .env from template             │
│                                                      │
╰──────────────────────────────────────────────────────╯
```

---

## ⚙️ Configuration

All config lives in a `.env` file in your project root:

```bash
# ── What to sync ─────────────────────────────────────
LOCAL_PATH=./wp-content/themes/my-theme        # Local dir
REMOTE_PATH=/var/www/html/wp-content/themes/my-theme  # Remote dir

# ── Connection ───────────────────────────────────────
SYNC_PROTOCOL=ssh          # ssh or ftp
REMOTE_USER=deploy
REMOTE_HOST=myserver.com
REMOTE_PORT=22             # 22 for SSH, 21 for FTP
REMOTE_PASSWORD=           # FTP only

# ── Behavior ─────────────────────────────────────────
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env
SYNC_DELETE=false          # true = mirror exact state
```

### .syncignore

For more control, create a `.syncignore` file in your project root (or run `wp-dev-sync init`). One pattern per line, like `.gitignore`:

```bash
# .syncignore
node_modules
vendor
.git
.env
*.log
*.map
public/hot
public/.vite
.idea
.vscode
```

Both `.syncignore` and `SYNC_EXCLUDE` work together — patterns from both are merged.

### Example Setups

<details>
<summary><b>🏠 WordPress Classic (cPanel / Shared Hosting)</b></summary>

```bash
LOCAL_PATH=./wp-content/themes/my-theme
REMOTE_PATH=/home/user/public_html/wp-content/themes/my-theme
SYNC_PROTOCOL=ftp
REMOTE_USER=cpanel-user@domain.com
REMOTE_HOST=ftp.domain.com
REMOTE_PORT=21
REMOTE_PASSWORD=your-ftp-password
```
</details>

<details>
<summary><b>🪨 WordPress Bedrock</b></summary>

```bash
LOCAL_PATH=./web/app/themes/my-theme
REMOTE_PATH=/var/www/mysite/current/web/app/themes/my-theme
SYNC_PROTOCOL=ssh
REMOTE_USER=deploy
REMOTE_HOST=myserver.com
REMOTE_PORT=22
```
</details>

<details>
<summary><b>🖥️ VPS (DigitalOcean, Linode, Vultr)</b></summary>

```bash
LOCAL_PATH=./wp-content/themes/my-theme
REMOTE_PATH=/var/www/html/wp-content/themes/my-theme
SYNC_PROTOCOL=ssh
REMOTE_USER=root
REMOTE_HOST=203.0.113.10
REMOTE_PORT=22
SYNC_DELETE=true
```
</details>

<details>
<summary><b>⚡ WP Engine</b></summary>

```bash
LOCAL_PATH=./wp-content/themes/my-theme
REMOTE_PATH=/sites/mysite/wp-content/themes/my-theme
SYNC_PROTOCOL=ssh
REMOTE_USER=mysite
REMOTE_HOST=mysite.ssh.wpengine.net
REMOTE_PORT=22
```
</details>

<details>
<summary><b>🔌 Plugin Development</b></summary>

```bash
LOCAL_PATH=./wp-content/plugins/my-plugin
REMOTE_PATH=/var/www/html/wp-content/plugins/my-plugin
SYNC_PROTOCOL=ssh
REMOTE_USER=deploy
REMOTE_HOST=myserver.com
REMOTE_PORT=22
SYNC_EXCLUDE=.git,node_modules,tests,vendor
```
</details>

---

## 🔄 Protocols

```
┌──────────────────────┬──────────────────────┐
│  SSH (rsync)         │  FTP (lftp)          │
│  ══════════          │  ═════════           │
│  ✔ Delta transfer    │  ✔ Universal access  │
│  ✔ Encrypted         │  ✔ No server setup   │
│  ✔ Passwordless      │  ✔ Works everywhere  │
│  ✔ ~200 bytes/edit   │  ✘ Full file upload  │
│                      │  ✘ Unencrypted       │
│  ★ Recommended       │  ○ Fallback option   │
└──────────────────────┴──────────────────────┘
```

<details>
<summary><b>Install rsync (SSH)</b></summary>

```bash
choco install rsync          # Windows
brew install rsync           # macOS
sudo apt install rsync       # Linux
```

**SSH key setup (one-time):**
```bash
ssh-keygen -t ed25519
ssh-copy-id -p 22 user@myserver.com
```
</details>

<details>
<summary><b>Install lftp (FTP)</b></summary>

```bash
choco install lftp           # Windows
brew install lftp            # macOS
sudo apt install lftp        # Linux
```
</details>

---

## 👀 Watch Mode

`wp-dev-sync watch` monitors your files and syncs on every save:

```
┌───────────┬──────────────┬───────────┐
│ OS        │ Watcher      │ Latency   │
├───────────┼──────────────┼───────────┤
│ macOS     │ fswatch      │ ~0.5s     │
│ Linux     │ inotifywait  │ ~0.5s     │
│ Windows   │ Polling      │ ~2s       │
└───────────┴──────────────┴───────────┘
```

**Pro tip:** Pair with Vite HMR for the ultimate WordPress dev experience:

```bash
# Terminal 1                    # Terminal 2
npm run dev                     wp-dev-sync watch
# Vite handles CSS/JS HMR      # WP Dev Sync handles PHP uploads
```

---

## 🚇 Tunnels

Share your staging site with clients via a public URL:

```bash
# .env
TUNNEL_TOOL=cloudflared      # or: ngrok
TUNNEL_DOMAIN=staging.mysite.com
```

```bash
wp-dev-sync tunnel
# → https://random-words.trycloudflare.com
```

---

## 🔥 SYNC_DELETE

| Value | What happens | Safety |
|:------|:-------------|:------:|
| `false` | Only uploads new/changed files. Never deletes remotely. | ✅ Safe |
| `true` | Mirrors local state exactly. Remote-only files get deleted. | ⚠️ Careful |

---

## 🔧 Troubleshooting

<details>
<summary><b>rsync: command not found (Windows)</b></summary>

The CLI auto-adds Chocolatey/Scoop paths. If it still fails:
```bash
export PATH="/c/ProgramData/chocolatey/bin:$PATH"
```
</details>

<details>
<summary><b>SSH: Connection refused</b></summary>

- Check SSH is enabled on your server
- Try alternative ports: `2222`, `7822`, `18765`
- SSH hostname may differ from FTP (`ssh.host.com` vs `ftp.host.com`)
</details>

<details>
<summary><b>FTP: Login incorrect</b></summary>

- Some hosts require full email as username (`user@domain.com`)
- Check IP whitelisting in your hosting panel
- Test with FileZilla first to isolate the issue
</details>

<details>
<summary><b>Sync is slow</b></summary>

- Switch from FTP to SSH if possible (10x faster)
- Exclude large dirs: `SYNC_EXCLUDE=.git,node_modules,vendor,public/fonts`
- Windows polling (2s) is normal behavior
</details>

---

## 🏗️ Architecture

```
wp-dev-sync/
├── bin/wp-dev-sync              # CLI entry point
├── lib/
│   ├── _env.sh              # .env loader + Windows PATH fix
│   ├── _ui.sh               # Terminal UI (colors, banners, spinners)
│   └── _sync.sh             # Core sync engine (rsync + lftp)
├── commands/
│   ├── watch.sh             # File watcher + auto-sync
│   ├── push.sh              # One-time upload
│   ├── pull.sh              # One-time download
│   ├── tunnel.sh            # Cloudflare / ngrok tunnel
│   └── setup.sh             # Preflight dependency check
└── docs/                    # Full wiki documentation
```

---

## 💡 Not just WordPress

While wp-dev-sync is built for WordPress theme development, it works with **any directory** you need to sync remotely. Just set `LOCAL_PATH` and `REMOTE_PATH` to whatever you need.

```bash
# Sync a React app
LOCAL_PATH=./build
REMOTE_PATH=/var/www/html/myapp

# Sync a Jekyll site
LOCAL_PATH=./_site
REMOTE_PATH=/var/www/html/blog
```

---

<p align="center">
  <a href="docs/home.md"><b>📖 Full Documentation</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/reandimo/wp-dev-sync/issues"><b>🐛 Report Bug</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/reandimo/wp-dev-sync/issues"><b>💡 Request Feature</b></a>
</p>

<p align="center">
  <sub>Built by <a href="https://reandimo.dev">Renan Diaz</a></sub>
</p>
