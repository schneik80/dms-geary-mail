import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankGearyMail"

    StyledText {
        width: parent.width
        text: "Geary Mail Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Shows unread counts for every account configured in Geary. Counts are read from Geary's local database, so Geary must be running (it can stay in the background) for them to stay current."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: countColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: countColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Counting"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            SelectionSetting {
                settingKey: "countMode"
                label: "Folders to count"
                description: "Inbox only, or every folder except Junk/Trash/Sent/Drafts/Archive"
                options: [
                    { label: "Inbox only", value: "inbox" },
                    { label: "All folders", value: "all" }
                ]
                defaultValue: "inbox"
            }

            StringSetting {
                settingKey: "refreshInterval"
                label: "Refresh interval (minutes)"
                description: "How often to re-read Geary's database"
                placeholder: "2"
                defaultValue: "2"
            }
        }
    }

    StyledRect {
        width: parent.width
        height: displayColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: displayColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Display"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "showPerAccount"
                label: "Per-account counts in bar"
                description: "Show 3·0·12 instead of the total"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "hideWhenZero"
                label: "Hide when nothing is unread"
                description: "Hide the widget from the bar when the count is zero"
                defaultValue: false
            }
        }
    }

    StyledRect {
        width: parent.width
        height: actionColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: actionColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Actions"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            SelectionSetting {
                settingKey: "clickAction"
                label: "Left click"
                description: "Right click always opens Geary"
                options: [
                    { label: "Open popout", value: "popout" },
                    { label: "Open Geary", value: "launch" }
                ]
                defaultValue: "popout"
            }

            StringSetting {
                settingKey: "launchCommand"
                label: "Launch command"
                description: "Use 'geary' for a native install"
                placeholder: "flatpak run org.gnome.Geary"
                defaultValue: "flatpak run org.gnome.Geary"
            }
        }
    }
}
