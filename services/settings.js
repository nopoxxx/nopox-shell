.pragma library

// Схема окна настроек и генерация ~/.config/niri/nopox.kdl.
//   niri.*      — уходят в конфиг niri
//   shell.*     — читает quickshell
//   wallpaper.* — хранится в сервисе Wallpaper

const ACCENTS = {
    yellow: "#fabd2f",
    orange: "#fe8019",
    green: "#b8bb26",
    aqua: "#8ec07c",
    blue: "#83a598",
    purple: "#d3869b",
    red: "#fb4934"
};

const WIDTHS = { "1/3": "0.33333", "1/2": "0.5", "2/3": "0.66667", "1": "1.0" };

// outputs: [{ name, scale, make, model, mode }] из `niri msg --json outputs`
function sections(outputs) {
    return [
        { id: "niri", rows: [
            { header: "клавиатура" },
            { key: "niri.kb.layout", label: "раскладки", type: "text", def: "us,ru", hint: "XKB-раскладки через запятую, например us,ru,ua" },
            { key: "niri.kb.options", label: "опции xkb", type: "text", def: "grp:alt_shift_toggle", hint: "например grp:win_space_toggle,ctrl:nocaps" },
            { key: "niri.kb.repeatDelay", label: "задержка повтора, мс", type: "int", min: 150, max: 1000, step: 25, def: 600 },
            { key: "niri.kb.repeatRate", label: "скорость повтора, /с", type: "int", min: 10, max: 80, step: 5, def: 25 },
            { key: "niri.kb.numlock", label: "numlock при входе", type: "bool", def: true },

            { header: "мышь и тачпад" },
            { key: "niri.tp.tap", label: "тап для клика", type: "bool", def: true, hint: "тачпад" },
            { key: "niri.tp.natural", label: "естественная прокрутка", type: "bool", def: true, hint: "тачпад" },
            { key: "niri.mouse.accel", label: "ускорение мыши", type: "float", min: -1, max: 1, step: 0.1, def: 0 },
            { key: "niri.mouse.profile", label: "профиль ускорения", type: "enum", options: ["adaptive", "flat"], def: "adaptive" },
            { key: "niri.ffm", label: "фокус следует за мышью", type: "bool", def: false },
            { key: "niri.warp", label: "курсор за фокусом", type: "bool", def: false, hint: "переносить курсор в окно, получившее фокус с клавиатуры" },

            { header: "окна" },
            { key: "niri.gaps", label: "отступы", type: "int", min: 0, max: 64, step: 2, def: 8 },
            { key: "niri.colWidth", label: "ширина новой колонки", type: "enum", options: ["1/3", "1/2", "2/3", "1"], def: "1/2" },
            { key: "niri.center", label: "центрировать колонку", type: "enum", options: ["never", "always", "on-overflow"], def: "never" },
            { key: "niri.ring", label: "рамка фокуса", type: "int", min: 0, max: 12, step: 1, def: 2, hint: "толщина в px, 0 — выключить; цвет — акцент из раздела shell" },
            { key: "niri.border", label: "обводка окон", type: "int", min: 0, max: 12, step: 1, def: 0, hint: "толщина в px, 0 — выключить" },
            { key: "niri.shadow", label: "тени", type: "bool", def: false },
            { key: "niri.csd", label: "без декораций приложений", type: "bool", def: true, hint: "prefer-no-csd: просить приложения не рисовать свои заголовки" },

            { header: "курсор" },
            { key: "niri.cursor.size", label: "размер", type: "int", min: 16, max: 64, step: 4, def: 24 },
            { key: "niri.cursor.hide", label: "прятать при наборе", type: "bool", def: false },

            { header: "анимации" },
            { key: "niri.anim", label: "включены", type: "bool", def: true },
            { key: "niri.anim.slowdown", label: "замедление", type: "float", min: 0.25, max: 3, step: 0.25, def: 1 },

            { header: "экраны" },
            ...outputs.map(o => ({
                key: "niri.out." + o.name + ".scale",
                label: o.name + " масштаб",
                type: "float", min: 0.5, max: 3, step: 0.25, def: o.scale,
                hint: [o.make, o.model, o.mode].filter(x => x).join(" ")
            }))
        ] },

        { id: "shell", rows: [
            { header: "оформление" },
            { key: "shell.accent", label: "акцентный цвет", type: "enum", options: Object.keys(ACCENTS), def: "yellow", hint: "рамки окон shell, prompt и рамка фокуса niri" },
            { key: "shell.fontSize", label: "размер шрифта", type: "int", min: 10, max: 28, step: 1, def: 16 },

            { header: "панель" },
            { key: "shell.bar.position", label: "положение", type: "enum", options: ["top", "bottom"], def: "top" },
            { key: "shell.bar.height", label: "высота", type: "int", min: 18, max: 48, step: 2, def: 26 },
            { key: "shell.bar.title", label: "активное окно", type: "bool", def: true, hint: "приложение и заголовок после ❯" },
            { key: "shell.bar.cpu", label: "загрузка cpu", type: "bool", def: true },
            { key: "shell.bar.mem", label: "память", type: "bool", def: true },
            { key: "shell.bar.layout", label: "раскладка", type: "bool", def: true },
            { key: "shell.bar.clock", label: "формат часов", type: "enum", options: ["HH:mm", "HH:mm:ss", "ddd HH:mm", "dd.MM HH:mm"], def: "HH:mm" },

            { header: "меню" },
            { key: "shell.launcher.rows", label: "строк в меню", type: "int", min: 6, max: 24, step: 1, def: 12 }
        ] },

        { id: "wallpaper", rows: [
            { header: "обои" },
            { key: "wallpaper.fill", label: "заполнение", type: "enum", options: ["fill", "fit", "stretch"], def: "fill", hint: "fill — обрезать, fit — вписать с полосами, stretch — растянуть" },
            { key: "wallpaper.picker", label: "выбрать обои", type: "action", hint: "открыть окно выбора (Mod+Shift+W)" }
        ] }
    ];
}

function find(key, outputs) {
    for (const s of sections(outputs))
        for (const r of s.rows)
            if (r.key === key) return r;
    return null;
}

function defaultOf(key, outputs) {
    return find(key, outputs)?.def;
}

// ── генерация KDL ──────────────────────────────────────────────────

const q = s => JSON.stringify(String(s));
const f = x => Number(x).toFixed(2);

// get(key) — значение с учётом умолчаний; outputScales — { имя: масштаб } только для изменённых
function niriKdl(get, outputScales) {
    const accent = ACCENTS[get("shell.accent")] ?? ACCENTS.yellow;
    const ring = get("niri.ring");
    const border = get("niri.border");

    const lines = [
        "// Сгенерировано окном настроек nopox (Mod+S) из ~/.config/nopox/settings.json.",
        "// Ручные правки здесь перезапишутся — свои настройки пишите в config.kdl.",
        "",
        "input {",
        "    keyboard {",
        "        xkb {",
        "            layout " + q(get("niri.kb.layout")),
        "            options " + q(get("niri.kb.options")),
        "        }",
        "        repeat-delay " + get("niri.kb.repeatDelay"),
        "        repeat-rate " + get("niri.kb.repeatRate"),
        get("niri.kb.numlock") ? "        numlock" : null,
        "    }",
        "    touchpad {",
        get("niri.tp.tap") ? "        tap" : null,
        get("niri.tp.natural") ? "        natural-scroll" : null,
        "    }",
        "    mouse {",
        "        accel-speed " + f(get("niri.mouse.accel")),
        "        accel-profile " + q(get("niri.mouse.profile")),
        "    }",
        get("niri.ffm") ? "    focus-follows-mouse" : null,
        get("niri.warp") ? "    warp-mouse-to-focus" : null,
        "}",
        "",
        "layout {",
        "    // прозрачный фон: под рабочими столами видны обои quickshell",
        '    background-color "transparent"',
        "    gaps " + get("niri.gaps"),
        "    center-focused-column " + q(get("niri.center")),
        "    preset-column-widths {",
        "        proportion 0.33333",
        "        proportion 0.5",
        "        proportion 0.66667",
        "    }",
        "    default-column-width { proportion " + WIDTHS[get("niri.colWidth")] + "; }",
        "    focus-ring {",
        ...(ring > 0
            ? ["        width " + ring, "        active-color " + q(accent), '        inactive-color "#504945"']
            : ["        off"]),
        "    }",
        "    border {",
        ...(border > 0
            ? ["        width " + border, "        active-color " + q(accent), '        inactive-color "#504945"', '        urgent-color "#fb4934"']
            : ["        off"]),
        "    }",
        "    shadow {",
        get("niri.shadow") ? "        on" : null,
        "        softness 30",
        "        spread 5",
        "        offset x=0 y=5",
        '        color "#0007"',
        "    }",
        "}",
        "",
        "cursor {",
        "    xcursor-size " + get("niri.cursor.size"),
        get("niri.cursor.hide") ? "    hide-when-typing" : null,
        "}",
        "",
        "prefer-no-csd " + (get("niri.csd") ? "true" : "false"),
        "",
        "animations {",
        get("niri.anim") ? null : "    off",
        "    slowdown " + f(get("niri.anim.slowdown")),
        "}"
    ];

    for (const name in outputScales)
        lines.push("", "output " + q(name) + " {", "    scale " + f(outputScales[name]), "}");

    return lines.filter(l => l !== null).join("\n") + "\n";
}
