#!/usr/bin/env bash
# Deploy businessmassan_website from this repo to the Odoo container.
#
# Usage:
#   ./deploy.sh                 # deploy + module update
#   ./deploy.sh --no-update     # deploy files only
#
# The module source lives here in git; the container only has a copy at
# /usr/share/odoo-website/. Never edit the container copy directly.
#
# Working path note: the SSH key from hansolo18 to the businessmassan
# container is gone. We go via the Salt master (192.168.11.22) instead.
# salt-cp does not work in this environment (silently fails), so files
# are transferred as base64 written in chunks through cmd.run.

set -euo pipefail

MASTER="192.168.11.22"
MINION="businessmassan"
MODULE="businessmassan_website"
REMOTE_DIR="/usr/share/odoo-website"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHUNK=60000

run() { ssh -o BatchMode=yes "$MASTER" "sudo -n salt $MINION cmd.run \"$1\" --timeout ${2:-120} 2>/dev/null"; }

echo "==> Packaging $MODULE"
TARBALL=$(mktemp /tmp/bmdeploy.XXXXXX.tgz)
# --exclude bilder om de redan finns i containern (snabbare upprepade deploys)
EXCL=""
if [ "${SKIP_IMAGES:-}" = "1" ]; then
  EXCL="--exclude=$MODULE/static/src/img"
  echo "    (hoppar över static/src/img)"
fi
tar czf "$TARBALL" $EXCL -C "$REPO_DIR" "$MODULE"
B64FILE=$(mktemp /tmp/bmdeploy.XXXXXX.b64)
base64 -w0 "$TARBALL" > "$B64FILE"
SIZE=$(wc -c < "$B64FILE")
N=$(( (SIZE + CHUNK - 1) / CHUNK ))
echo "    $SIZE bytes base64, $N chunks"

echo "==> Transferring via $MASTER"
run "rm -f /tmp/bmdeploy.b64" 30 >/dev/null
for i in $(seq 0 $((N-1))); do
  START=$((i * CHUNK))
  PART=$(dd if="$B64FILE" bs=1 skip=$START count=$CHUNK 2>/dev/null)
  run "printf '%s' '$PART' >> /tmp/bmdeploy.b64" 60 >/dev/null
done

echo "==> Unpacking in container"
run "base64 -d /tmp/bmdeploy.b64 > /tmp/bmdeploy.tgz && \
     cd $REMOTE_DIR && \
     cp -r $MODULE /tmp/bm_backup_\$(date +%s) && \
     tar xzf /tmp/bmdeploy.tgz && \
     echo DEPLOYED && grep version $MODULE/__manifest__.py" 120

if [ "${1:-}" = "--no-update" ]; then
  echo "==> Skipping module update (--no-update)"
  rm -f "$TARBALL" "$B64FILE"
  exit 0
fi

echo "==> Updating module"
# Skriv ett skript i containern — undviker citatproblem genom Salt
run "cat > /tmp/bm_update.sh <<'SH'
#!/bin/bash
sudo -u odoo /usr/bin/odoo -c /etc/odoo/odoo.conf -d businessmassan \
     --no-http --stop-after-init -u MODULE 2>&1 \
     | grep -iE 'Modules loaded|ERROR|CRITICAL|ParseError' | tail -5
systemctl restart odoo
sleep 10
systemctl is-active odoo
SH
sed -i 's/MODULE/$MODULE/' /tmp/bm_update.sh && bash /tmp/bm_update.sh" 300

echo "==> Restarting Odoo (clears view cache)"
run "systemctl restart odoo && sleep 10 && systemctl is-active odoo" 60

echo "==> Verifying pages"
for u in / /boka /for-utstallare /program /nkpg /boka-nkpg \
         /for-utstallare-i-nkpg /program-nkpg /save-the-date /tidigare-massor; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 "https://businessmassan.azzar.org$u")
  printf "    %-30s %s\n" "$u" "$code"
done

rm -f "$TARBALL" "$B64FILE"
echo "==> Done"
