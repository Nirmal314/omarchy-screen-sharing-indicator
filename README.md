# Screen Sharing Indicator

A small Omarchy bar widget that shows a pulsing red dot in the bar while anything shares or records your screen. It covers screen sharing through the desktop portal, which is how Zoom, Teams, Discord, and browser tabs hand your screen to an app, plus direct recorders such as OBS Studio and gpu-screen-recorder.

The widget takes up no space when idle. The dot only appears when it detects an active share, so the bar stays clean the rest of the time.

## Requirements

- Omarchy with the Quattro shell
- A running PipeWire session (wireplumber)
- `pw-dump`, part of the PipeWire tools
- `jq`
- `pgrep`, from procps
- A portal implementation such as xdg-desktop-portal-hyprland, if you share through a portal

A standard Omarchy install already provides all of the above, so nothing extra is usually needed.

## How it works

Every poll interval (3 seconds by default), the widget runs its bundled `bin/screen-sharing.sh` script. The script asks PipeWire for a full dump of its graph with `pw-dump`, and treats the screen as shared when:

- at least one Video/Source node carries a screencast, portal, capture, or cap mark, and
- an active PipeWire link feeds that node, meaning an application is actually pulling the stream.

A portal node that lingers after an app disconnects but has no active link does not count as a share. An active consumer is the reliable signal.

The script also checks two direct recorders: OBS Studio, only when it has a connected screen-capture source in the PipeWire graph, and `gpu-screen-recorder`, Omarchy's built-in recording engine. It matches OBS by process name and then confirms an OBS video source actually exists in the graph, so a running but idle OBS does not light the dot.

The script prints one line of JSON, for example `{"sharing":true,"source":"obs"}`. The widget parses that line and shows or hides the pulsing dot accordingly.

## Usage

No interaction is required. Start a screen share or recording and a red dot appears in the center of the bar, pulsing softly. It disappears one poll interval, at most a few seconds, after the share ends. Hover over the dot to see which application is sharing, such as "Screen Shared (obs)".

The dot has no click action. It is informational only, so it cannot be dismissed or mis-triggered by accident.

## Installation

```sh
omarchy plugin add https://github.com/Nirmal314/omarchy-screen-sharing-indicator --enable
```

After installing, start a screen share to confirm the red dot appears in the center of the bar. If it does not show, see Troubleshooting.

## Modify

The poll interval, 1 to 30 seconds, is a plugin setting exposed in the Omarchy widget settings (stored under the plugin's settings block in `~/.config/omarchy/shell.json` under the key `pollSeconds`). The default of 3 balances a quick reaction with negligible overhead.

To change what the widget detects, edit `bin/screen-sharing.sh`. It is plain bash, so adding an app to `detect_app_sharing` or narrowing the node matching in `detect_portal_sharing` is straightforward.

To change the look, edit the dot and its pulse animation in `BarWidget.qml`. The dot is a `Rectangle` whose `SequentialAnimation` fades its opacity; the color comes from `Color.urgent`.

Saved changes reload automatically. When they do not, run `omarchy restart shell`.

## Local development

From a local checkout, validate the folder and install it:

```sh
omarchy plugin validate .
omarchy plugin add "$(pwd)" --enable
```

The widget can be linted against the installed shell imports:

```sh
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml
```

The detection script can be exercised directly. While something shares your screen:

```sh
./bin/screen-sharing.sh
# {"sharing":true,"source":"portal"}
```

Otherwise it prints `{"sharing":false,"source":""}`. The exit code signals whether sharing was detected, but the widget trusts the JSON line, so check the output rather than the exit status.

## Remove

```sh
omarchy plugin remove archer-nemo.screen-sharing
```

Removal deletes the plugin folder and its entry in Omarchy's plugin state. The widget keeps no state of its own, so there are no leftover files to clean up beyond the folder itself.

## Troubleshooting

### Widget enabled but the dot never appears

Put the widget back in the bar with a disable plus enable:

```sh
omarchy plugin disable archer-nemo.screen-sharing
omarchy plugin enable archer-nemo.screen-sharing
```

If the widget is still registered as a plain plugin from an earlier install, the enable command treats it as already installed and moves nothing. The disable drops that stale registration, and the enable then places the widget in the bar.

### The enable command says the plugin is not known

The shell discovers plugin folders at startup and after a rescan. Run `omarchy-shell shell rescanPlugins`, then enable again.

If the dot still does not show once sharing starts, check the shell log for QML errors:

```sh
qs log -p "$OMARCHY_PATH/shell" --tail 100 | grep -i error
```

## Security and system access

Omarchy plugins run unsandboxed with your user permissions, so review the code before installing it. This plugin:

- Makes no network requests and needs no elevated permissions.
- Reads no personal files. It inspects only your current PipeWire user session and the processes you can already see.
- Runs its bundled `screen-sharing.sh`, which invokes `pw-dump`, `jq`, and `pgrep`. `pgrep` is limited to your own processes, so it does not reveal other users' activity.
- Changes nothing on the system. It only observes the PipeWire graph and the process table, and stores no state on disk apart from the `pollSeconds` setting that Omarchy keeps.
