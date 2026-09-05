#!/usr/bin/env bash
# Detect active screen sharing / recording via PipeWire (xdg-desktop-portal)
# and common screen sharing/recording applications.
#
# Exit code 0 = screen is being shared, 1 = not sharing.
# Output: JSON {"sharing":true|false,"source":"<app>"}

set -euo pipefail

# A screencast via xdg-desktop-portal-hyprland exposes a Video/Source node in
# PipeWire. Detection: at least one such Video/Source node exists AND has at
# least one active link feeding a real consumer, meaning an application is
# actively pulling the screen stream. A lingering but unlinked portal node is
# not an active share (portal nodes can persist briefly after the app
# disconnects, so an active link is the reliable signal).
detect_portal_sharing() {
  local dump
  dump=$(pw-dump 2>/dev/null) || return 1

  local portal_node_ids
  portal_node_ids=$(printf '%s' "$dump" | jq -r '
    [.[]
     | select(.type == "PipeWire:Interface:Node")
     | select(.info.props["media.class"] == "Video/Source")
     | select(
         (.info.props["node.name"] // "" | test("screencast|portal|cap|capture"; "i"))
         or (.info.props["media.name"] // "" | test("screencast|portal|cap|capture"; "i"))
       )
     | .id]
    | .[]
  ') || return 1

  [ -z "$portal_node_ids" ] && return 1

  local nids_json
  nids_json=$(printf '%s' "$portal_node_ids" | paste -sd, -)
  nids_json="[$nids_json]"

  # Require an ACTIVE link consuming one of the portal nodes (state == "active").
  # Returning 1 (not sharing) when no such link exists.
  printf '%s' "$dump" | jq -e \
    --argjson nids "$nids_json" '
      [.[]
       | select(.type == "PipeWire:Interface:Link")
       | select(.info.state == "active")
       | select(.info["output-node-id"] as $o | $nids | index($o) != null)]
      | length > 0
    ' >/dev/null 2>&1 && {
    echo "portal"
    return 0
  }

  return 1
}

detect_app_sharing() {
  # gpu-screen-recorder (Omarchy's built-in recording engine)
  if pgrep -f "^gpu-screen-recorder" >/dev/null 2>&1; then
    echo "gpu-screen-recorder"
    return 0
  fi

  # OBS Studio with a screen-capture source connected
  if pgrep -x "obs" >/dev/null 2>&1 || pgrep -f "^/usr/bin/obs" >/dev/null 2>&1; then
    if pw-dump 2>/dev/null | jq -e '
      [.[]
       | select(.type == "PipeWire:Interface:Node")
       | select(.info.props["media.class"] == "Video/Source")
       | select(.info.props["node.name"] // "" | test("obs"; "i"))]
      | length > 0
    ' >/dev/null 2>&1; then
      echo "obs"
      return 0
    fi
  fi

  return 1
}

# Run detection
source=""
if source=$(detect_portal_sharing); then
  printf '{"sharing":true,"source":"%s"}\n' "$source"
elif source=$(detect_app_sharing); then
  printf '{"sharing":true,"source":"%s"}\n' "$source"
else
  printf '{"sharing":false,"source":""}\n'
fi
