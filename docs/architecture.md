# Architecture

## Directory structure

```
wp-sync/
├── bin/
│   └── wp-sync              # CLI entry point (bash)
├── lib/
│   ├── _env.sh              # Environment loader
│   ├── _ui.sh               # Terminal UI functions
│   └── _sync.sh             # Core sync engine
├── commands/
│   ├── watch.sh             # File watcher + auto-sync
│   ├── push.sh              # One-time upload
│   ├── pull.sh              # One-time download
│   ├── tunnel.sh            # Public tunnel
│   └── setup.sh             # Preflight check
├── docs/                    # Wiki documentation
├── package.json             # npm package config
├── .env.example             # Configuration template
└── README.md
```

## How it works

### Entry point: `bin/wp-sync`

The CLI entry point resolves its own real path (following symlinks from `npm link` or `npm install -g`), then dispatches to the appropriate command.

```
User runs: wp-sync push
                │
                ▼
        bin/wp-sync
                │
                ├── Resolves WP_SYNC_ROOT (follows symlinks)
                ├── Exports WP_SYNC_LIB and WP_SYNC_COMMANDS
                │
                ▼
        case "$COMMAND" in
            push) source commands/push.sh ;;
            ...
        esac
```

Built-in commands (`init`, `help`, `version`) are handled directly in `bin/wp-sync` without sourcing external files.

### Library: `lib/`

Three shared libraries, sourced by commands in order:

#### 1. `_env.sh` — Environment loader

- Resolves the `.env` file path (current working directory)
- On Windows, extends PATH with Chocolatey/Scoop/Git paths
- Parses `.env` line-by-line (handles special characters in passwords)
- Exports all variables to the shell environment

#### 2. `_ui.sh` — Terminal UI

Pure bash terminal formatting:

| Function | Purpose |
|----------|---------|
| `ui_banner` | Centered title box with optional subtitle |
| `ui_section` | Section header with icon |
| `ui_ok` | Green checkmark + text |
| `ui_fail` | Red X + text |
| `ui_warn` | Yellow warning + text |
| `ui_info` | Blue info + text |
| `ui_key_value` | Aligned key-value pair |
| `ui_error_box` | Red bordered error box |
| `ui_success_box` | Green bordered success box |
| `ui_spinner_start/stop` | Animated braille spinner |
| `ui_timestamp` | Dimmed HH:MM:SS |
| `detect_os_label` | Colored OS name |

#### 3. `_sync.sh` — Sync engine

Core logic for file transfer:

```
_sync.sh
├── Reads SYNC_PROTOCOL, REMOTE_PORT, SYNC_EXCLUDE, SYNC_DELETE
├── Resolves LOCAL_PATH to absolute
├── Handles Windows path conversion for lftp
│
├── _build_lftp_excludes()    Convert SYNC_EXCLUDE to lftp regex
├── _build_rsync_opts()       Build rsync flags with excludes
│
├── sync_push()               Upload LOCAL_PATH → REMOTE_PATH
│   ├── FTP: lftp mirror --reverse
│   └── SSH: rsync -avz
│
└── sync_pull()               Download REMOTE_PATH → LOCAL_PATH
    ├── FTP: lftp mirror
    └── SSH: rsync -avz (no --delete)
```

### Commands: `commands/`

Each command is a self-contained bash script that:

1. Sources `_env.sh` (loads config)
2. Sources `_ui.sh` (enables formatting)
3. Checks for `.env` existence
4. Sources `_sync.sh` if needed (provides sync functions)
5. Runs its specific logic

### Source order matters

```bash
# Correct order in commands that use sync:
source "$WP_SYNC_LIB/_env.sh"      # 1. Load .env
source "$WP_SYNC_LIB/_ui.sh"       # 2. Load UI (needed for error messages)
# Check .env exists here            # 3. Fail early with nice error
source "$WP_SYNC_LIB/_sync.sh"     # 4. Load sync (validates LOCAL_PATH, REMOTE_PATH)
```

This ensures that if `.env` is missing, the user sees a helpful error message instead of a raw bash error about undefined variables.

## npm global install

The `package.json` `bin` field maps the command name to the entry point:

```json
{
  "bin": {
    "wp-sync": "./bin/wp-sync"
  }
}
```

When installed globally (`npm install -g wp-sync`), npm creates a symlink in the global bin directory pointing to `bin/wp-sync`. The entry point follows this symlink to find `WP_SYNC_ROOT`, which allows it to locate `lib/` and `commands/` regardless of where the user runs the command.

## Design decisions

### Why bash, not Node.js?

- Zero runtime dependencies — bash is available everywhere
- rsync, lftp, ssh, fswatch, inotifywait are all CLI tools best invoked from bash
- The logic is simple (file watching + shell commands) — a Node.js wrapper would add complexity without benefit
- Works in Docker containers, CI/CD pipelines, and minimal environments

### Why .env, not a config file?

- `.env` is a widely understood format
- Easy to add to `.gitignore`
- Can coexist with other tools that use `.env`
- No parser dependencies (bash handles it natively)

### Why CWD for .env, not script-relative?

The original boilerplate looked for `.env` relative to the script location. The standalone CLI looks in the current working directory (CWD) because:

- Users `cd` into their project and run `wp-sync`
- Different projects have different configs
- Follows the convention of tools like Docker Compose, dotenv, etc.
