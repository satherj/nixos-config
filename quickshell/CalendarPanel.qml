import QtQuick
import QtQuick.Layouts
import Quickshell

// Month calendar under the clock. Weeks start on Monday; ISO week numbers on the left.
// Scroll or ‹ › to change month.
ColumnLayout {
    id: root

    spacing: 10

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property date today: clock.date
    property int year: today.getFullYear()
    property int month: today.getMonth()
    readonly property bool isCurrentMonth: year === today.getFullYear() && month === today.getMonth()

    function shift(n) {
        const d = new Date(year, month + n, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }
    // 6 weeks x 7 days starting on the Monday on/before the 1st
    readonly property var days: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() + 6) % 7;
        return Array.from({ length: 42 }, (_, i) => new Date(year, month, 1 - offset + i));
    }

    // Big date
    ColumnLayout {
        spacing: 0
        StyledText {
            text: Qt.formatDateTime(root.today, "dddd")
            color: Theme.blue
            font.pixelSize: 13
        }
        StyledText {
            text: Qt.formatDateTime(root.today, "d MMMM yyyy")
            font.pixelSize: 22
            font.bold: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.surface0
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText {
            Layout.fillWidth: true
            text: Qt.formatDateTime(new Date(root.year, root.month, 1), "MMMM yyyy")
            font.bold: true
        }
        IconButton {
            visible: !root.isCurrentMonth
            text: "Today"
            onClicked: {
                root.year = root.today.getFullYear();
                root.month = root.today.getMonth();
            }
        }
        IconButton { text: "󰅁"; onClicked: root.shift(-1) }
        IconButton { text: "󰅂"; onClicked: root.shift(1) }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 8
        columnSpacing: 2
        rowSpacing: 2

        // Header: week-number column + weekdays
        StyledText {
            text: "wk"
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignHCenter
            color: Theme.surface2
            font.pixelSize: 10
        }
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            StyledText {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index >= 5 ? Theme.overlay0 : Theme.subtext0
                font.pixelSize: 11
            }
        }

        Repeater {
            model: 48

                Item {
                    required property int index
                    readonly property int row: Math.floor(index / 8)
                    readonly property int col: index % 8
                    readonly property var day: col === 0 ? null : root.days[row * 7 + col - 1]
                    readonly property bool inMonth: day !== null && day.getMonth() === root.month
                    readonly property bool isToday: day !== null && day.toDateString() === root.today.toDateString()
                    Layout.fillWidth: true
                    implicitWidth: 36
                    implicitHeight: 34

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: 15
                        color: parent.isToday ? Theme.blue : "transparent"
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: parent.day === null ? root.isoWeek(root.days[parent.row * 7]) : parent.day.getDate()
                        font.pixelSize: parent.day === null ? 10 : 12
                        font.bold: parent.isToday
                        color: parent.day === null ? Theme.surface2
                            : parent.isToday ? Theme.base
                            : !parent.inMonth ? Theme.surface2
                            : parent.col >= 6 ? Theme.overlay0 : Theme.text
                    }
                }
        }
    }

    // Scroll anywhere on the calendar to change month
    WheelHandler {
        onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1)
    }
}
