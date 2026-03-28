# Examples

Real-world configuration examples for different WordPress setups.

## WordPress Classic (cPanel / Shared Hosting)

The most common setup. Your WordPress site is installed in `public_html` on a shared hosting provider.

```bash
# .env
LOCAL_PATH=./wp-content/themes/my-theme
REMOTE_PATH=/home/cpanel-user/public_html/wp-content/themes/my-theme
SYNC_PROTOCOL=ftp
REMOTE_USER=cpanel-user@domain.com
REMOTE_HOST=ftp.domain.com
REMOTE_PORT=21
REMOTE_PASSWORD=your-ftp-password
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env
SYNC_DELETE=false
```

## WordPress Bedrock

Bedrock uses a different directory structure with `web/app/themes/` instead of `wp-content/themes/`.

```bash
# .env
LOCAL_PATH=./web/app/themes/my-theme
REMOTE_PATH=/var/www/mysite/current/web/app/themes/my-theme
SYNC_PROTOCOL=ssh
REMOTE_USER=deploy
REMOTE_HOST=myserver.com
REMOTE_PORT=22
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,public/hot,vendor
SYNC_DELETE=false
```

## VPS with SSH

A standard VPS (DigitalOcean, Linode, Vultr, etc.) with SSH access.

```bash
# .env
LOCAL_PATH=./wp-content/themes/my-theme
REMOTE_PATH=/var/www/html/wp-content/themes/my-theme
SYNC_PROTOCOL=ssh
REMOTE_USER=root
REMOTE_HOST=203.0.113.10
REMOTE_PORT=22
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,public/hot
SYNC_DELETE=true
```

## Staging server (full wp-content)

Sync your entire `wp-content` directory, including plugins and uploads.

```bash
# .env
LOCAL_PATH=./wp-content
REMOTE_PATH=/var/www/staging/wp-content
SYNC_PROTOCOL=ssh
REMOTE_USER=deploy
REMOTE_HOST=staging.mysite.com
REMOTE_PORT=22
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,uploads
SYNC_DELETE=false
```

Note: Excluding `uploads` is recommended to avoid syncing large media files.

## SiteGround

SiteGround uses a non-standard SSH port.

```bash
# .env
LOCAL_PATH=./wp-content/themes/my-theme
REMOTE_PATH=/home/customer/public_html/wp-content/themes/my-theme
SYNC_PROTOCOL=ssh
REMOTE_USER=customer
REMOTE_HOST=mysite.sg-host.com
REMOTE_PORT=18765
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env
SYNC_DELETE=false
```

## WP Engine

WP Engine provides SSH access via their gateway.

```bash
# .env
LOCAL_PATH=./wp-content/themes/my-theme
REMOTE_PATH=/sites/mysite/wp-content/themes/my-theme
SYNC_PROTOCOL=ssh
REMOTE_USER=mysite
REMOTE_HOST=mysite.ssh.wpengine.net
REMOTE_PORT=22
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env
SYNC_DELETE=false
```

## Starter theme with build tools

A theme using Vite/Webpack for CSS/JS compilation. Exclude build artifacts and source maps.

```bash
# .env
LOCAL_PATH=./wp-content/themes/starter-theme
REMOTE_PATH=/var/www/html/wp-content/themes/starter-theme
SYNC_PROTOCOL=ssh
REMOTE_USER=deploy
REMOTE_HOST=myserver.com
REMOTE_PORT=22
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,public/hot,public/.vite,*.map
SYNC_DELETE=false
```

## Child theme only

Syncing just a child theme while the parent theme is already on the server.

```bash
# .env
LOCAL_PATH=./wp-content/themes/my-child-theme
REMOTE_PATH=/home/user/public_html/wp-content/themes/my-child-theme
SYNC_PROTOCOL=ftp
REMOTE_USER=ftp-user
REMOTE_HOST=ftp.myhost.com
REMOTE_PORT=21
REMOTE_PASSWORD=ftp-password
SYNC_EXCLUDE=.git,node_modules,.DS_Store
SYNC_DELETE=false
```

## Plugin development

WP Dev Sync isn't limited to themes. You can sync a plugin directory too.

```bash
# .env
LOCAL_PATH=./wp-content/plugins/my-plugin
REMOTE_PATH=/var/www/html/wp-content/plugins/my-plugin
SYNC_PROTOCOL=ssh
REMOTE_USER=deploy
REMOTE_HOST=myserver.com
REMOTE_PORT=22
SYNC_EXCLUDE=.git,node_modules,.DS_Store,*.log,.env,tests,vendor
SYNC_DELETE=true
```

## Non-WordPress project

While WP Dev Sync is designed for WordPress, it works with any directory:

```bash
# .env
LOCAL_PATH=./src
REMOTE_PATH=/var/www/html/myapp
SYNC_PROTOCOL=ssh
REMOTE_USER=deploy
REMOTE_HOST=myserver.com
REMOTE_PORT=22
SYNC_EXCLUDE=.git,node_modules,.DS_Store
SYNC_DELETE=true
```
