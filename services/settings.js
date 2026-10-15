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

// ── модули панели ──────────────────────────────────────────────────
// file — bar/<file>.qml; inline — часть prompt: между двумя inline-модулями пробел, а не разделитель

const MODULES = [
    { id: "user", file: "User", inline: true, desc: "user@host — стиль в shell/ → prompt" },
    { id: "workspaces", file: "Workspaces", inline: true, desc: "~/ws/{1,[2],3}: клик — перейти, колёсико — листать" },
    { id: "jobs", file: "Jobs", inline: true, desc: "[3] — число окон на текущем столе" },
    { id: "command", file: "Command", inline: true, desc: "❯ активное окно как набранная команда" },
    { id: "media", file: "Media", desc: "♪ плеер: клик — пауза, правый — следующий, средний — предыдущий" },
    { id: "tray", file: "Tray", desc: "[трей] текстом: клик — открыть, правый — меню" },
    { id: "cpu", file: "Cpu", desc: "загрузка cpu, клик — процессы" },
    { id: "mem", file: "Mem", desc: "память, клик — процессы" },
    { id: "gpu", file: "Gpu", desc: "загрузка и температура amdgpu" },
    { id: "temp", file: "Temp", desc: "температура cpu (k10temp / coretemp)" },
    { id: "netspeed", file: "NetSpeed", desc: "скорость сети ↓↑" },
    { id: "net", file: "Net", desc: "сеть: eth / wifi / offline, клик — nmtui" },
    { id: "vol", file: "Vol", desc: "громкость: колёсико, клик — микшер, правый — mute" },
    { id: "bat", file: "Bat", desc: "батарея — видна только на ноутбуках" },
    { id: "updates", file: "Upd", desc: "обновления: клик — paru -Syu, правый — проверить" },
    { id: "shellupd", file: "ShellUpd", desc: "nopox ↑3 — обновления nopox-shell с GitHub: клик — список и [обновить]" },
    { id: "notify", file: "Notify", desc: "уведомления: клик — история, правый — «не беспокоить»" },
    { id: "kbd", file: "Kbd", desc: "раскладка, клик — переключить" },
    { id: "clock", file: "Clock", desc: "часы, клик — календарь" }
];

const ZONES = ["left", "center", "right", "off"];

const DEFAULT_LAYOUT = {
    left: ["user", "workspaces", "jobs", "command"],
    center: [],
    right: ["media", "tray", "cpu", "mem", "net", "vol", "bat", "shellupd", "updates", "notify", "kbd", "clock"]
};

function moduleById(id) {
    return MODULES.find(m => m.id === id) ?? null;
}

// убирает неизвестные и повторяющиеся id.
// off хранится явно: модуль, которого нет ни в одной зоне и ни в off, — новый (появился после обновления)
// и встаёт в свою зону по умолчанию, а не пропадает в «выключенных».
function normalizeLayout(l) {
    const src = l ?? DEFAULT_LAYOUT;
    const seen = new Set();
    const out = { left: [], center: [], right: [], off: [] };
    for (const z of ZONES)
        for (const id of src[z] ?? [])
            if (moduleById(id) && !seen.has(id)) {
                seen.add(id);
                out[z].push(id);
            }
    for (const m of MODULES) {
        if (seen.has(m.id)) continue;
        const z = ["left", "center", "right"].find(z => DEFAULT_LAYOUT[z].includes(m.id)) ?? "off";
        out[z].push(m.id);
    }
    return out;
}

function zoneOf(l, id) {
    const n = normalizeLayout(l);
    return ZONES.find(z => n[z].includes(id));
}

// перенос в соседнюю зону (по кругу left → center → right → off), модуль встаёт в конец
function moveModule(l, id, d) {
    const n = normalizeLayout(l);
    const from = ZONES.find(z => n[z].includes(id));
    const to = ZONES[(ZONES.indexOf(from) + d + ZONES.length) % ZONES.length];
    n[from] = n[from].filter(x => x !== id);
    n[to].push(id);
    return n;
}

// сдвиг внутри зоны; null — двигать некуда
function reorderModule(l, id, d) {
    const n = normalizeLayout(l);
    const z = ["left", "center", "right"].find(z => n[z].includes(id));
    if (!z) return null;
    const a = n[z], i = a.indexOf(id), j = i + d;
    if (j < 0 || j >= a.length) return null;
    [a[i], a[j]] = [a[j], a[i]];
    return n;
}

function barRows(layout) {
    const n = normalizeLayout(layout);
    const rows = [];
    for (const z of ZONES) {
        rows.push({ header: z === "off" ? "выключены" : z });
        for (const id of n[z])
            rows.push({ type: "module", id, zone: z, label: id, key: "shell.bar.layout", hint: moduleById(id).desc });
    }
    return rows;
}

// outputs: [{ name, scale, make, model, mode }] из `niri msg --json outputs`
// layout: текущее значение shell.bar.layout — из него строится раздел bar/
function sections(outputs, layout) {
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

            { header: "меню" },
            { key: "shell.launcher.rows", label: "строк в меню", type: "int", min: 6, max: 24, step: 1, def: 12 },

            { header: "обновления nopox-shell" },
            { key: "shell.update.check", label: "проверять", type: "bool", def: true, hint: "git fetch в папке shell; нужен git-клон и доступ к репозиторию" },
            { key: "shell.update.hours", label: "раз в, ч", type: "int", min: 1, max: 48, step: 1, def: 6 },
            { key: "shell.update.notify", label: "уведомлять", type: "bool", def: true, hint: "уведомление, когда появились новые коммиты" },
            { key: "shell.update.now", label: "проверить сейчас", type: "action", action: "shellUpdate", hint: "результат — модуль nopox ↑ на панели" }
        ] },

        { id: "bar", rows: [
            ...barRows(layout),

            { header: "панель" },
            { key: "shell.bar.position", label: "положение", type: "enum", options: ["top", "bottom"], def: "top" },
            { key: "shell.bar.height", label: "высота", type: "int", min: 18, max: 48, step: 2, def: 26 },
            { key: "shell.bar.style", label: "стиль", type: "enum", options: ["full", "floating"], def: "full", hint: "floating — с отступами от краёв и рамкой цвета акцента" },
            { key: "shell.bar.opacity", label: "непрозрачность, %", type: "int", min: 30, max: 100, step: 5, def: 100 },
            { key: "shell.bar.autohide", label: "автоскрытие", type: "bool", def: false, hint: "панель появляется при наведении мыши на край экрана" },
            { key: "shell.bar.monitors", label: "мониторы", type: "enum", options: ["all", "primary"], def: "all" },
            { key: "shell.bar.trayCollapsed", label: "трей свёрнут", type: "bool", def: false, hint: "на панели переключается кликом по ‹ / +N; просящие внимания видны всегда" },
            { key: "shell.bar.trayTyping", label: "анимация трея", type: "bool", def: true, hint: "названия печатаются при разворачивании и стираются при сворачивании" },

            { header: "prompt" },
            { key: "shell.bar.prompt", label: "стиль prompt", type: "enum", options: ["user@host", "[user@host]", "user", "host"], def: "user@host" },
            { key: "shell.bar.symbol", label: "символ", type: "enum", options: ["❯", "$", "#", "λ", ">", "→"], def: "❯", hint: "красный, если какое-то окно требует внимания — как $? в shell" },
            { key: "shell.bar.separator", label: "разделитель", type: "enum", options: [" · ", " | ", " / ", " │ ", "  "], def: " · " },
            { key: "shell.bar.typing", label: "эффект набора", type: "bool", def: true, hint: "новое активное окно «печатается» по символу" },
            { key: "shell.bar.titleMax", label: "длина команды", type: "int", min: 20, max: 160, step: 10, def: 80, hint: "максимум символов для приложения и заголовка" },
            { key: "shell.bar.cpuGraph", label: "график cpu", type: "bool", def: true, hint: "▂▃▅▇ — история загрузки, как в btop" },
            { key: "shell.bar.clock", label: "формат часов", type: "enum", options: ["HH:mm", "HH:mm:ss", "ddd HH:mm", "dd.MM HH:mm"], def: "HH:mm" }
        ] },

        { id: "notify", rows: [
            { header: "уведомления" },
            { key: "shell.notify.position", label: "положение", type: "enum", options: ["top-right", "top-left", "bottom-right", "bottom-left"], def: "top-right" },
            { key: "shell.notify.timeout", label: "время показа, с", type: "int", min: 2, max: 60, step: 1, def: 6, hint: "если приложение не задало своё" },
            { key: "shell.notify.max", label: "максимум на экране", type: "int", min: 1, max: 10, step: 1, def: 4 },
            { key: "shell.notify.criticalSticky", label: "критичные не исчезают", type: "bool", def: true, hint: "ERROR висит, пока не закроете" },
            { key: "shell.notify.typing", label: "эффект набора", type: "bool", def: true, hint: "заголовок уведомления печатается по символу" },
            { key: "shell.notify.dnd", label: "не беспокоить", type: "bool", def: false, hint: "показывать только критичные; остальные — в истории (log на панели)" }
        ] },

        { id: "lock", rows: [
            { header: "блокировка экрана" },
            { key: "shell.lock.idle", label: "блокировать через, мин", type: "int", min: 0, max: 60, step: 1, def: 10, hint: "после бездействия; 0 — не блокировать; видеоплееры могут запретить" },
            { key: "shell.lock.echo", label: "эхо пароля", type: "enum", options: ["*", "●", "none"], def: "*", hint: "none — как в консоли: ничего не видно при вводе" },
            { key: "shell.lock.clock", label: "часы", type: "bool", def: true, hint: "крупные часы как tty-clock" },
            { key: "shell.lock.wallpaper", label: "обои на фоне", type: "bool", def: true, hint: "приглушённые текущие обои под приглашением" },
            { key: "shell.lock.preview", label: "предпросмотр", type: "action", action: "lockPreview", hint: "экран блокировки без проверки пароля; Esc — закрыть" },
            { key: "shell.lock.now", label: "заблокировать сейчас", type: "action", action: "lock", hint: "Super+Alt+L" }
        ] },

        { id: "wallpaper", rows: [
            { header: "обои" },
            { key: "wallpaper.fill", label: "заполнение", type: "enum", options: ["fill", "fit", "stretch"], def: "fill", hint: "fill — обрезать, fit — вписать с полосами, stretch — растянуть" },
            { key: "wallpaper.picker", label: "выбрать обои", type: "action", action: "picker", hint: "открыть окно выбора (Mod+Shift+W)" }
        ] }
    ];
}

function find(key, outputs) {
    for (const s of sections(outputs, null))
        for (const r of s.rows)
            if (r.key === key && r.type !== "module") return r;
    return null;
}

function defaultOf(key, outputs) {
    if (key === "shell.bar.layout") return JSON.parse(JSON.stringify(DEFAULT_LAYOUT));
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
