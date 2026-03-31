# Installation

## npm (recommended)

Install globally:

```bash
npm install -g wp-dev-sync
```

Then use it with npx from any project directory:

```bash
npx wp-dev-sync <command>
```

## Manual install

Clone the repo and link it:

```bash
git clone https://github.com/reandimo/wp-dev-sync.git
cd wp-dev-sync
npm link
```

This creates a global symlink so you can run `wp-dev-sync` from any directory.

## Prerequisites

### Required

- **Bash** — Git Bash on Windows, Terminal on macOS/Linux
- **rsync** (for SSH protocol) or **lftp** (for FTP protocol)

### Installing rsync

| OS | Command |
|----|---------|
| Windows | `choco install rsync` |
| macOS | Pre-installed (or `brew install rsync` for latest) |
| Linux | `sudo apt install rsync` |

### Installing lftp

| OS | Command |
|----|---------|
| Windows | `choco install lftp` |
| macOS | `brew install lftp` |
| Linux | `sudo apt install lftp` |

### Optional

- **fswatch** (macOS) — Native file watcher, faster than polling
- **inotify-tools** (Linux) — Native file watcher, faster than polling
- **cloudflared** or **ngrok** — For public tunnels

| Tool | Windows | macOS | Linux |
|------|---------|-------|-------|
| fswatch | N/A | `brew install fswatch` | `sudo apt install fswatch` |
| inotify-tools | N/A | N/A | `sudo apt install inotify-tools` |
| cloudflared | `choco install cloudflared` | `brew install cloudflared` | [Download](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/) |
| ngrok | `choco install ngrok` | `brew install ngrok` | [Download](https://ngrok.com/download) |

## Verify installation

After installing, run the preflight check:

```bash
cd /path/to/your/wordpress-project
npx wp-dev-sync init     # Creates .env
npx wp-dev-sync setup    # Checks everything
```

The setup command will show you what's installed, what's missing, and how to fix it.

## Windows notes

WP Dev Sync is designed to run in **Git Bash** on Windows. The CLI automatically extends your PATH to find tools installed via:

- **Chocolatey** (`/c/ProgramData/chocolatey/bin`)
- **Scoop** (`~/scoop/shims`)
- **Git for Windows** (`/c/Program Files/Git/usr/bin`)
- **Windows OpenSSH** (`/c/Windows/System32/OpenSSH`)

If a tool is installed but not found, the PATH fix in `lib/_env.sh` handles it automatically.
