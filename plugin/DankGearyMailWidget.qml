import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // ---- settings (see DankGearyMailSettings.qml) ----
    property int refreshInterval: parseInt(pluginData.refreshInterval) || 2
    property string countMode: pluginData.countMode || "inbox"
    property bool hideWhenZero: pluginData.hideWhenZero ?? false
    property bool showPerAccount: pluginData.showPerAccount ?? false
    property string clickAction: pluginData.clickAction || "popout"
    property string launchCommand: pluginData.launchCommand || "flatpak run org.gnome.Geary"

    // ---- state ----
    property var accounts: []
    property int total: 0
    property bool gearyRunning: false
    property string lastError: ""
    property string lastUpdated: ""
    property bool loading: false
    property string scriptPath: Qt.resolvedUrl("geary-unread.py").toString().replace("file://", "")

    popoutWidth: 380
    conditionVisible: !(hideWhenZero && total === 0 && lastError === "")

    pillClickAction: clickAction === "launch" ? function () { root.openGeary() } : null
    pillRightClickAction: function () { root.openGeary() }

    onPluginServiceChanged: if (pluginService) refresh()
    onCountModeChanged: refresh()
    Component.onCompleted: refresh()

    Timer {
        interval: Math.max(1, root.refreshInterval) * 60000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    function openGeary() {
        Quickshell.execDetached(["sh", "-c", root.launchCommand])
    }

    function refresh() {
        if (loading) return
        loading = true
        fetchProcessComponent.createObject(root)
    }

    function pillText() {
        if (lastError !== "") return "!"
        if (showPerAccount && accounts.length > 1)
            return accounts.map(a => a.unread === null ? "?" : a.unread).join("·")
        return String(total)
    }

    function pillIcon() {
        if (lastError !== "") return "mail_lock"
        return total > 0 ? "mark_email_unread" : "mail"
    }

    function pillColor() {
        if (lastError !== "") return Theme.error
        if (!gearyRunning) return Theme.warning
        return total > 0 ? Theme.primary : Theme.surfaceVariantText
    }

    function formatTime(ts) {
        if (!ts) return ""
        const d = new Date(ts * 1000)
        const now = new Date()
        if (d.toDateString() === now.toDateString())
            return Qt.formatTime(d, "HH:mm")
        return Qt.formatDate(d, "MMM d")
    }

    property Component fetchProcessComponent: Component {
        Process {
            id: fetchProcess
            running: true
            command: ["python3", root.scriptPath, "--mode", root.countMode, "--recent", "5"]

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text)
                        root.accounts = data.accounts || []
                        root.total = data.total || 0
                        root.gearyRunning = !!data.gearyRunning
                        root.lastError = data.error || ""
                        root.lastUpdated = Qt.formatTime(new Date(), "HH:mm")
                    } catch (e) {
                        root.lastError = "bad output from geary-unread.py"
                        console.error("[DankGearyMail] parse failed:", e, text)
                    }
                    root.loading = false
                    fetchProcess.destroy()
                }
            }
            onExited: exitCode => {
                if (exitCode !== 0) {
                    console.warn("[DankGearyMail] geary-unread.py exited", exitCode)
                    root.loading = false
                }
            }
        }
    }

    // ---- bar pills ----
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.pillIcon()
                size: Theme.iconSize - 6
                color: root.pillColor()
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.pillText()
                visible: !(root.hideWhenZero && root.total === 0)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.total > 0 ? Theme.surfaceText : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.pillIcon()
                size: Theme.iconSize - 6
                color: root.pillColor()
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.showPerAccount ? String(root.total) : root.pillText()
                visible: !(root.hideWhenZero && root.total === 0)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.total > 0 ? Theme.surfaceText : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ---- popout ----
    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Mail"
            detailsText: {
                if (root.lastError !== "") return root.lastError
                if (!root.gearyRunning) return "Geary not running — counts may be stale"
                return root.total + " unread • updated " + root.lastUpdated
            }
            showCloseButton: true

            Component.onCompleted: root.refresh()

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: root.accounts

                    delegate: StyledRect {
                        id: accountRow
                        required property var modelData
                        property bool expanded: false

                        width: parent.width
                        height: accountColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: accountArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                        MouseArea {
                            id: accountArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: accountRow.expanded = !accountRow.expanded
                        }

                        Column {
                            id: accountColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: accountRow.modelData.error ? "error" : "account_circle"
                                    size: Theme.iconSize - 4
                                    color: accountRow.modelData.error ? Theme.error : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    width: parent.width - Theme.iconSize - badge.width - Theme.spacingS * 2
                                    text: accountRow.modelData.name
                                    elide: Text.ElideMiddle
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    id: badge
                                    width: Math.max(28, badgeText.implicitWidth + Theme.spacingM)
                                    height: 22
                                    radius: 11
                                    color: (accountRow.modelData.unread || 0) > 0 ? Theme.primary : Theme.surfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        id: badgeText
                                        anchors.centerIn: parent
                                        text: accountRow.modelData.unread === null ? "?" : String(accountRow.modelData.unread)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: (accountRow.modelData.unread || 0) > 0 ? Theme.primaryText : Theme.surfaceVariantText
                                    }
                                }
                            }

                            StyledText {
                                visible: !!accountRow.modelData.error
                                width: parent.width
                                text: accountRow.modelData.error || ""
                                wrapMode: Text.WordWrap
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.error
                            }

                            Column {
                                visible: accountRow.expanded && (accountRow.modelData.recent || []).length > 0
                                width: parent.width
                                spacing: Theme.spacingXS

                                Repeater {
                                    model: accountRow.modelData.recent || []

                                    delegate: Row {
                                        required property var modelData
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        Column {
                                            width: parent.width - timeText.width - Theme.spacingS
                                            StyledText {
                                                width: parent.width
                                                text: modelData.from || "(unknown)"
                                                elide: Text.ElideRight
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceText
                                            }
                                            StyledText {
                                                width: parent.width
                                                text: modelData.subject
                                                elide: Text.ElideRight
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }
                                        }

                                        StyledText {
                                            id: timeText
                                            text: root.formatTime(modelData.ts)
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    visible: root.accounts.length === 0
                    width: parent.width
                    text: root.loading ? "Loading…" : "No Geary accounts found"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    layoutDirection: Qt.RightToLeft

                    DankButton {
                        text: "Open Geary"
                        iconName: "open_in_new"
                        onClicked: {
                            root.openGeary()
                            popout.closePopout && popout.closePopout()
                        }
                    }

                    DankActionButton {
                        iconName: "refresh"
                        tooltipText: "Refresh"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.refresh()
                    }
                }
            }
        }
    }
}
