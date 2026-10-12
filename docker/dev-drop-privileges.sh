#!/bin/sh
# Re-exec the calling entrypoint as the host user so files written to bind
# mounts (database, uploads) stay editable on the host.
#
# Source this file, set DEV_CHOWN_PATHS, then call:
#   dev_drop_privileges "$@"

dev_drop_privileges() {
  if [ "$(id -u)" != "0" ]; then
    export HOME=/home/appuser
    return 0
  fi

  uid="${DEV_UID:-1000}"
  gid="${DEV_GID:-1000}"

  if [ "$uid" = "0" ]; then
    return 0
  fi

  if ! getent group "$gid" >/dev/null 2>&1; then
    groupadd --gid "$gid" appuser
  fi

  # The cache volume mount can create /home/appuser before this user exists.
  mkdir -p /home/appuser
  if ! getent passwd "$uid" >/dev/null 2>&1; then
    useradd \
      --uid "$uid" \
      --gid "$gid" \
      --no-create-home \
      --home-dir /home/appuser \
      --shell /bin/bash \
      appuser
  fi

  user_name=$(getent passwd "$uid" | cut -d: -f1)
  usermod -d /home/appuser -g "$gid" "$user_name"
  mkdir -p /home/appuser
  chown "$uid:$gid" /home/appuser

  if [ -n "${DEV_CHOWN_PATHS:-}" ]; then
    # shellcheck disable=SC2086
    mkdir -p $DEV_CHOWN_PATHS
    for path in $DEV_CHOWN_PATHS; do
      owner=$(stat -c '%u' "$path")
      if [ "$owner" != "$uid" ]; then
        chown -R "$uid:$gid" "$path"
      fi
    done
  fi

  exec gosu "$user_name" "$0" "$@"
}
