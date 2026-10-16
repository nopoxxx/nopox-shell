import QtQuick
import qs
import qs.bar
import qs.services

// en / ru — клик: следующая раскладка
Seg {
    available: Niri.layout !== ""
    value: Niri.layout
    valueColor: Theme.purple
    onLeftClicked: Niri.action("switch-layout", "next")
    scrollable: true
    onScrolled: dir => Niri.action("switch-layout", dir > 0 ? "prev" : "next")
}
