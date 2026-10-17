import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
// секции грузятся через Loader по URL — импорт нужен, чтобы quickshell просканировал home/
import qs.home
import "services/settings.js" as S

// Меню home — панель во всю высоту у края экрана: переключатели, звук, медиа, погода, календарь,
// уведомления, система, питание, Wi-Fi, bluetooth, действия. Состав и порядок секций — в настройках
// (Mod+S → home/), сами секции — home/<Name>.qml на базе home/Section.qml.
// Открывают клик по user@host, Mod+A, `qs ipc call home toggle` (services/Home.qml).
// Клавиши: ↑↓ / j k — элементы и секции, ←→ / h l — внутри строки, ↵ / Space — действие,
// Tab / ⇧Tab — следующая / предыдущая секция, Esc / q — закрыть.
Scope {
    id: root

    // окно живёт, пока доигрывает закрытие (Reveal.qml); slide — на всю ширину колонки
    Reveal {
        id: reveal
        open: Home.open
        style: Settings.get("shell.home.anim")
        duration: 180
        edge: Settings.get("shell.home.side")
    }

    LazyLoader {
        active: reveal.loaded

        PanelWindow {
            id: win

            readonly property bool right: Settings.get("shell.home.side") === "right"
            readonly property var ids: S.normalizeLayout(Settings.get("shell.home.layout"), "shell.home.layout").on

            // панель остаётся доступной: окно начинается под ней (или кончается над ней)
            readonly property bool barHere: !Settings.get("shell.bar.autohide")
                && (Settings.get("shell.bar.monitors") === "all" || screen === Quickshell.screens[0])
            readonly property bool barTop: Settings.get("shell.bar.position") === "top"
            readonly property int barSpace: !barHere ? 0
                : Theme.barHeight + (Settings.get("shell.bar.style") === "floating" ? 4 + 8 : 0)

            screen: Quickshell.screens.find(s => s.name === Home.screenName) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            margins { top: barTop ? barSpace : 0; bottom: barTop ? 0 : barSpace }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: Home.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "nopox-home"

            function close() { Home.open = false; }

            // ── фокус: какая секция, какой элемент в ней ──

            property int sec: -1

            function sectionAt(i) {
                const it = rep.itemAt(i)?.item;
                return it && it.available !== false && it.count > 0 ? it : null;
            }

            function indexOf(s) {
                for (let i = 0; i < rep.count; i++)
                    if (rep.itemAt(i)?.item === s) return i;
                return -1;
            }

            function setSection(i, fromEnd) {
                const prev = sectionAt(sec);
                if (prev) prev.focused = false;
                sec = i;
                const s = sectionAt(i);
                if (!s) return;
                if (fromEnd !== undefined) s.cur = fromEnd ? s.count - 1 : 0;
                s.cur = Math.max(0, Math.min(s.count - 1, s.cur));
                s.focused = true;
                ensureVisible(s);
            }

            function focusSection(s) {
                const i = indexOf(s);
                if (i >= 0) setSection(i);
                keys.forceActiveFocus();
            }

            // следующая (d = 1) или предыдущая секция с элементами; null — дальше некуда
            function neighbour(d) {
                for (let i = sec + d; i >= 0 && i < rep.count; i += d)
                    if (sectionAt(i)) return i;
                return null;
            }

            function move(d) {
                const s = sectionAt(sec);
                if (s && s.cur + d >= 0 && s.cur + d < s.count) {
                    s.cur += d;
                    ensureVisible(s);
                    return;
                }
                const n = neighbour(d);
                if (n !== null) setSection(n, d < 0);
            }

            function jump(d) {
                const n = neighbour(d);
                if (n !== null) setSection(n, false);
            }

            // секция целиком в видимой области, если влезает; иначе — её начало
            function ensureVisible(s) {
                const y = s.mapToItem(content, 0, 0).y;
                const h = s.height;
                if (y < flick.contentY) flick.contentY = y;
                else if (y + h > flick.contentY + flick.height)
                    flick.contentY = Math.min(y, y + h - flick.height);
            }

            // секции грузятся не сразу — фокус на первую, как только она появится
            Timer {
                interval: 50
                running: win.sec < 0
                repeat: true
                onTriggered: { const n = win.neighbour(1) ?? null; if (n !== null) win.setSection(n, false); }
            }

            // ширина символа — секциям для отступов и полосок
            readonly property alias cell: cellM

            TextMetrics {
                id: cellM
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }

            // клик мимо панели закрывает её
            MouseArea {
                anchors.fill: parent
                onClicked: win.close()
            }

            Rectangle {
                id: box

                width: cellM.advanceWidth * Settings.get("shell.home.width") + Theme.pad * 2
                anchors { top: parent.top; bottom: parent.bottom }
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2

                x: win.right ? parent.width - width : 0
                opacity: reveal.alpha
                scale: reveal.zoom
                transform: [
                    Translate { x: reveal.dx },
                    Scale { yScale: reveal.ys }
                ]

                Binding { target: reveal; property: "distance"; value: box.width }

                MouseArea { anchors.fill: parent }

                Rectangle {
                    x: Theme.pad
                    y: 0
                    z: 1
                    width: title.implicitWidth
                    height: title.implicitHeight
                    color: Theme.bg
                    T { id: title; text: "[ ~/home/" + Sys.user + "/ ]"; color: Theme.accent; font.bold: true }
                }

                Item {
                    id: keys
                    focus: true

                    Keys.onPressed: event => {
                        const k = event.key;
                        const s = win.sectionAt(win.sec);
                        const shift = event.modifiers & Qt.ShiftModifier;
                        if (s && s.key(event)) {
                            // секция обработала сама
                        } else if (k === Qt.Key_Escape || k === Qt.Key_Q) {
                            win.close();
                        } else if (k === Qt.Key_Down || k === Qt.Key_J) {
                            win.move(1);
                        } else if (k === Qt.Key_Up || k === Qt.Key_K) {
                            win.move(-1);
                        } else if (k === Qt.Key_Tab) {
                            win.jump(1);
                        } else if (k === Qt.Key_Backtab) {
                            win.jump(-1);
                        } else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && s) {
                            s.activate(s.cur);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }

                Flickable {
                    id: flick

                    anchors { fill: parent; margins: Theme.pad; topMargin: title.implicitHeight; bottomMargin: hints.implicitHeight + Theme.pad }
                    contentHeight: content.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Behavior on contentY { NumberAnimation { duration: 80 } }

                    ColumnLayout {
                        id: content
                        width: flick.width
                        spacing: 6

                        Repeater {
                            id: rep
                            model: win.ids

                            Loader {
                                required property string modelData
                                readonly property var info: S.moduleById(modelData, "shell.home.layout")

                                Layout.fillWidth: true
                                visible: item !== null && item.available !== false
                                Component.onCompleted: setSource(Qt.resolvedUrl("home/" + info.file + ".qml"), { panel: win })
                            }
                        }
                    }
                }

                T {
                    id: hints
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.pad }
                    textFormat: Text.StyledText
                    color: Theme.gray
                    elide: Text.ElideRight
                    text: [["↑↓", "выбор"], ["←→", "изменить"], ["↵", "действие"], ["⇥", "секция"], ["esc", "закрыть"]]
                        .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("  ")
                }
            }

            // колонка во всю высоту: построчно печать шла бы сверху вниз и почти не видна — все строки сразу, слева направо
            TypeOn {
                anchors.fill: parent
                source: box
                direction: "columns"
                p: reveal.p
                active: reveal.printing
            }
        }
    }
}
