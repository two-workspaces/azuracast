#!/bin/bash
# Stock init scripts do `chown -R` on paths we replaced with symlinks;
# GNU chown -R doesn't traverse a symlink argument, so redo it on the target.

[ -d /data ] || exit 0

chown -R azuracast:azuracast /data/sftpgo 2>/dev/null || true

# Liquidsoap caches each station's compiled script under www_tmp, which
# 10_clear_temp empties on every boot. Keep it on the volume so a restarted
# station loads in ~180 MB instead of recompiling.
mkdir -p /data/liquidsoap_user_cache
chown azuracast:azuracast /data/liquidsoap_user_cache
ln -sfn /data/liquidsoap_user_cache /var/azuracast/www_tmp/liquidsoap_cache

mem=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
case "$mem" in ''|max) mem=999999999999 ;; esac

# Under 0.9 GB, 00_0_railway_gate.sh served a "needs 1 GB" page and nothing
# below runs, so only bigger services get here.
if [ "$mem" -ge 900000000 ]; then
  # The standard-library cache baked into the image doesn't match this host,
  # so a station's first start compiles it: a ~760 MB spike on top of the
  # running services, OOM-killing the station on a 1 GB plan. Build it now,
  # before anything else runs; it stays on the volume and later boots only
  # check it (under a second).
  gosu azuracast env LIQ_CACHE_SYSTEM_DIR=/tmp/liquidsoap_cache liquidsoap --cache-stdlib >/dev/null 2>&1 ||
    echo "Building the Liquidsoap cache failed; stations will compile it on first start" >&2
fi

exit 0
