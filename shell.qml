//@ pragma UseQApplication

// =========================================================================
// IMPORTS & MODULES
// Core QML modules and Quickshell bindings for hardware and desktop integration.
// =========================================================================
import Quickshell
import Quickshell.Hyprland            // Links up directly to the Hyprland Window Manager
import QtQuick                        // Core engine for elements, shapes, and animations
import QtQuick.Layouts                // Automatic positioning frameworks (RowLayout, ColumnLayout)
import Quickshell.Wayland             // Handles desktop layers and screen edge anchors
import Quickshell.Io                  // Needed for background system process tracking
import Quickshell.Services.SystemTray // Fetches running status tray applications
import Quickshell.Services.Mpris      // Handles media player states and metadata
import Quickshell.Services.UPower     // Interface for battery and system power tracking

// =========================================================================
// ROOT CONFIGURATION
// Entry point for the Quickshell environment. Holds global variables, backend logic, and global popups.
// =========================================================================
ShellRoot {
    FontLoader {
    id: datatypeFont
    source: "file:///home/astena/.local/share/fonts/Datatype-VariableFont_wdth,wght.ttf"
    // Or place the .ttf in your QML folder and use a relative path:
    // source: "./Datatype-VariableFont_wdth,wght.ttf"
    }
    // Global toggle states and metadata parsers used across windows
    Component.onCompleted: {
        console.log("players count:", Mpris.players.values.length)
    }
    property var mpris: {
        const players = Mpris.players.values.filter(p => !p.dbusName.includes("skwd"))
        return players.length > 0 ? players[0] : null
    }
    property bool dashboardOpen: false
    property bool launcherOpen: false
    property bool batteryPopupOpen: false

    // Floating overlay window showing detailed battery stats (charging time, power draw)
    PopupWindow {
        id: batteryPopup
        visible: batteryPopupOpen

        anchor.item: batteryText    // Anchors directly to the battery text readout
        anchor.edges: Edges.Top     // Attaches to the top edge of batteryText
        anchor.gravity: Edges.Top   // Expands upward from the anchor point

        implicitWidth: batteryPopUpActual.width + 55
        implicitHeight: batteryPopUpActual.height + 30

        Rectangle {
            id: batteryPopUpActual
            anchors.fill: parent
            color: Colors.colSurface
            radius: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                // Charging state label
                Text {
                    text: {
                        const state = UPower.displayDevice.state
                        if (state === UPowerDeviceState.Charging) return "⚡ Charging"
                        if (state === UPowerDeviceState.Discharging) return "🔋 Discharging"
                        return "✓ Full"
                    }
                    color: Colors.colOnSurface
                    font { family: "Faculty Glyphic"; pixelSize: 15 }
                }

                // Estimated time to full or empty
                Text {
                    text: {
                        const state = UPower.displayDevice.state
                        const secs = state === UPowerDeviceState.Charging
                            ? UPower.displayDevice.timeToFull
                            : UPower.displayDevice.timeToEmpty
                        if (!secs || secs <= 0) return "Calculating..."
                        const h = Math.floor(secs / 3600)
                        const m = Math.floor((secs % 3600) / 60)
                        const label = state === UPowerDeviceState.Charging ? "until full" : "remaining"
                        return h > 0 ? `${h}h ${m}m ${label}` : `${m}m ${label}`
                    }
                    color: Colors.colOnSurfaceVariant
                    font { family: "Faculty Glyphic"; pixelSize: 12 }
                }

                // Real-time power usage readout
                Text {
                    text: UPower.displayDevice.energyRate.toFixed(1) + "W draw"
                    color: Colors.colOnSurfaceVariant
                    font { family: "Faculty Glyphic"; pixelSize: 12 }
                }
            }
        }

        // Closes popup when clicking outside
        MouseArea {
            parent: batteryPopup
            anchors.fill: parent
            onClicked: batteryPopupOpen = false
        }
    }

    // Listens for external triggers (e.g. keybinds) to toggle the launcher
    IpcHandler {
        target: "launcher"
        
        function toggle(): void {
            launcherOpen = !launcherOpen
            if (!launcherOpen) searchInput.text = ""
        }
        
        function open(): void {
            launcherOpen = true
        }
        
        function close(): void {
            launcherOpen = false
            searchInput.text = ""
        }
    }

    // Process handler for running shell commands asynchronously
    Process {
        id: setFanLevel
    }

    // Backend clock engine tracking current time
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // =========================================================================
    // WINDOW 1: THE BOTTOM STATUS BAR
    // Panel window pinned to the bottom screen edge holding all main bar widgets.
    // =========================================================================
    PanelWindow {
        id: barWindow
        
        anchors { 
            bottom: true
            left: true
            right: true 
        }
        
        implicitHeight: dashboardOpen ? 340 : 40
        exclusiveZone: 40
        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"

        // ---------------------------------------------------------------------
        // LEFT ISLAND: SYSTEM TRAY
        // Displays active background app icons with left/right click controls.
        // ---------------------------------------------------------------------
        Rectangle {
            id: leftIsland
            anchors { 
                left: parent.left
                bottom: parent.bottom
                margins: 0 
            }
            height: 30
            implicitWidth: trayRow.implicitWidth + 16
            color: Colors.colSurface
            radius: 0

            RowLayout {
                id: trayRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        width: 20
                        height: 20

                        Image {
                            anchors.fill: parent
                            source: modelData.icon
                            smooth: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    modelData.display(barWindow, x, y)
                                } else {
                                    modelData.activate()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // CENTER ISLAND: CLOCK & DASHBOARD TOGGLE
        // Pinned clock bar that expands into the main dashboard panel on click.
        // ---------------------------------------------------------------------
        Rectangle {
            id: centerIsland
            anchors { 
                horizontalCenter: parent.horizontalCenter
            }
            MouseArea {
                anchors.fill: parent 
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    dashboardOpen = !dashboardOpen
                }
            }
            
            implicitHeight: dashboardOpen ? 340 : 40 
            y: dashboardOpen ? (barWindow.height - 340) : (barWindow.height - 40)
            
            Behavior on y {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            
            color: Colors.colSurface
            
            implicitWidth: dashboardOpen ? 600 : (clockText.implicitWidth + 24)
            Behavior on implicitWidth {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            // ---------------------------------------------------------------------
            // DASHBOARD CONTENT SUBTREE
            // Inner layout containing system controls, player widgets, buttons, and fan options.
            // ---------------------------------------------------------------------
            Item {
                id: dashboardContent
                anchors {
                    top: parent.top 
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 16
                    topMargin: 16
                }
                
                visible: dashboardOpen 
                opacity: dashboardOpen ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    spacing: 6

                    // --- COLUMN 1: SYSTEM CONTROLS & MEDIA PLAYER ---
                    ColumnLayout {
                        Layout.fillHeight: true  
                        
                        // Power profiles selector
                        Rectangle {
                            id: powerProfiles
                            Layout.preferredWidth: 284
                            Layout.preferredHeight: 50
                            radius: 0
                            color: Colors.colSurfaceVariant

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 0

                                Repeater {
                                    model: [
                                        { profile: PowerProfile.PowerSaver, label: "Saver" },
                                        { profile: PowerProfile.Balanced, label: "Balanced" },
                                        { profile: PowerProfile.Performance, label: "Perf" }
                                    ]

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 0
                                        color: PowerProfiles.profile === modelData.profile ? Colors.colPrimary : Colors.colSurface

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: PowerProfiles.profile === modelData.profile ? Colors.colOnPrimary : Colors.colOnSurfaceVariant
                                            font { family: "Faculty Glyphic"; pixelSize: 12 }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: PowerProfiles.profile = modelData.profile
                                        }
                                    }
                                }
                            }
                        }

                        // Active media player display and track position bar
                        Rectangle {
                            id: musicContent
                            Layout.preferredWidth: 284
                            Layout.preferredHeight: 260
                            Component.onCompleted: {
                                if (mpris) {
                                    console.log("metadata:", JSON.stringify(mpris.metadata))
                                    console.log("art:", mpris.metadata["mpris:artUrl"])
                                } else {
                                    console.log("no active player")
                                }
                            }
                            Timer {
                                interval: 1000
                                running: mpris && mpris.playbackState === MprisPlaybackState.Playing
                                repeat: true
                                onTriggered: mpris.positionChanged()
                            }

                            color: Colors.colSurfaceVariant
                            ColumnLayout {
                                Layout.preferredWidth: 284
                                Layout.preferredHeight: 238
                                spacing: 8
                                anchors.margins: 16

                                Image {
                                    Layout.preferredWidth: 149
                                    Layout.preferredHeight: 149
                                    fillMode: Image.PreserveAspectCrop
                                    source: mpris && mpris.metadata && mpris.metadata["mpris:artUrl"] ? mpris.metadata["mpris:artUrl"] : ""
                                }

                                Rectangle {
                                    id: progressTrack
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 6
                                    Layout.topMargin: 5
                                    radius: 0
                                    color: Colors.colSurface

                                    Rectangle {
                                        height: parent.height
                                        radius: 0
                                        color: Colors.colPrimary
                                        width: (mpris && mpris.length > 0) ? parent.width * (mpris.position / mpris.length) : 0   
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: (mouse) => {
                                            if (mpris && mpris.length > 0 && mpris.canSeek) {
                                                const fraction = mouse.x / progressTrack.width
                                                mpris.position = fraction * mpris.length
                                            }
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 270
                                    Layout.topMargin: 2
                                    text: mpris ? (mpris.trackTitle || "No track") : "No player"
                                    color: Colors.colOnSurface
                                    font { family: "SpaceMono Nerd Font Propo"; pixelSize: 20 }
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: -10
                                    Layout.maximumWidth: 270
                                    text: mpris ? (mpris.trackArtist || "") : ""
                                    color: Colors.colOnSurfaceVariant
                                    font { family: "SpaceMono Nerd Font Propo"; pixelSize: 15 }
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                    
                    // --- COLUMN 2: UTILITIES & SYSTEM BUTTONS ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Quick system command action buttons
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Layout.preferredHeight: 64

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 0
                                color: Colors.colSurfaceVariant
                                Text { anchors.centerIn: parent; text: "OCR"; color: Colors.colOnSurface }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        Quickshell.execDetached(["omarchy-cmd-ocr"])
                                        dashboardOpen = false   
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 0
                                color: Colors.colSurfaceVariant
                                Text { anchors.centerIn: parent; text: "BT"; color: Colors.colOnSurface }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        Quickshell.execDetached(["adw-bluetooth"])
                                        dashboardOpen = false   
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 0
                                color: Colors.colSurfaceVariant
                                Text { anchors.centerIn: parent; text: "Sleep"; color: Colors.colOnSurface }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        Quickshell.execDetached(["systemctl", "sleep"])
                                        dashboardOpen = false   
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 0
                                color: Colors.colSurfaceVariant
                                Text { anchors.centerIn: parent; text: "Lock"; color: Colors.colOnSurface }
                                MouseArea { 
                                    anchors.fill: parent 
                                    onClicked:{
                                        Quickshell.execDetached(["/home/reva/.local/share/quickshell-lockscreen/lock.sh"])
                                        dashboardOpen = false
                                    }
                                }
                            }
                        }

                        // Hardware fan speed controller selector
                        Rectangle {
                            id: fanSpeed
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 0
                            color: Colors.colSurfaceVariant

                            property var fanLevels: ["0", "1", "2", "3", "4", "5", "6", "7", "auto", "disengaged", "full-speed"]
                            property int currentLevelIndex: 8   

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                Text {
                                    text: "Fan: " + fanSpeed.fanLevels[fanSpeed.currentLevelIndex]
                                    color: Colors.colOnSurface
                                    font { family: "Faculty Glyphic"; pixelSize: 13 }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Repeater {
                                        model: fanSpeed.fanLevels.length

                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 20
                                            radius: 0
                                            color: index === fanSpeed.currentLevelIndex ? Colors.colPrimary : Colors.colSurface

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    fanSpeed.currentLevelIndex = index
                                                    setFanLevel.command = ["sh", "-c", "echo level " + fanSpeed.fanLevels[index] + " | sudo tee /proc/acpi/ibm/fan"]
                                                    setFanLevel.running = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Placeholder container box
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 0
                        color: Colors.colSurfaceVariant

                        ColumnLayout {
                            id: sysRoot
                            spacing: 0
                            Layout.fillWidth: true

                            property string topProcess: "..."
                            property string temps: "..."
                            property string ramUsage: "..."

                            // 1. Poll the shell process
                            Timer {
                                interval: 2000
                                running: true
                                repeat: true
                                triggeredOnStart: true
                                onTriggered: sysProc.running = true
                            }

                            Process {
                                id: sysProc

                                // Automatically restart the process when it exits so it's ready for the next tick
                                onRunningChanged: {
                                    if (!running) {
                                        // Preps process state
                                    }
                                }

                                command: [
                                    "sh", "-c",
                                    // Top CPU process using top (gets line 8, compresses spaces, grabs process name and %CPU)
                                    "TOP_NAME=$(top -b -n 1 -w 512 -c -o %CPU | awk 'NR>7 {print $12; exit}'); " +
                                    "TOP_CPU=$(ps -eo %cpu --sort=-%cpu | head -n 2 | tail -n 1); " +
                                    "TOP=\"$TOP_NAME$TOP_CPU%\"; " +
                                    
                                    // CPU Temp fallback directly from thermal zone (millidegrees to °C in bash)
                                    "RAW_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null); " +
                                    "CPUTEMP=$((RAW_TEMP / 1000))°C; " +
                                    
                                    // RAM usage using 'free -h' and cut
                                    "RAM_USED=$(free -h | grep Mem: | tr -s ' ' | cut -d' ' -f3); " +
                                    "RAM_TOTAL=$(free -h | grep Mem: | tr -s ' ' | cut -d' ' -f2); " +
                                    "RAM=\"$RAM_USED / $RAM_TOTAL\"; " +
                                    
                                    "echo \"$TOP|$CPUTEMP |$RAM\""
                                ]

                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        // In Quickshell, 'text' is explicitly available on the StdioCollector instance
                                        if (!text || text.trim() === "") return;
                                        var parts = text.trim().split("|");
                                        if (parts.length === 3) {
                                            sysRoot.topProcess = parts[0] || "N/A";
                                            sysRoot.temps = parts[1] || "N/A";
                                            sysRoot.ramUsage = parts[2] || "N/A";
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Image {
                                    source: "/home/astena/Downloads/8fc2ffd6ede623dca5833392c62aa494.jpg"
                                    clip: true
                                    fillMode: Image.Stretch
                                    Layout.preferredHeight: 116
                                    Layout.preferredWidth: 116
                                }

                                ColumnLayout {
                                    spacing: 0

                                    Text {
                                        text: "astena"
                                        font.family: "DM Mono"
                                        font.pixelSize: 25
                                        font.weight: 900
                                        color: Colors.colPrimary
                                    }

                                    Text {
                                        text: "🔲: " + sysRoot.topProcess
                                        font.pixelSize: 13
                                        color: Colors.colOnSurfaceVariant
                                        font.family: "Adwaita Sans"
                                        font.italic: true
                                         
                                    }

                                    Text {
                                        text: "🌡: " + sysRoot.temps
                                        font.pixelSize: 13
                                        color: Colors.colOnSurfaceVariant
                                        font.family: "Adwaita Sans"
                                        font.italic: true
                                         
                                    }

                                    Text {
                                        text: "🐏: " + sysRoot.ramUsage
                                        font.pixelSize: 13
                                        font.family: "Adwaita Sans"
                                        font.italic: true
                                         
                                        color: Colors.colOnSurfaceVariant
                                    }
                                }
                            }

                            Image {
                                source: "/home/astena/Downloads/baeae7f730e8053c37cf7445cbb04e0e.webp.jpg"
                                fillMode: Image.PreserveAspectCrop
                                Layout.preferredHeight: 60
                                Layout.preferredWidth: 277
                                clip: true
                            }
                        }
                    }
                    }
                }
            }
            
            // Format rendering targets mapping SystemClock time down to text strings
            Text {
                id: clockText
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 10 
                }
                
                text: Qt.formatDateTime(clock.date, "hh:mm:ss")
                font {
                    family: "Faculty Glyphic"
                    pixelSize: 15
                    weight: 100
                }
                color: dashboardOpen ? "transparent" : Colors.colOnSurface
            }
        }

        // ---------------------------------------------------------------------
        // RIGHT ISLAND: BATTERY READOUT & WORKSPACE MONITOR
        // Shows battery status (right click for popup) and workspace switches.
        // ---------------------------------------------------------------------
        Rectangle {
            id: rightIsland
            anchors { 
                right: parent.right
                bottom: parent.bottom
                margins: 0 
            }
            implicitWidth: rightRow.implicitWidth + 16
            height: 35
            color: Colors.colSurface
            property var wsRange: []
            function refreshWorkspaces() {
                wsProc.running = true
            }
            RowLayout {
                anchors.fill: parent
                id: rightRow
                anchors.margins: 6
                Process {
                    id: wsProc
                    command: ["hyprctl", "workspaces", "-j"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            var wss = JSON.parse(text)
                            var ids = []
                            for (var i = 0; i < wss.length; i++) {
                                if (wss[i].id > 0)
                                    ids.push(wss[i].id)
                            }

                            var focused = Hyprland.focusedWorkspace?.id
                            if (focused && focused > 0 && ids.indexOf(focused) === -1)
                                ids.push(focused)

                            ids.sort(function(a, b) { return a - b })
                            rightIsland.wsRange = ids
                        }
                    }
                }

                Connections {
                    target: Hyprland
                    function onRawEvent(event) {
                        var n = event.name
                        if (n === "workspace" || n === "createworkspace" || n === "destroyworkspace"
                            || n === "workspacev2" || n === "createworkspacev2" || n === "destroyworkspacev2")
                            rightIsland.refreshWorkspaces()
                    }
                }

                Component.onCompleted: refreshWorkspaces()
                
                // Battery status indicator; right-click toggles batteryPopup
                Text {
                    id: batteryText
                    text: {
                        const pct = Math.round(UPower.displayDevice.percentage * 100) + "%"
                        const charging = UPower.displayDevice.state === UPowerDeviceState.Charging
                        return charging ? "⚡ " + pct : pct
                    }
                    color: UPower.displayDevice.percentage * 100 < 20 ? "#ff5555" : Colors.colOnSurfaceVariant
                    font { family: "Space Mono Nerd Font Mono"; pixelSize: 15 }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton)
                                batteryPopupOpen = !batteryPopupOpen
                        }
                    }
                }
                
                // Workspace switcher mapping active windows to Hyprland IDs
                Repeater {
                    model: rightIsland.wsRange

                    Rectangle {
                        id: dot
                        required property int modelData
                        property bool isActive: Hyprland.focusedWorkspace?.id === modelData

                        Layout.preferredWidth: isActive ? 20 : 8
                        Layout.preferredHeight: 8
                        radius: 0
                        color: isActive ? Colors.colPrimary : Colors.colOnSurfaceVariant

                        Behavior on Layout.preferredWidth {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6   // bigger hit target than the tiny dot
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch(`workspace ${dot.modelData}`)
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // WINDOW 2: APPLICATION LAUNCHER
    // Pulls down an interactive screen layer running a filtered app search.
    // =========================================================================
    PanelWindow {
        id: launcherWindow
        anchors { top: true }
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        
        implicitWidth: 600
        implicitHeight: (launcherOpen || launcherContent.y > -410) ? 400 : 0
        visible: launcherOpen || launcherContent.y > -400
        color: "transparent"

        Rectangle {
            id: launcherContent
            anchors.left: parent.left
            anchors.right: parent.right
            width: parent.width
            height: parent.height
            radius: 0
            color: Colors.colSurface
            y: launcherOpen ? 0 : -400
            
            Behavior on y {
                NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
            }

            // Input field search box
            Rectangle {
                id: searchBox
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 16
                }
                height: 40
                color: Colors.colSurfaceVariant
                
                TextInput {
                    id: searchInput
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                        topMargin: 9
                    }
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.colOnSurfaceVariant
                    font { 
                        family: "Space Mono Nerd Font Propo"
                        pixelSize: 15
                    }
                    clip: true 
                    focus: launcherOpen
                    
                    onVisibleChanged: {
                        if (launcherOpen) {
                            forceActiveFocus() 
                        }
                    }
                    
                    // Keyboard navigation mapping for the app list
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Down) {
                            appList.incrementCurrentIndex()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            appList.decrementCurrentIndex()
                            event.accepted = true
                        }
                    }

                    Keys.onReturnPressed: (event) => {
                        if (appList.currentItem) {
                            appList.currentItem.executeApp()
                            launcherOpen = false
                            searchInput.text = ""
                            appList.currentIndex = -1
                        }
                    }

                    Keys.onEscapePressed: {
                        launcherOpen = false
                        searchInput.text = ""
                        appList.currentIndex = 0
                    }
                }
            }

            // Dynamically sorts and filters system application desktop entries
            ScriptModel {
                id: filtered
                values: {
                    const allEntries = [...DesktopEntries.applications.values]
                        .filter(d => d.name)
                        .sort((a, b) => a.name.localeCompare(b.name))

                    const q = searchInput.text.trim().toLowerCase()
                    if (q === "") return allEntries

                    return allEntries.filter(d => {
                        const name = (d.name || "").toLowerCase()
                        return name.includes(q)
                    })
                }
            }

            // Scrollable view rendering matching search results
            ListView {
                id: appList
                anchors {
                    top: searchBox.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 16
                    topMargin: 8
                }
                model: filtered
                clip: true
                spacing: 4

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 36
                    radius: 0
                    
                    color: ListView.isCurrentItem ? Colors.colPrimary : Colors.colSurface
                    
                    function executeApp() {
                        modelData.execute()
                    }

                    Image {
                        id: appIcon
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        width: 22
                        height: 22
                        source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                        visible: modelData.icon !== ""
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 34
                        text: modelData.name
                        color: ListView.isCurrentItem ? "#000000" : Colors.colOnSurface
                        font { 
                            family: "Faculty Glyphic"
                            pixelSize: 14 
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modelData.execute() 
                            launcherOpen = false
                            searchInput.text = ""
                        }
                    }
                }
            }
        }
    }
}