# Pinned, not :latest — upstream keeps changing its init scripts (MariaDB is
# now disabled unless MYSQL_HOST=localhost, for one), and a silent rebase
# breaks every deploy of this template at once. Bump deliberately.
FROM ghcr.io/azuracast/azuracast:0.24.0

# The in-app updater needs the sidecar updater container + docker.sock,
# neither of which exists on Railway. Updates happen by redeploying instead.
ENV ENABLE_WEB_UPDATER=false

# Upstream nginx runs `worker_processes auto`, which counts host cores, not the
# container's CPU quota: Railway Metal hosts show 48, so nginx forked 48 workers
# at ~30 MB each — ~1.5 GB idle — and the container was OOM-killed on the Trial
# (1 GB) and Free (0.5 GB) plans before the health check ever passed. The
# config is rendered from this template at boot, so patch the template.
RUN sed -i 's/^worker_processes auto;/worker_processes 2;/' /etc/nginx/nginx.conf.tmpl \
    && grep -q '^worker_processes 2;' /etc/nginx/nginx.conf.tmpl

COPY 00_0_railway_gate.sh /etc/my_init.d/00_0_railway_gate.sh
COPY 00_railway_volumes.sh /etc/my_init.d/00_railway_volumes.sh
COPY 99_railway_fixups.sh /etc/my_init.d/99_railway_fixups.sh
COPY drop-file-cache /usr/local/bin/drop-file-cache
COPY drop-file-cache.conf /etc/supervisor/full.conf.d/drop-file-cache.conf
RUN chmod +x /etc/my_init.d/00_0_railway_gate.sh /etc/my_init.d/00_railway_volumes.sh /etc/my_init.d/99_railway_fixups.sh /usr/local/bin/drop-file-cache
