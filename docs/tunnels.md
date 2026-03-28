# Tunnels

WP Dev Sync can expose your remote site through a public URL using `wp-dev-sync tunnel`. This is useful for sharing previews with clients without configuring DNS or exposing the server's IP.

## Configuration

Add these variables to your `.env`:

```bash
TUNNEL_TOOL=cloudflared    # or: ngrok
TUNNEL_DOMAIN=staging.mysite.com
```

`TUNNEL_DOMAIN` is the domain (or IP) of your remote server that the tunnel will proxy.

## Cloudflare Tunnel (cloudflared)

Free, no account required for quick tunnels.

### Install

```bash
choco install cloudflared      # Windows
brew install cloudflared       # macOS
```

### How it works

```bash
wp-dev-sync tunnel
# → cloudflared tunnel --url https://staging.mysite.com
```

Cloudflare creates a temporary public URL like `https://random-words.trycloudflare.com` that proxies to your remote server.

### Pros
- Free, no signup
- Fast, global edge network
- HTTPS by default
- No bandwidth limits

### Cons
- Random URL (paid plan for custom domains)
- Temporary (stops when you close the terminal)

## ngrok

Popular tunnel tool with a free tier.

### Install

```bash
choco install ngrok            # Windows
brew install ngrok             # macOS
```

### How it works

```bash
wp-dev-sync tunnel
# → ngrok http https://staging.mysite.com
```

ngrok provides a public URL and a local dashboard at `http://localhost:4040` for inspecting requests.

### Pros
- Dashboard with request inspection
- Stable URLs on paid plans
- Replay requests for debugging

### Cons
- Free tier has limited connections
- Requires signup for some features

## Sync + Tunnel

Run both watch and tunnel simultaneously:

```bash
# Terminal 1
wp-dev-sync watch

# Terminal 2
wp-dev-sync tunnel
```

This gives you a full development workflow: edit locally, auto-sync to server, share via public URL.

## Use cases

- **Client previews** — Share a URL with a client to review progress
- **Mobile testing** — Access the staging site from your phone
- **Webhook testing** — Receive webhooks from third-party services to your staging server
- **Team review** — Let team members access the staging site without VPN
