# Troubleshooting

## Common issues

### `.env file not found`

```
┌─ Error ──────────────────────────────────────────┐
│ .env file not found. Run: npx wp-dev-sync init           │
└──────────────────────────────────────────────────┘
```

**Cause:** No `.env` file in the current directory.

**Fix:**
```bash
npx wp-dev-sync init    # Creates .env from template
```

Make sure you're in the right directory (your project root).

---

### `LOCAL_PATH does not exist`

**Cause:** The path specified in `LOCAL_PATH` doesn't exist on your machine.

**Fix:** Verify the path in `.env`:
```bash
# Check if it exists
ls -la ./wp-content/themes/my-theme

# If relative path doesn't work, try absolute
LOCAL_PATH=/c/projects/mysite/wp-content/themes/my-theme
```

---

### `REMOTE_PATH is not set`

**Cause:** `REMOTE_PATH` is empty or not defined in `.env`.

**Fix:** Edit `.env` and set the full remote path:
```bash
REMOTE_PATH=/var/www/html/wp-content/themes/my-theme
```

---

### rsync: command not found (Windows)

**Cause:** rsync is installed but not in Git Bash's PATH.

**Fix options:**

1. WP Dev Sync auto-adds common paths — restart Git Bash and try again
2. Manual fix:
   ```bash
   export PATH="/c/ProgramData/chocolatey/bin:/c/ProgramData/chocolatey/lib/rsync/tools/bin:$PATH"
   ```
3. Reinstall:
   ```bash
   choco install rsync
   ```

---

### SSH: Connection refused

**Possible causes:**
- SSH is not enabled on the server
- Wrong port number
- Firewall blocking the connection

**Debug steps:**
```bash
# Test connection directly
ssh -p 22 user@myserver.com

# Try common alternative ports
ssh -p 2222 user@myserver.com
ssh -p 7822 user@myserver.com
ssh -p 18765 user@myserver.com
```

**Common port mappings:**

| Host | SSH Port |
|------|----------|
| Standard | 22 |
| SiteGround | 18765 |
| Bluehost | 2222 |
| GoDaddy | 22 |
| HostGator | 2222 |

**Note:** The SSH hostname may differ from the FTP hostname. Check your hosting panel for the correct SSH hostname.

---

### SSH: Permission denied (publickey)

**Cause:** SSH key not set up on the server.

**Fix:**
```bash
# Generate key
ssh-keygen -t ed25519

# Copy to server
ssh-copy-id -p 22 user@myserver.com

# If ssh-copy-id doesn't work (Windows):
cat ~/.ssh/id_ed25519.pub
# → Copy output and paste into server's ~/.ssh/authorized_keys
```

---

### FTP: Login incorrect

**Possible causes:**
- Wrong username or password
- IP not whitelisted
- Account locked

**Debug steps:**

1. Verify credentials match your hosting panel
2. Some hosts use the full email as username:
   ```bash
   REMOTE_USER=user@domain.com
   ```
3. Check if your hosting requires IP whitelisting (common on cPanel)
4. Try connecting with a standard FTP client (FileZilla) to isolate the issue

---

### FTP: SSL/TLS errors

**Cause:** lftp's SSL verification fails with the server's certificate.

WP Dev Sync already sets `ssl:verify-certificate no` to avoid this. If you still see SSL errors:

```bash
# Test directly with lftp
lftp -u user,password -p 21 myserver.com -e "set ssl:verify-certificate no; ls; quit"
```

---

### Sync is slow

**Possible causes and fixes:**

| Cause | Fix |
|-------|-----|
| Using FTP instead of SSH | Switch to `SYNC_PROTOCOL=ssh` if possible |
| Large excluded directories being scanned | Add to `SYNC_EXCLUDE`: `vendor,public/fonts` |
| Slow server connection | Expected — nothing to do |
| Windows polling mode | Normal (2s interval) — install fswatch isn't available for Windows |

**SSH performance tip:** rsync with `--checksum` is thorough but slightly slower than timestamp-based comparison. This is intentional — it catches all changes regardless of clock differences between local and remote.

---

### Watch mode doesn't detect changes

**macOS:**
```bash
# Install fswatch for native detection
brew install fswatch
```

**Linux:**
```bash
# Install inotify-tools for native detection
sudo apt install inotify-tools
```

**Windows:** Polling mode checks every 2 seconds. If a change isn't picked up, wait for the next cycle.

---

### lftp: Windows path errors

**Cause:** lftp on Windows (Chocolatey) doesn't understand Unix-style paths (`/c/Users/...`).

WP Dev Sync handles this automatically by converting paths with `cygpath -w`. If you still see path errors, check that `cygpath` is available:

```bash
which cygpath
# Should output: /usr/bin/cygpath
```

---

## Getting help

### Run the preflight check

```bash
npx wp-dev-sync setup
```

This command checks everything and provides actionable suggestions.

### Check your .env

```bash
cat .env
```

Verify all required variables are set and paths are correct.

### Test the connection manually

**SSH:**
```bash
ssh -p 22 user@myserver.com "echo ok"
```

**FTP:**
```bash
lftp -u user,password -p 21 myserver.com -e "ls; quit"
```

### Verbose rsync

For debugging, you can run rsync manually with extra verbosity:

```bash
rsync -avvz --compress --checksum -e "ssh -p 22" \
    ./wp-content/themes/my-theme/ \
    user@server:/path/to/theme/
```
