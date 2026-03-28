# Protocols

WP Dev Sync supports two protocols for transferring files to your remote server. Set the protocol in your `.env`:

```bash
SYNC_PROTOCOL=ssh    # or: ftp
```

## SSH (rsync) — Recommended

Uses `rsync` over an SSH connection. This is the fastest and most efficient option.

### How it works

rsync computes checksums of files on both sides and only transfers the **bytes that changed** (delta sync). This means:

- Editing one line in a PHP file transfers a few bytes, not the whole file
- Unchanged files are skipped entirely
- Large directories with few changes sync in under a second

### Requirements

- `rsync` installed locally and on the remote server
- SSH access to the server
- SSH key configured (recommended) or password auth

### Authentication

**SSH key (recommended):**

```bash
# Generate a key if you don't have one
ssh-keygen -t ed25519

# Copy to the server
ssh-copy-id -p 22 user@myserver.com

# Test
ssh -p 22 user@myserver.com
```

Once your key is set up, syncing is fully passwordless.

**Password auth:**

rsync will prompt for your password on each sync. This works but is impractical for watch mode. Use SSH keys instead.

### rsync flags used

```
-a          Archive mode (preserves permissions, timestamps, symlinks)
-v          Verbose (shows transferred files)
-z          Compress during transfer
--compress  Same as -z
--checksum  Use checksums instead of timestamps for change detection
--delete    Mirror mode (only when SYNC_DELETE=true)
--exclude   Patterns from SYNC_EXCLUDE
```

### When to use SSH

- You have SSH access to your server (VPS, dedicated, managed hosting with SSH)
- You want the fastest possible sync
- You're syncing frequently (watch mode)

---

## FTP (lftp)

Uses `lftp` for FTP mirror syncing. Works with any hosting that provides FTP access.

### How it works

lftp's `mirror` command compares the local and remote directory trees and transfers changed files. Unlike rsync, it transfers **whole files** rather than deltas.

### Requirements

- `lftp` installed locally
- FTP access to the server (username + password)

### Authentication

FTP uses username and password from `.env`:

```bash
SYNC_PROTOCOL=ftp
REMOTE_USER=your-ftp-username
REMOTE_PASSWORD=your-ftp-password
REMOTE_PORT=21
```

### lftp flags used

```
mirror --reverse       Upload direction (local → remote)
mirror                 Download direction (remote → local)
--no-perms             Don't sync permissions (avoids issues on shared hosting)
--verbose=1            Show transferred files
--delete               Mirror mode (only when SYNC_DELETE=true)
--exclude              Patterns from SYNC_EXCLUDE (converted to regex)
set ssl:verify-certificate no    Skip SSL cert verification (common on shared hosting)
```

### When to use FTP

- Your hosting only provides FTP access (no SSH)
- You're on shared hosting (cPanel, Plesk)
- You can't install rsync on the server

---

## Comparison

| Feature | SSH (rsync) | FTP (lftp) |
|---------|-------------|------------|
| Speed | Fast (delta transfer) | Slower (full file transfer) |
| Security | Encrypted (SSH) | Unencrypted (unless FTPS) |
| Auth | SSH key (passwordless) | Username + password |
| Server requirement | rsync + SSH | FTP server |
| Availability | VPS, dedicated, some managed | Nearly universal |
| Watch mode | Excellent | Works, but slower |
| `SYNC_DELETE` | Supported | Supported |

### Performance example

Changing one line in a 50KB PHP file:

| Protocol | Transferred | Time |
|----------|-------------|------|
| SSH (rsync) | ~200 bytes | <1s |
| FTP (lftp) | 50KB | 1-3s |

---

## Windows path handling

On Windows (Git Bash), `lftp` installed via Chocolatey expects Windows-style paths (`C:\Users\...`) rather than Unix-style (`/c/Users/...`). WP Dev Sync automatically converts paths using `cygpath -w` when running on Windows with FTP protocol.

This is handled transparently — you don't need to do anything special.
