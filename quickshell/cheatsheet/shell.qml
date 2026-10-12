// Standalone Quickshell app (run as `qs -c cheatsheet`, separate from the
// compiled caelestia-shell binary). Toggled by Hyprland (SUPER + Slash)
// via `qs ipc -c cheatsheet call cheatsheet toggle` (see hypr-user.lua).
//
// Content is generated from two sources every time the sheet is opened:
//   - `hyprctl binds -j` for the live, ground-truth set of bound keys.
//   - The `groups` table below, which supplies the plain-English descriptions
//     and section groupings that hyprctl itself can't provide (Hyprland's lua
//     config registers every bind with dispatcher "__lua" and an empty
//     description field - there is no human-readable info left at runtime).
// A group is only shown if at least one of its key variants is still live, so
// removed binds disappear on their own. Any live bind that isn't in the table
// (a new/changed one) still surfaces, under System, as an undescribed entry.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root

    WlrLayershell.namespace: "caelestia-cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    focusable: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: false

    onVisibleChanged: if (visible)
        bindsProc.running = true

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            root.visible = !root.visible;
        }

        function show(): void {
            root.visible = true;
        }

        function hide(): void {
            root.visible = false;
        }
    }

    // ---- live colour scheme (same file caelestia-shell's Colours.qml reads) ----
    QtObject {
        id: scheme

        // Fallback values are the current catppuccin-mocha scheme so the sheet
        // looks right even before scheme.json has loaded.
        //
        // Names are prefixed (cSurface, cOnSurface, ...) rather than plain
        // (surface, onSurface, ...) because QML reserves the identifier
        // "onXxx" for any property "xxx" declared on the same object - a
        // plain "surface" + "onSurface" pair fails to parse. Caelestia's own
        // M3Palette (services/Colours.qml) sidesteps the same trap with its
        // "m3"/"m3on" prefixes.
        property color cSurface: "#131317"
        property color cSurfaceContainer: "#201f23"
        property color cSurfaceContainerHigh: "#2a292e"
        property color cSurfaceContainerHighest: "#353438"
        property color cOutline: "#918f9a"
        property color cOutlineVariant: "#47464f"
        property color cPrimary: "#c2c1ff"
        property color cOnPrimary: "#2a2a60"
        property color cPrimaryContainer: "#7171ac"
        property color cOnPrimaryContainer: "#ffffff"
        property color cSecondaryContainer: "#45455c"
        property color cOnSecondaryContainer: "#b4b2ce"
        property color cOnSurface: "#e5e1e7"
        property color cOnSurfaceVariant: "#c8c5d1"
        property color cScrim: "#000000"
    }

    FileView {
        id: schemeFile

        path: `${Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")}/caelestia/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyScheme(text())
    }

    function applyScheme(data: string): void {
        try {
            const parsed = JSON.parse(data);
            const c = parsed.colours;
            const propMap = {
                "surface": "cSurface",
                "surfaceContainer": "cSurfaceContainer",
                "surfaceContainerHigh": "cSurfaceContainerHigh",
                "surfaceContainerHighest": "cSurfaceContainerHighest",
                "outline": "cOutline",
                "outlineVariant": "cOutlineVariant",
                "primary": "cPrimary",
                "onPrimary": "cOnPrimary",
                "primaryContainer": "cPrimaryContainer",
                "onPrimaryContainer": "cOnPrimaryContainer",
                "secondaryContainer": "cSecondaryContainer",
                "onSecondaryContainer": "cOnSecondaryContainer",
                "onSurface": "cOnSurface",
                "onSurfaceVariant": "cOnSurfaceVariant",
                "scrim": "cScrim"
            };
            for (const jsonKey in propMap) {
                if (c[jsonKey])
                    scheme[propMap[jsonKey]] = `#${c[jsonKey]}`;
            }
        } catch (e) {
            console.warn("cheatsheet: failed to parse scheme.json:", e);
        }
    }

    // ---- live hyprctl binds ----
    property var liveBinds: []
    property var liveKeySet: ({})

    Process {
        id: bindsProc

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.liveBinds = parsed;
                    const set = {};
                    for (const b of parsed)
                        set[`${b.modmask}:${b.key.toLowerCase()}`] = true;
                    root.liveKeySet = set;
                } catch (e) {
                    console.warn("cheatsheet: failed to parse hyprctl binds:", e);
                }
            }
        }
    }

    // ---- modifier / key display helpers ----
    function modsLabel(mod: int): string {
        const parts = [];
        if (mod & 64)
            parts.push("Super");
        if (mod & 4)
            parts.push("Ctrl");
        if (mod & 1)
            parts.push("Shift");
        if (mod & 8)
            parts.push("Alt");
        return parts.length ? parts.join(" + ") : "(none)";
    }

    readonly property var keyNames: ({
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "page_up": "PgUp",
            "page_down": "PgDn",
            "mouse_up": "Scroll ↑",
            "mouse_down": "Scroll ↓",
            "mouse:272": "LMB drag",
            "mouse:273": "RMB drag",
            "super_l": "Super (tap)",
            "tab": "Tab",
            "comma": ",",
            "period": ".",
            "minus": "-",
            "equal": "=",
            "backslash": "\\",
            "backspace": "Backspace",
            "space": "Space",
            "delete": "Delete",
            "escape": "Esc",
            "print": "PrtScn",
            "slash": "/",
            "caps_lock": "Caps Lock",
            "num_lock": "Num Lock",
            "xf86audioplay": "Play",
            "xf86audiopause": "Pause",
            "xf86audionext": "Next Track",
            "xf86audioprev": "Prev Track",
            "xf86audiostop": "Stop",
            "xf86audiomute": "Mute",
            "xf86audiomicmute": "Mic Mute",
            "xf86audioraisevolume": "Vol +",
            "xf86audiolowervolume": "Vol -",
            "xf86monbrightnessup": "Brightness +",
            "xf86monbrightnessdown": "Brightness -"
        })

    function prettyKey(key: string): string {
        const lower = key.toLowerCase();
        if (root.keyNames[lower] !== undefined)
            return root.keyNames[lower];
        return key.length === 1 ? key.toUpperCase() : key;
    }

    // ---- curated bind -> {section, description} table ----
    readonly property var sectionOrder: ["Apps", "Windows", "Workspaces", "Caelestia", "Media", "System"]

    readonly property var groups: [
        // Apps
        { section: "Apps", label: "Open terminal (foot)", keys: [[64, "T"]] },
        { section: "Apps", label: "Open browser (Firefox)", keys: [[64, "W"]] },
        { section: "Apps", label: "Open code editor (VSCodium)", keys: [[64, "C"]] },
        { section: "Apps", label: "Open file manager (Thunar)", keys: [[64, "E"]] },
        { section: "Apps", label: "Open audio settings (pwvucontrol)", keys: [[12, "V"]] },
        { section: "Apps", label: "Pick a colour from the screen", keys: [[65, "C"]] },

        // Windows
        { section: "Windows", label: "Focus window in direction", keys: [[64, "left"], [64, "right"], [64, "up"], [64, "down"]] },
        { section: "Windows", label: "Move window in direction", keys: [[65, "left"], [65, "right"], [65, "up"], [65, "down"]] },
        { section: "Windows", label: "Shrink window width", keys: [[64, "Minus"], [72, "Left"]] },
        { section: "Windows", label: "Grow window width", keys: [[64, "Equal"], [72, "Right"]] },
        { section: "Windows", label: "Shrink window height", keys: [[65, "Minus"], [72, "Up"]] },
        { section: "Windows", label: "Grow window height", keys: [[65, "Equal"], [72, "Down"]] },
        { section: "Windows", label: "Move window with mouse", keys: [[64, "mouse:272"], [64, "Z"]] },
        { section: "Windows", label: "Resize window with mouse", keys: [[64, "mouse:273"], [64, "X"]] },
        { section: "Windows", label: "Centre the floating window", keys: [[68, "Backslash"]] },
        { section: "Windows", label: "Reset window size and centre it", keys: [[76, "Backslash"]] },
        { section: "Windows", label: "Toggle picture-in-picture pin", keys: [[72, "Backslash"]] },
        { section: "Windows", label: "Pin window to all workspaces", keys: [[64, "P"]] },
        { section: "Windows", label: "Toggle fullscreen", keys: [[64, "F"]] },
        { section: "Windows", label: "Toggle maximised (bordered fullscreen)", keys: [[72, "F"]] },
        { section: "Windows", label: "Toggle floating", keys: [[72, "Space"]] },
        { section: "Windows", label: "Close window", keys: [[64, "Q"]] },
        { section: "Windows", label: "Cycle recent windows forward / backward", keys: [[8, "TAB"], [9, "TAB"]] },
        { section: "Windows", label: "Cycle grouped tabs forward / backward", keys: [[12, "TAB"], [13, "TAB"]] },
        { section: "Windows", label: "Toggle window group", keys: [[64, "Comma"]] },
        { section: "Windows", label: "Lock active group (block new tabs)", keys: [[65, "Comma"]] },
        { section: "Windows", label: "Remove window from group", keys: [[64, "U"]] },

        // Workspaces
        { section: "Workspaces", label: "Switch to workspace 1-10", digits: true, mod: 64 },
        { section: "Workspaces", label: "Move window to workspace 1-10", digits: true, mod: 72 },
        { section: "Workspaces", label: "Switch to workspace group 1-10", digits: true, mod: 68 },
        { section: "Workspaces", label: "Move window to workspace group 1-10", digits: true, mod: 76 },
        { section: "Workspaces", label: "Previous / next workspace", keys: [[64, "Page_Up"], [64, "Page_Down"], [64, "mouse_up"], [64, "mouse_down"], [68, "Left"], [68, "Right"]] },
        { section: "Workspaces", label: "Previous / next workspace group", keys: [[68, "mouse_up"], [68, "mouse_down"]] },
        { section: "Workspaces", label: "Move window to previous / next workspace", keys: [[72, "mouse_down"], [72, "mouse_up"], [72, "Page_Down"], [72, "Page_Up"], [69, "Right"], [69, "Left"]] },
        { section: "Workspaces", label: "Move window to / from special workspace", keys: [[72, "S"], [69, "Up"], [69, "Down"]] },
        { section: "Workspaces", label: "Toggle scratchpad workspace", keys: [[64, "S"]] },
        { section: "Workspaces", label: "Toggle music workspace", keys: [[64, "M"]] },
        { section: "Workspaces", label: "Toggle communication workspace", keys: [[64, "D"]] },
        { section: "Workspaces", label: "Toggle todo workspace", keys: [[64, "R"]] },

        // Caelestia (shell UI + its CLI utilities)
        { section: "Caelestia", label: "Open app launcher", keys: [[64, "SUPER_L"]] },
        { section: "Caelestia", label: "Toggle all panels (launcher, dashboard, OSD)", keys: [[64, "K"]] },
        { section: "Caelestia", label: "Toggle sidebar (notifications)", keys: [[64, "N"]] },
        { section: "Caelestia", label: "Open session menu (logout/shutdown/reboot)", keys: [[12, "Delete"]] },
        { section: "Caelestia", label: "Lock screen", keys: [[64, "L"]] },
        { section: "Caelestia", label: "Restore lock screen (after crash/restart)", keys: [[72, "L"]] },
        { section: "Caelestia", label: "Clear all notifications", keys: [[12, "C"]] },
        { section: "Caelestia", label: "Open settings (Nexus)", keys: [[64, "I"]] },
        { section: "Caelestia", label: "Take a screenshot", keys: [[0, "Print"]] },
        { section: "Caelestia", label: "Freeze screen, then screenshot", keys: [[65, "S"]] },
        { section: "Caelestia", label: "Screenshot a selected region", keys: [[73, "S"]] },
        { section: "Caelestia", label: "Start/stop screen recording", keys: [[12, "R"]] },
        { section: "Caelestia", label: "Start/stop recording with sound", keys: [[72, "R"]] },
        { section: "Caelestia", label: "Record a selected region", keys: [[73, "R"]] },
        { section: "Caelestia", label: "Open clipboard history", keys: [[64, "V"]] },
        { section: "Caelestia", label: "Delete a clipboard history entry", keys: [[72, "V"]] },
        { section: "Caelestia", label: "Paste most recent clipboard item", keys: [[13, "V"]] },
        { section: "Caelestia", label: "Open emoji picker", keys: [[64, "Period"]] },
        { section: "Caelestia", label: "Reload Caelestia shell (kill only)", keys: [[69, "R"]] },
        { section: "Caelestia", label: "Restart Caelestia shell", keys: [[76, "R"]] },
        { section: "Caelestia", label: "Open this cheat sheet", keys: [[64, "Slash"]], always: true },

        // Media
        { section: "Media", label: "Play / pause media", keys: [[0, "XF86AudioPlay"], [0, "XF86AudioPause"], [68, "Space"]] },
        { section: "Media", label: "Next track", keys: [[0, "XF86AudioNext"], [68, "Equal"]] },
        { section: "Media", label: "Previous track", keys: [[0, "XF86AudioPrev"], [68, "Minus"]] },
        { section: "Media", label: "Stop media", keys: [[0, "XF86AudioStop"], [68, "Backspace"]] },
        { section: "Media", label: "Volume up", keys: [[0, "XF86AudioRaiseVolume"]] },
        { section: "Media", label: "Volume down", keys: [[0, "XF86AudioLowerVolume"]] },
        { section: "Media", label: "Mute / unmute speaker", keys: [[0, "XF86AudioMute"], [65, "M"]] },
        { section: "Media", label: "Mute / unmute microphone", keys: [[0, "XF86AudioMicMute"]] },
        { section: "Media", label: "Screen brightness up", keys: [[0, "XF86MonBrightnessUp"]] },
        { section: "Media", label: "Screen brightness down", keys: [[0, "XF86MonBrightnessDown"]] },

        // System
        { section: "System", label: "Caps Lock indicator", keys: [[0, "Caps_Lock"]] },
        { section: "System", label: "Num Lock indicator", keys: [[0, "Num_Lock"]] },
        { section: "System", label: "Toggle system monitor workspace", keys: [[5, "Escape"]] },
        { section: "System", label: "Suspend then hibernate", keys: [[65, "L"]] },
        { section: "System", label: "Send a test notification (debug)", keys: [[72, "F12"]] }
    ]

    function isGroupLive(g: var): bool {
        if (g.always)
            return true;
        if (g.digits) {
            for (let d = 0; d <= 9; d++) {
                if (root.liveKeySet[`${g.mod}:${d}`])
                    return true;
            }
            return false;
        }
        for (const pair of g.keys) {
            if (root.liveKeySet[`${pair[0]}:${pair[1].toLowerCase()}`])
                return true;
        }
        return false;
    }

    function oneKeyLabel(mod: int, key: string): string {
        const mods = root.modsLabel(mod);
        return mods === "(none)" ? root.prettyKey(key) : `${mods} + ${root.prettyKey(key)}`;
    }

    function groupKeyLabel(g: var): string {
        if (g.digits)
            return `${root.modsLabel(g.mod)} + 0-9`;
        return g.keys.map(pair => root.oneKeyLabel(pair[0], pair[1])).join("   /   ");
    }

    property var renderSections: root.buildSections(root.liveKeySet)

    function buildSections(liveSet: var): var {
        const bySection = {};
        for (const s of root.sectionOrder)
            bySection[s] = [];

        for (const g of root.groups) {
            if (root.isGroupLive(g))
                bySection[g.section].push({ label: g.label, keyLabel: root.groupKeyLabel(g) });
        }

        // Catch-all: any live bind the curated table above doesn't know about yet.
        const covered = {};
        for (const g of root.groups) {
            if (g.digits) {
                for (let d = 0; d <= 9; d++)
                    covered[`${g.mod}:${d}`] = true;
            } else {
                for (const pair of g.keys)
                    covered[`${pair[0]}:${pair[1].toLowerCase()}`] = true;
            }
        }
        const extra = [];
        for (const b of root.liveBinds) {
            const key = `${b.modmask}:${b.key.toLowerCase()}`;
            if (!covered[key])
                extra.push(root.oneKeyLabel(b.modmask, b.key));
        }
        if (extra.length)
            bySection["System"].push({ label: "Other active binds (not yet described here)", keyLabel: extra.join("   /   ") });

        return root.sectionOrder.map(s => ({ name: s, rows: bySection[s] }));
    }

    // ---- custom terminal commands (fish functions declared in home.nix) ----
    readonly property var terminalCommands: [
        { cmd: "rebuild", desc: "Switch to the flake config, then prune old generations" },
        { cmd: "save", desc: "Commit and push nixos-config" },
        { cmd: "gens", desc: "List system generations" },
        { cmd: "cfg", desc: "cd to nixos-config and launch claude" },
        { cmd: "/update", desc: "Run inside claude (after cfg) for safe system updates" }
    ]

    // ---- visuals ----
    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Qt.alpha(scheme.cScrim, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.visible = false
        }
    }

    Rectangle {
        id: sheet

        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 1600)
        height: Math.min(parent.height * 0.88, 1200)
        radius: 20
        color: Qt.alpha(scheme.cSurfaceContainer, 0.92)
        border.width: 1
        border.color: Qt.alpha(scheme.cOutlineVariant, 0.6)

        MouseArea {
            // Swallows clicks so they don't fall through to the scrim behind.
            anchors.fill: parent
        }

        // Plain anchors + Column/Row/Grid/Flow throughout below, not
        // QtQuick.Layouts: Quickshell's bundled QML runtime doesn't ship the
        // Layouts plugin (`import QtQuick.Layouts` silently "blackholes" -
        // every ColumnLayout/RowLayout/GridLayout then fails to instantiate
        // with no fatal error, leaving a correctly-sized but empty window).
        // Caelestia's own shell source never uses Layouts either, for the
        // same reason.
        FocusScope {
            id: focusScope

            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: root.visible = false

            Column {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                spacing: 2

                Text {
                    text: "Keybind Cheat Sheet"
                    font.family: "Rubik"
                    font.pixelSize: 22
                    font.bold: true
                    color: scheme.cOnSurface
                }

                Text {
                    text: "Generated live from hyprctl binds -j · Esc or Super+/ to close"
                    font.family: "Rubik"
                    font.pixelSize: 12
                    color: scheme.cOnSurfaceVariant
                }
            }

            Flickable {
                id: scrollArea

                anchors.top: header.bottom
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                contentWidth: width
                contentHeight: contentColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: contentColumn

                    readonly property real colWidth: (width - 32) / 3

                    width: scrollArea.width
                    spacing: 16

                    Grid {
                        width: parent.width
                        columns: 3
                        columnSpacing: 16
                        rowSpacing: 16

                        Repeater {
                            model: root.renderSections

                            delegate: Rectangle {
                                id: sectionCard

                                required property var modelData

                                width: contentColumn.colWidth
                                height: sectionColumn.height + 24
                                radius: 16
                                color: Qt.alpha(scheme.cSurfaceContainerHigh, 0.7)
                                border.width: 1
                                border.color: Qt.alpha(scheme.cOutlineVariant, 0.35)
                                visible: modelData.rows.length > 0

                                Column {
                                    id: sectionColumn

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    spacing: 6

                                    Text {
                                        text: sectionCard.modelData.name
                                        font.family: "Rubik"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: scheme.cPrimary
                                    }

                                    Repeater {
                                        model: sectionCard.modelData.rows

                                        delegate: Column {
                                            required property var modelData

                                            width: sectionColumn.width
                                            spacing: 1

                                            Text {
                                                width: parent.width
                                                text: modelData.keyLabel
                                                font.family: "CaskaydiaCove NF"
                                                font.pixelSize: 11
                                                color: scheme.cOnPrimaryContainer
                                                wrapMode: Text.WordWrap
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.label
                                                font.family: "Rubik"
                                                font.pixelSize: 12
                                                color: scheme.cOnSurface
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: termColumn.height + 24
                        radius: 16
                        color: Qt.alpha(scheme.cSurfaceContainerHigh, 0.7)
                        border.width: 1
                        border.color: Qt.alpha(scheme.cOutlineVariant, 0.35)

                        Column {
                            id: termColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: "Terminal Commands"
                                font.family: "Rubik"
                                font.pixelSize: 14
                                font.bold: true
                                color: scheme.cPrimary
                            }

                            Flow {
                                width: parent.width
                                spacing: 16

                                Repeater {
                                    model: root.terminalCommands

                                    delegate: Row {
                                        required property var modelData

                                        spacing: 8

                                        Rectangle {
                                            radius: 6
                                            color: Qt.alpha(scheme.cSecondaryContainer, 0.8)
                                            width: cmdText.implicitWidth + 12
                                            height: cmdText.implicitHeight + 6
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                id: cmdText

                                                anchors.centerIn: parent
                                                text: modelData.cmd
                                                font.family: "CaskaydiaCove NF"
                                                font.pixelSize: 12
                                                color: scheme.cOnSecondaryContainer
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.desc
                                            font.family: "Rubik"
                                            font.pixelSize: 12
                                            color: scheme.cOnSurface
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
