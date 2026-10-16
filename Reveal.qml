import Quickshell
import QtQuick
import qs.services

// Появление и исчезновение окна shell: p идёт 0 → 1, пока open, и обратно, когда open снят.
// Стили (S.SHELL_ANIMS): slide — выезжает от edge, fade — проявляется, pop — вырастает из центра,
// unfold — разворачивается сверху вниз, type — печатается по символу из случайных знаков (рисует TypeOn.qml),
// none — без анимации.
// Для окна в LazyLoader Reveal живёт снаружи загрузчика: active: reveal.loaded держит окно, пока доигрывает
// закрытие. Окно привязывает к нему opacity, scale и transform:
//   opacity: rv.alpha; scale: rv.zoom
//   transform: [Translate { x: rv.dx; y: rv.dy }, Scale { yScale: rv.ys }]
Scope {
    id: rv

    property bool open: false
    property string style: "none"
    property int duration: 160
    property string edge: "top"       // откуда выезжает slide: left, right, top, bottom
    property real distance: 40        // на сколько px
    property real typeScale: 1.5      // печать (type) дольше остальных стилей: окно набирается по символу
    // общая скорость анимаций shell (look/ → анимации)
    readonly property real speed: Settings.get("shell.anim.speed")

    property real p: 0
    readonly property bool loaded: open || p > 0
    readonly property bool animated: style !== "none" && duration > 0
    // type: окно рисует TypeOn, пока печать не закончена
    readonly property bool printing: style === "type" && p < 1

    readonly property real alpha: style === "fade" || style === "pop" || style === "slide" ? p : 1
    readonly property real zoom: style === "pop" ? 0.92 + 0.08 * p : 1
    readonly property real ys: style === "unfold" ? Math.max(p, 0.001) : 1
    readonly property real shift: style === "slide" ? (1 - p) * distance : 0
    readonly property real dx: edge === "left" ? -shift : edge === "right" ? shift : 0
    readonly property real dy: edge === "top" ? -shift : edge === "bottom" ? shift : 0

    // p дошло до 0 после закрытия — можно убирать (уведомления так ждут конца анимации)
    signal hidden()

    onOpenChanged: run()
    Component.onCompleted: if (open) run()

    function run() {
        anim.stop();
        const to = open ? 1 : 0;
        if (!animated || p === to) {
            p = to;
            if (!open) hidden();
            return;
        }
        anim.from = p;
        anim.to = to;
        // прерванная на середине анимация доигрывает только остаток пути;
        // печать — ровным темпом и дольше: окно набирается по символу
        const type = style === "type";
        anim.duration = duration * (type ? typeScale : 1) * Math.abs(to - p) / Math.max(0.25, speed);
        anim.easing.type = type ? Easing.Linear : open ? Easing.OutCubic : Easing.InCubic;
        anim.start();
    }

    NumberAnimation {
        id: anim
        target: rv
        property: "p"
        onFinished: if (!rv.open) rv.hidden()
    }
}
