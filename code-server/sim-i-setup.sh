#!/bin/sh
# Run at each start of code-server, as its user: installs the Sim i extension from the image (replacing an older one),
# points it at Sim i, and sets git's name and email when the settings give them.
set -eu

data="$HOME/.local/share/code-server"
version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' /opt/sim-i/extension/package.json | head -n 1)
mkdir -p "$data/extensions" "$data/Machine" "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
rm -rf "$data"/extensions/sim-i.sim-i-*
cp -r /opt/sim-i/extension "$data/extensions/sim-i.sim-i-$version"
# A list of the extensions the folder holds: VS Code reads it, and adds this one again from the folder.
rm -f "$data/extensions/extensions.json"

# Colouring for RPG, CL, DDS and the other IBM i source types, which the Sim i extension doesn't have: IBM i Languages
# (barrettotte.ibmi-languages, from Open VSX). It uses the same language id for RPG, so it colours Sim i's RPG members.
# Installed once into code-server's home volume; without a network, code-server starts without it.
if ! ls -d "$data"/extensions/barrettotte.ibmi-languages-* >/dev/null 2>&1; then
  code-server --install-extension barrettotte.ibmi-languages@0.7.4 >/dev/null 2>&1 \
    || echo "sim-i-setup: couldn't install barrettotte.ibmi-languages: no colouring for IBM i source" >&2
fi

# The machine's settings: Sim i inside compose's network, and the developer who signs on to it. A user's own settings win.
user=$(printf '%s' "${SIM_I_DEVELOPER_USER:-}" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9#$@_')
# The site's address in the browser, for opening the terminal (and where programs with screens run when debugged).
site=$(printf '%s' "${SIM_I_PUBLIC_URL:-}" | tr -d '"\\')
cat > "$data/Machine/settings.json" <<EOF
{
  "simI.host": "sim-i",
  "simI.webPort": 8080,
  "simI.debugPort": 4711,
  "simI.user": "$user",
  "simI.sourceRoot": "/source",
  "simI.siteUrl": "$site",
  "telemetry.telemetryLevel": "off"
}
EOF

if [ -n "${SIM_I_GIT_NAME:-}" ]; then git config --global user.name "$SIM_I_GIT_NAME"; fi
if [ -n "${SIM_I_GIT_EMAIL:-}" ]; then git config --global user.email "$SIM_I_GIT_EMAIL"; fi
