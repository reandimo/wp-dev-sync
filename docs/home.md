# WP Dev Sync — Wiki

Welcome to the WP Dev Sync documentation. WP Dev Sync is a CLI tool that syncs your local WordPress theme files to a remote server automatically — bringing the same developer experience that Shopify offers with `shopify theme dev` to the WordPress ecosystem.

## What it does

- **Smart reconciliation** — compares local and remote files before syncing, shows exactly which files differ, and lets you choose what to do per category (local-only, remote-only, differing)
- Watches your local theme directory for file changes
- Automatically uploads changed files to your remote server via SSH (rsync) or FTP (lftp)
- **Gradient progress bar** — tracks file-by-file progress during initial sync
- **Diff command** — compare local vs remote like `git status` without syncing
- Supports one-time push/pull operations for manual syncing
- **Multi-environment manager** — switch between staging, production, etc. with one command
- Provides a preflight check to verify dependencies and server connectivity
- Optionally exposes your remote site via public tunnels (Cloudflare/ngrok)

## Why

Developing WordPress themes on remote servers typically means:

1. **FTP clients** — Drag and drop files manually in FileZilla every time you save
2. **Git-based deploys** — Commit, push, wait for CI/CD, then check the result
3. **Local environments** — Full Docker/MAMP/XAMPP setups that may not match production

WP Dev Sync eliminates all of that. You edit files locally with your favorite editor, and they appear on your server in seconds. No commits required, no FTP clients, no complex local environments.

## Who it's for

- WordPress theme developers working on remote/staging servers
- Freelancers deploying to client hosting (cPanel, Plesk, shared hosting)
- Teams that need fast iteration on staging environments
- Anyone tired of manual FTP uploads

## Table of Contents

- [Installation](installation.md)
- [Configuration](configuration.md)
- [Commands](commands.md)
- [Protocols](protocols.md)
- [Watch Mode](watch-mode.md)
- [Tunnels](tunnels.md)
- [Architecture](architecture.md)
- [Troubleshooting](troubleshooting.md)
- [Examples](examples.md)
