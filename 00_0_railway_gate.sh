#!/bin/bash
# Runs first of the my_init.d scripts. Railway's Free plan caps a service at
# 0.5 GB: the web UI starts, but every station's Liquidsoap is OOM-killed in a
# loop, and Railway counts the kills against the template. On a service that
# small, serve a page that says what's needed and never return, so my_init
# doesn't start MariaDB, Redis or supervisord at all.

mem=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
case "$mem" in ''|max) exit 0 ;; esac
[ "$mem" -ge 900000000 ] && exit 0

port=${PORT:-80}
mkdir -p /run/gate
cat > /run/gate/index.html <<HTML
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>AzuraCast needs more memory</title><style>body{font:16px/1.5 system-ui,sans-serif;max-width:40rem;margin:3rem auto;padding:0 1rem}</style></head>
<body><h1>AzuraCast needs at least 1 GB of memory</h1>
<p>This service is limited to $((mem / 1000000)) MB, which is Railway's Free plan. AzuraCast's web panel would start, but every radio station is killed for lack of memory as soon as it goes on air, so nothing has been started.</p>
<p>The Trial plan (1 GB) runs a station, and Hobby gives room for several. Upgrade, then redeploy this service.</p></body></html>
HTML
cat > /run/gate/nginx.conf <<CONF
worker_processes 1;
pid /run/gate/nginx.pid;
error_log stderr;
events {}
http {
  access_log off;
  server {
    listen $port default_server;
    listen [::]:$port default_server;
    root /run/gate;
    location = /api/status { default_type application/json; return 200 '{"online":true,"gate":"needs 1 GB"}'; }
    location / { try_files /index.html =404; }
  }
}
CONF
echo "Railway: this service is limited to $((mem / 1000000)) MB, under the 1 GB AzuraCast needs. Serving instructions on :$port instead of starting AzuraCast."
exec nginx -c /run/gate/nginx.conf -g 'daemon off;'
