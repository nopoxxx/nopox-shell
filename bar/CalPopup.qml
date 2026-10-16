import QtQuick
import QtQuick.Layouts
import qs
import qs.bar

// Календарь под часами — CalGrid в TUI-рамке
TuiPopup {
    id: pop

    title: "cal"

    onOpenChanged: if (open) grid.today()

    CalGrid { id: grid }
}
