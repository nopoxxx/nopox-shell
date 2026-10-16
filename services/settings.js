.pragma library

// Схема окна настроек и генерация ~/.config/niri/nopox/*.kdl.
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
    { id: "user", file: "User", inline: true, desc: "user@host — стиль в bar/ → prompt" },
    { id: "workspaces", file: "Workspaces", inline: true, desc: "~/ws/{1,[2],3}: клик — перейти; колёсико по панели — листать" },
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

// Строка раздела: { header } или { key, label, type, def, hint, … }.
// type: bool | int | float (min, max, step) | enum (options) | text | action (action — имя действия,
// обработчик в SettingsWindow.actions) | module (раздел bar/, строится barRows) | combo (сочетание клавиш:
// ↵ — захват нажатия, ⇥ — ввод текстом; action — его строка KDL для проверки конфликтов).
// У действий ключ action.<имя>: значения у них нет, ключ нужен только для поиска и подсказки.
function act(name, label, hint) {
    return { key: "action." + name, label, type: "action", action: name, hint: hint ?? "" };
}

// outputs: [{ name, scale, make, model, mode }] из `niri msg --json outputs`
// layout: текущее значение shell.bar.layout — из него строится раздел bar/
function sections(outputs, layout) {
    return [
        { id: "look", title: "вид", rows: [
            { header: "цвет и шрифт" },
            { key: "shell.accent", label: "акцентный цвет", type: "enum", options: Object.keys(ACCENTS), def: "yellow", hint: "рамки окон shell, prompt, рамка фокуса niri и акцент в приложениях" },
            { key: "shell.fontSize", label: "размер шрифта", type: "int", min: 10, max: 28, step: 1, def: 16 },

            { header: "приложения" },
            { key: "shell.theme.sync", label: "темы Qt и GTK", type: "bool", def: true,
              hint: "тёмная схема, палитра Gruvbox, акцент и иконки Gruvbox Plus в GTK (adw-gtk3, libadwaita) и Qt (qt6ct); открытые окна — после перезапуска приложения" },
            { key: "shell.theme.font", label: "шрифт shell в приложениях", type: "bool", def: true,
              hint: "Terminess в интерфейсе GTK- и Qt-приложений; моноширинный шрифт ставится всегда" },

            { header: "обои" },
            act("picker", "выбрать обои", "локальная коллекция ~/Pictures/Wallpapers (Mod+Shift+W)"),
            act("wallhaven", "найти на wallhaven", "поиск на wallhaven.cc, скачанные — в коллекцию"),
            { key: "wallpaper.fill", label: "заполнение", type: "enum", options: ["fill", "fit", "stretch"], def: "fill", hint: "fill — обрезать, fit — вписать с полосами, stretch — растянуть" },

            { header: "меню" },
            { key: "shell.launcher.rows", label: "строк в меню", type: "int", min: 6, max: 24, step: 1, def: 12, hint: "высота меню Mod+D" }
        ] },

        { id: "windows", title: "окна", rows: [
            { header: "раскладка" },
            { key: "niri.gaps", label: "отступы", type: "int", min: 0, max: 64, step: 2, def: 8 },
            { key: "niri.colWidth", label: "ширина новой колонки", type: "enum", options: ["1/3", "1/2", "2/3", "1"], def: "1/2" },
            { key: "niri.center", label: "центрировать колонку", type: "enum", options: ["never", "always", "on-overflow"], def: "never" },

            { header: "рамки и тени" },
            { key: "niri.ring", label: "рамка фокуса", type: "int", min: 0, max: 12, step: 1, def: 2, hint: "толщина в px, 0 — выключить; цвет — акцент (look/)" },
            { key: "niri.border", label: "обводка окон", type: "int", min: 0, max: 12, step: 1, def: 0, hint: "толщина в px, 0 — выключить" },
            { key: "niri.shadow", label: "тени", type: "bool", def: false },
            { key: "niri.rules.radius", label: "скругление углов", type: "int", min: 0, max: 24, step: 2, def: 0, hint: "радиус в px, 0 — прямые углы" },

            { header: "поведение" },
            { key: "niri.rules.inactiveOpacity", label: "прозрачность неактивных, %", type: "int", min: 50, max: 100, step: 5, def: 100, hint: "100 — непрозрачные" },
            { key: "niri.csd", label: "без декораций приложений", type: "bool", def: true, hint: "prefer-no-csd: просить приложения не рисовать свои заголовки" },

            { header: "анимации" },
            { key: "niri.anim", label: "включены", type: "bool", def: true },
            { key: "niri.anim.slowdown", label: "замедление", type: "float", min: 0.25, max: 3, step: 0.25, def: 1 }
        ] },

        { id: "input", title: "ввод", rows: [
            { header: "клавиатура" },
            { key: "niri.kb.layout", label: "раскладки", type: "text", def: "us,ru", hint: "XKB-раскладки через запятую, например us,ru,ua" },
            { key: "niri.kb.options", label: "опции xkb", type: "text", def: "grp:alt_shift_toggle", hint: "например grp:win_space_toggle,ctrl:nocaps" },
            { key: "niri.kb.repeatDelay", label: "задержка повтора, мс", type: "int", min: 150, max: 1000, step: 25, def: 600 },
            { key: "niri.kb.repeatRate", label: "скорость повтора, /с", type: "int", min: 10, max: 80, step: 5, def: 25 },
            { key: "niri.kb.numlock", label: "numlock при входе", type: "bool", def: true },

            { header: "клавиши" },
            act("binds", "бинды", "все сочетания niri и nopox: изменить, добавить, отключить"),
            act("hotkeys", "подсказка клавиш", "окно niri со всеми сочетаниями (Mod+Shift+/)"),
            { key: "niri.key.micMute", label: "мьют микрофона", type: "combo", def: "", action: MUTE_BINDS["niri.key.micMute"].action, hint: "вкл/выкл микрофон по умолчанию (wpctl); работает и на экране блокировки" },
            { key: "niri.key.audioMute", label: "мьют звука", type: "combo", def: "", action: MUTE_BINDS["niri.key.audioMute"].action, hint: "вкл/выкл звук на устройстве вывода по умолчанию — наушники или колонки (wpctl)" },

            { header: "горячие углы" },
            { key: "niri.hc.topLeft", label: "↖ левый верхний", type: "bool", def: true, hint: "курсор в угол экрана — обзор столов и окон (как Mod+Tab)" },
            { key: "niri.hc.topRight", label: "↗ правый верхний", type: "bool", def: false, hint: "курсор в угол экрана — обзор столов и окон" },
            { key: "niri.hc.bottomLeft", label: "↙ левый нижний", type: "bool", def: false, hint: "курсор в угол экрана — обзор столов и окон" },
            { key: "niri.hc.bottomRight", label: "↘ правый нижний", type: "bool", def: false, hint: "курсор в угол экрана — обзор столов и окон" },

            { header: "мышь и тачпад" },
            { key: "niri.tp.tap", label: "тап для клика", type: "bool", def: true, hint: "тачпад" },
            { key: "niri.tp.natural", label: "естественная прокрутка", type: "bool", def: true, hint: "тачпад" },
            { key: "niri.mouse.accel", label: "ускорение мыши", type: "float", min: -1, max: 1, step: 0.1, def: 0 },
            { key: "niri.mouse.profile", label: "профиль ускорения", type: "enum", options: ["adaptive", "flat"], def: "adaptive" },
            { key: "niri.ffm", label: "фокус следует за мышью", type: "bool", def: false },
            { key: "niri.warp", label: "курсор за фокусом", type: "bool", def: false, hint: "переносить курсор в окно, получившее фокус с клавиатуры" },

            { header: "курсор" },
            { key: "niri.cursor.size", label: "размер", type: "int", min: 16, max: 64, step: 4, def: 24 },
            { key: "niri.cursor.hide", label: "прятать при наборе", type: "bool", def: false }
        ] },

        { id: "bar", title: "панель", rows: [
            ...barRows(layout),

            { header: "панель" },
            { key: "shell.bar.position", label: "положение", type: "enum", options: ["top", "bottom"], def: "top" },
            { key: "shell.bar.height", label: "высота", type: "int", min: 18, max: 48, step: 2, def: 26 },
            { key: "shell.bar.style", label: "стиль", type: "enum", options: ["full", "floating"], def: "full", hint: "floating — с отступами от краёв и рамкой цвета акцента" },
            { key: "shell.bar.opacity", label: "непрозрачность, %", type: "int", min: 30, max: 100, step: 5, def: 100 },
            { key: "shell.bar.autohide", label: "автоскрытие", type: "bool", def: false, hint: "панель появляется при наведении мыши на край экрана" },
            { key: "shell.bar.monitors", label: "мониторы", type: "enum", options: ["all", "primary"], def: "all" },
            { key: "shell.bar.wheelWorkspaces", label: "колёсико — рабочие столы", type: "bool", def: true, hint: "прокрутка по панели листает столы её монитора; vol и kbd — своё колёсико" },
            { key: "shell.bar.separator", label: "разделитель", type: "enum", options: [" · ", " | ", " / ", " │ ", "  "], def: " · " },

            { header: "prompt" },
            { key: "shell.bar.prompt", label: "стиль prompt", type: "enum", options: ["user@host", "[user@host]", "user", "host"], def: "user@host" },
            { key: "shell.bar.symbol", label: "символ", type: "enum", options: ["❯", "$", "#", "λ", ">", "→"], def: "❯", hint: "красный, если какое-то окно требует внимания — как $? в shell" },
            { key: "shell.bar.typing", label: "эффект набора", type: "bool", def: true, hint: "новое активное окно «печатается» по символу" },
            { key: "shell.bar.titleMax", label: "длина команды", type: "int", min: 20, max: 160, step: 10, def: 80, hint: "максимум символов для приложения и заголовка" },

            { header: "модули" },
            { key: "shell.bar.clock", label: "формат часов", type: "enum", options: ["HH:mm", "HH:mm:ss", "ddd HH:mm", "dd.MM HH:mm"], def: "HH:mm" },
            { key: "shell.bar.cpuGraph", label: "график cpu", type: "bool", def: true, hint: "▂▃▅▇ — история загрузки, как в btop" },
            { key: "shell.bar.trayStyle", label: "трей", type: "enum", options: ["icons", "names"], def: "icons", hint: "icons — значки Nerd Font для известных программ, остальные — первой буквой; names — короткие названия" },
            { key: "shell.bar.trayCollapsed", label: "трей свёрнут", type: "bool", def: false, hint: "на панели переключается кликом по ‹ / +N; просящие внимания видны всегда" },
            { key: "shell.bar.trayTyping", label: "анимация трея", type: "bool", def: true, hint: "названия печатаются при разворачивании и стираются при сворачивании" }
        ] },

        { id: "notify", title: "уведомления", rows: [
            { header: "уведомления" },
            { key: "shell.notify.dnd", label: "не беспокоить", type: "bool", def: false, hint: "показывать только критичные; остальные — в истории (log на панели)" },
            { key: "shell.notify.position", label: "положение", type: "enum", options: ["top-right", "top-left", "bottom-right", "bottom-left"], def: "top-right" },
            { key: "shell.notify.timeout", label: "время показа, с", type: "int", min: 2, max: 60, step: 1, def: 6, hint: "если приложение не задало своё" },
            { key: "shell.notify.max", label: "максимум на экране", type: "int", min: 1, max: 10, step: 1, def: 4 },
            { key: "shell.notify.criticalSticky", label: "критичные не исчезают", type: "bool", def: true, hint: "ERROR висит, пока не закроете" },
            { key: "shell.notify.mute", label: "мьют микрофона и звука", type: "bool", def: true, hint: "уведомление, когда микрофон или звук по умолчанию выключается и включается — биндом, клавишей, pavucontrol" },
            { key: "shell.notify.typing", label: "эффект набора", type: "bool", def: true, hint: "заголовок уведомления печатается по символу" }
        ] },

        { id: "lock", title: "блокировка", rows: [
            { header: "блокировка экрана" },
            { key: "shell.lock.idle", label: "блокировать через, мин", type: "int", min: 0, max: 60, step: 1, def: 10, hint: "после бездействия; 0 — не блокировать; видеоплееры могут запретить" },
            { key: "shell.lock.echo", label: "эхо пароля", type: "enum", options: ["*", "●", "none"], def: "*", hint: "none — как в консоли: ничего не видно при вводе" },
            { key: "shell.lock.clock", label: "часы", type: "bool", def: true, hint: "крупные часы как tty-clock" },
            { key: "shell.lock.wallpaper", label: "обои на фоне", type: "bool", def: true, hint: "приглушённые текущие обои под приглашением" },
            act("lockPreview", "предпросмотр", "экран блокировки без проверки пароля; Esc — закрыть"),
            act("lock", "заблокировать сейчас", "Super+Alt+L")
        ] },

        { id: "system", title: "система", rows: [
            { header: "устройства" },
            act("displays", "мониторы", (outputs ?? []).map(o => o.name).join(", ") + " — режим, масштаб, поворот, расположение, VRR"),
            act("wifi", "сеть", "nmtui — Wi-Fi и проводные подключения"),
            act("audio", "звук", "pavucontrol — устройства и громкость приложений; быстрый микшер — клик по vol на панели"),

            { header: "приложения" },
            { key: "shell.terminal", label: "терминал", type: "enum", options: TERMINALS, def: "kitty", hint: "Mod+Return и окна, которые открывает shell (обновления, nmtui, …)" },
            { key: "shell.files", label: "файловый менеджер", type: "enum", options: FILE_MANAGERS, def: "none", hint: "Mod+E; yazi — в терминале" },
            { key: "shell.sh", label: "оболочка", type: "enum", options: SHELLS, def: "zsh", hint: "chsh в терминале (спросит пароль), действует с нового входа; нет пакета — поставит" },
            { key: "shell.browser", label: "браузер", type: "enum", options: Object.keys(BROWSERS), def: "none", hint: "Mod+Shift+B и браузер по умолчанию (xdg-settings); нет пакета — поставит через paru" },

            { header: "скриншоты" },
            { key: "shell.shot.dir", label: "папка", type: "text", def: "~/Pictures/Screenshots", hint: "куда сохраняет ^S; Mod+Shift+S или Print — снимок с разметкой" },
            { key: "shell.shot.enter", label: "по ↵", type: "enum", options: ["copy", "save", "both"], def: "copy", hint: "что делает ↵ в редакторе; ^C — копировать, ^S — сохранить, ⇧↵ — и то и другое" },
            { key: "shell.shot.notify", label: "уведомление", type: "bool", def: true, hint: "после копирования или сохранения" },
            { key: "shell.shot.tool", label: "инструмент", type: "enum", options: SHOT_TOOLS, def: "rect", hint: "последний выбранный в редакторе" },
            { key: "shell.shot.color", label: "цвет", type: "enum", options: SHOT_COLORS, def: "red", hint: "последний выбранный в редакторе (1-9)" },
            { key: "shell.shot.width", label: "толщина", type: "int", min: 1, max: 12, step: 1, def: 3, hint: "линий, текста и шагов ([ ] или колёсико в редакторе)" },

            { header: "конфиги" },
            act("editNiri", "niri", "~/.config/niri/config.kdl — свои настройки niri; nopox/ генерирует shell"),
            act("editShell", "код shell", "~/.config/quickshell/ — QML и JS nopox-shell"),
            act("editTerminal", "терминал", "конфиг выбранного терминала"),

            { header: "nopox-shell" },
            act("shellUpdate", "обновить", "git pull и перезапуск; если новых коммитов нет — проверить (nopox ↑ на панели)"),
            { key: "shell.update.check", label: "проверять обновления", type: "bool", def: true, hint: "git fetch в папке shell; нужен git-клон и доступ к репозиторию" },
            { key: "shell.update.hours", label: "раз в, ч", type: "int", min: 1, max: 48, step: 1, def: 6 },
            { key: "shell.update.notify", label: "уведомлять", type: "bool", def: true, hint: "уведомление, когда появились новые коммиты" },
            act("restartShell", "перезапустить shell", "pkill qs и запуск заново"),
            act("greeterUpdate", "обновить greeter", "переустановить экран входа из текущего shell (sudo)")
        ] }
    ];
}

// поиск по всем разделам: каждое слово запроса — подстрока подписи, подсказки, ключа, заголовка группы
// или имени раздела. Строки остаются как есть (плюс section — индекс раздела) и группируются под
// заголовками «раздел/ · группа» — по одной подписи («размер») не понять, чего она касается.
function searchRows(secs, query) {
    const words = String(query).toLowerCase().split(/\s+/).filter(w => w);
    const out = [];
    secs.forEach((s, i) => {
        let group = "", shown = "";
        for (const r of s.rows) {
            if (r.header) { group = r.header; continue; }
            // у модулей панели общий ключ shell.bar.layout — ищем по их id
            const fields = [r.label, r.hint, r.type === "module" ? r.id : r.key, group, s.id, s.title];
            if (!words.every(w => fields.some(x => String(x ?? "").toLowerCase().includes(w)))) continue;
            const h = s.id + "/ · " + group;
            if (h !== shown) out.push({ header: shown = h });
            out.push(Object.assign({ section: i }, r));
        }
    });
    return out;
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

// горячие углы: ключ настройки → имя угла в niri (gestures { hot-corners { … } })
var HOT_CORNERS = [["niri.hc.topLeft", "top-left"], ["niri.hc.topRight", "top-right"],
    ["niri.hc.bottomLeft", "bottom-left"], ["niri.hc.bottomRight", "bottom-right"]];

// ── скриншоты (ShotWindow) ───────────────────────────────────────────
var SHOT_TOOLS = ["rect", "ellipse", "line", "arrow", "pen", "marker", "text", "step", "blur", "pixel"];
var SHOT_COLORS = ["red", "orange", "yellow", "green", "aqua", "blue", "purple", "white", "black"];   // = ShotWindow.colors

// ── свои сочетания из настроек (type: "combo") ─────────────────────
// Пустое значение — бинда нет. action — готовая строка KDL: по ней Binds.conflict отличает этот бинд от чужих.
var MUTE_BINDS = {
    "niri.key.micMute": { title: "Mute Microphone", action: 'spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"' },
    "niri.key.audioMute": { title: "Mute Audio", action: 'spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"' }
};

// в KDL сочетание идёт без кавычек — пропускаем только имена клавиш и модификаторы через «+»
var COMBO_RE = /^[A-Za-z0-9_]+(\+[A-Za-z0-9_]+)*$/;

// ── значки трея ────────────────────────────────────────────────────
// Глифы Terminess Nerd Font: шаблон ищется в id, заголовке и имени иконки элемента трея (в нижнем регистре).
// Первое совпадение выигрывает — частные шаблоны выше общих. Новый глиф проверять по шрифту
// (fontTools: getBestCmap() и имена вида md-discord), иначе вместо значка будет пустой квадрат.
var TRAY_ICONS = [
    [/discord|vesktop|webcord|legcord|armcord/, 0xF066F],       // md-discord
    [/steam/, 0xF04D3],                                         // md-steam
    [/telegram|ayugram|kotatogram/, 0xF2C6],                    // fa-telegram
    [/spotify/, 0xF04C7],                                       // md-spotify
    [/firefox|librewolf|floorp|\bzen\b/, 0xF0239],                  // md-firefox
    [/chrom|helium|brave|vivaldi/, 0xF02AF],                    // md-google_chrome
    [/slack/, 0xF04B1],                                         // md-slack
    [/skype/, 0xF04AF],                                         // md-skype
    [/whatsapp/, 0xF05A3],                                      // md-whatsapp
    [/element|matrix|nheko|fractal/, 0xF0628],                  // md-matrix
    [/\bobs\b|obs-studio/, 0xF044B],                            // md-record_rec
    [/throne|nekoray|nekobox|hiddify|v2ray|clash|sing-?box|mullvad|proton.?vpn|wireguard|vpn/, 0xF099D], // md-shield_lock
    [/qbittorrent|transmission|deluge|ktorrent|fragments/, 0xF0347], // md-magnet
    [/syncthing/, 0xF04E6],                                     // md-sync
    [/nextcloud|owncloud|insync|megasync|rclone/, 0xF015F],     // md-cloud
    [/dropbox/, 0xF01E3],                                       // md-dropbox
    [/keepass|bitwarden|1password|proton.?pass/, 0xF0306],      // md-key
    [/kdeconnect|gsconnect|valent/, 0xF0121],                   // md-cellphone_link
    [/blueman|bluetooth/, 0xF00AF],                             // md-bluetooth
    [/nm-applet|network|iwgtk/, 0xF05A9],                       // md-wifi
    [/easyeffects|pavucontrol|pasystray|volume|audio/, 0xF057E], // md-volume_high
    [/lutris|heroic|bottles|gamemode/, 0xF0296],                // md-gamepad
    [/\bcode\b|vscode|codium/, 0xF0A1E],                     // md-microsoft_visual_studio_code
    [/solaar|piper|mouse/, 0xF037D],                            // md-mouse
    [/clipboard|copyq|clipman|cliphist/, 0xF014D],              // md-clipboard_text
    [/mpv|vlc|player|music/, 0xF040C],                          // md-play_circle
    [/update|pamac|octopi/, 0xF06B0],                           // md-update
    [/docker|podman/, 0xF0868],                                 // md-docker
    [/mail|thunderbird|geary/, 0xF01EE]                         // md-email
];

// значок элемента трея или "" — тогда Tray покажет первую букву
function trayGlyph(id, title, icon) {
    const hay = [id, title, icon].filter(x => x).join(" ").toLowerCase();
    for (const [re, cp] of TRAY_ICONS)
        if (re.test(hay)) return String.fromCodePoint(cp);
    return "";
}

// ── терминал и файловый менеджер ───────────────────────────────────

var TERMINALS = ["kitty", "alacritty", "ghostty", "foot"];
var FILE_MANAGERS = ["none", "thunar", "nautilus", "dolphin", "nemo", "yazi"];

// оболочка: пакеты, которые ставятся, если её нет (как в install.sh)
var SHELLS = ["zsh", "fish", "bash"];
var SHELL_PKGS = { zsh: "zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions", fish: "fish", bash: "bash bash-completion" };

// браузер: пакет (по нему ищется .desktop для xdg-settings) и команда для Mod+Shift+B
var BROWSERS = {
    none: null,
    helium: { pkg: "helium-browser-bin", bin: "helium-browser" },
    firefox: { pkg: "firefox", bin: "firefox" },
    zen: { pkg: "zen-browser-bin", bin: "zen-browser" },
    chromium: { pkg: "chromium", bin: "chromium" },
    brave: { pkg: "brave-bin", bin: "brave" },
    vivaldi: { pkg: "vivaldi", bin: "vivaldi-stable" }
};

// ghostty принимает только идентификатор приложения с точкой
function termClass(term, c) {
    return term === "ghostty" ? "dev.nopox." + c.replace(/^nopox-/, "") : c;
}

// argv — команда; opts: { cls, hold }. Общая для Term.qml и binds.kdl
function termCmd(term, argv, opts) {
    argv = argv ?? [];
    const hold = opts?.hold ?? false;
    const c = opts?.cls ? termClass(term, opts.cls) : "";
    switch (term) {
    case "foot":
        return ["foot"].concat(c ? ["--app-id=" + c] : [], hold ? ["--hold"] : [], argv);
    case "alacritty":
        return ["alacritty"].concat(c ? ["--class", c] : [], hold ? ["--hold"] : [], argv.length ? ["-e"].concat(argv) : []);
    case "ghostty":
        return ["ghostty"].concat(c ? ["--class=" + c] : [], hold ? ["--wait-after-command=true"] : [], argv.length ? ["-e"].concat(argv) : []);
    default:
        return ["kitty"].concat(c ? ["--class", c] : [], hold ? ["--hold"] : [], argv.length ? ["-e"].concat(argv) : []);
    }
}

// файловый менеджер: yazi — терминальный, остальные — свой бинарник
function filesCmd(term, fm) {
    if (!fm || fm === "none") return null;
    return fm === "yazi" ? termCmd(term, ["yazi"]) : [fm];
}

// ── бинды ──────────────────────────────────────────────────────────

var MODS = ["mod", "super", "ctrl", "alt", "shift", "iso_level3_shift", "iso_level5_shift"];

// ключ для сравнения: регистр и порядок модификаторов не важны, Control = Ctrl
function comboKey(c) {
    const parts = String(c).split("+").map(s => s.trim().toLowerCase()).filter(s => s);
    const key = parts.pop() ?? "";
    const mods = parts.map(m => m === "control" ? "ctrl" : m)
        .sort((a, b) => MODS.indexOf(a) - MODS.indexOf(b));
    return mods.concat([key]).join("+");
}

// однострочные бинды из блоков binds { … }: [{ combo, title, hidden, action, source }]
function parseBinds(text, source) {
    const out = [];
    let inBinds = false;
    for (const raw of String(text ?? "").split("\n")) {
        const line = raw.trim();
        if (!inBinds) {
            if (/^binds\s*\{\s*$/.test(line)) inBinds = true;
            continue;
        }
        if (line === "}") { inBinds = false; continue; }
        if (line.startsWith("//") || line.startsWith("/-")) continue;
        const m = line.match(/^([A-Za-z0-9_]+(?:\+[A-Za-z0-9_]+)*)((?:\s+[a-z-]+=(?:"[^"]*"|[^\s{]+))*)\s*\{\s*(.*?)\s*\}\s*(?:\/\/.*)?$/);
        if (!m) continue;
        const t = m[2].match(/hotkey-overlay-title=(?:"([^"]*)"|null)/);
        out.push({
            combo: m[1],
            title: t?.[1] ?? "",
            hidden: /hotkey-overlay-title=null/.test(m[2]),
            action: m[3].replace(/;\s*$/, ""),
            source
        });
    }
    return out;
}

// действие, как его ввёл человек, → KDL:
//   close-window → close-window      focus-workspace 3 → focus-workspace 3
//   spawn kitty → spawn "kitty"      spawn kitty -e btop → spawn-sh "kitty -e btop"
//   с кавычками — как есть
function actionKdl(a) {
    a = String(a ?? "").trim().replace(/;\s*$/, "");
    if (!a || a.includes('"')) return a;
    const [name, ...args] = a.split(/\s+/);
    if (name === "spawn-sh" || (name === "spawn" && args.length > 1)) return "spawn-sh " + JSON.stringify(args.join(" "));
    return [name, ...args.map(x => /^-?\d+(\.\d+)?$/.test(x) ? x : JSON.stringify(x))].join(" ");
}

// keys: { comboKey: { combo, action, title } }; action "off" — сочетание отключено
function keysKdl(keys) {
    const lines = [
        "// nopox: свои бинды — окно биндов (Mod+S → input/ → бинды), из ~/.config/nopox/settings.json.",
        "// Подключается в config.kdl последним (include \"nopox/keys.kdl\") и перекрывает одноимённые бинды.",
        "// Ручные правки перезапишутся.",
        "",
        "binds {"
    ];
    for (const k in keys) {
        const b = keys[k];
        if (b.action === "off")
            lines.push("    " + b.combo + ' hotkey-overlay-title=null { spawn "true"; }');
        else
            lines.push("    " + b.combo + (b.title ? " hotkey-overlay-title=" + JSON.stringify(b.title) : "")
                + " { " + actionKdl(b.action) + "; }");
    }
    lines.push("}");
    return lines.join("\n") + "\n";
}

// ── мониторы ───────────────────────────────────────────────────────

var TRANSFORMS = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"];

// transform из JSON niri («Normal», «_90», «Flipped90») → значение для конфига
function niriTransform(t) {
    const s = String(t ?? "normal").toLowerCase().replace(/^_/, "");
    if (s === "flipped" || !s.startsWith("flipped")) return s;
    return "flipped-" + s.slice(7);
}

// логический размер: пиксели режима / масштаб, при повороте на 90° стороны меняются
function logicalSize(mode, scale, transform) {
    const m = String(mode).match(/^(\d+)x(\d+)/);
    if (!m) return { w: 0, h: 0 };
    let w = Number(m[1]) / scale, h = Number(m[2]) / scale;
    if (/90|270/.test(transform)) [w, h] = [h, w];
    return { w: Math.round(w), h: Math.round(h) };
}

// ── файлы ~/.config/niri/nopox/ ───────────────────────────────────
// main.kdl подключает остальные; в config.kdl — include "nopox/main.kdl" и в самом конце include "nopox/keys.kdl"

var NIRI_FILES = ["input", "displays", "layout", "window-rules", "cursor", "animations", "misc", "binds"];

// в каком файле живёт настройка — для подсказки в окне настроек
function niriFileOf(key) {
    if (/^niri\.(kb|tp|mouse)\.|^niri\.(ffm|warp)$/.test(key)) return "input.kdl";
    if (/^niri\.(gaps|colWidth|center|ring|border|shadow)$/.test(key) || key === "shell.accent") return "layout.kdl";
    if (/^niri\.rules\./.test(key)) return "window-rules.kdl";
    if (/^niri\.cursor\./.test(key)) return "cursor.kdl";
    if (/^niri\.anim/.test(key)) return "animations.kdl";
    if (key === "niri.csd" || key === "shell.theme.sync" || /^niri\.hc\./.test(key)) return "misc.kdl";
    if (/^niri\.out\./.test(key) || key === "action.displays") return "displays.kdl";
    if (key === "action.binds") return "keys.kdl";
    if (key === "shell.terminal" || key === "shell.files" || key === "shell.browser" || key in MUTE_BINDS) return "binds.kdl";
    return "";
}

function head(what) {
    return [
        "// nopox: " + what,
        "// Сгенерировано nopox-shell (Mod+S) из ~/.config/nopox/settings.json — ручные правки перезапишутся.",
        "// Свои настройки пишите в ~/.config/niri/config.kdl.",
        ""
    ];
}

function text(lines) {
    return lines.filter(l => l !== null).join("\n") + "\n";
}

// get(key) — значение с учётом умолчаний;
// outs — { имя: { enabled, mode, scale, transform, x, y, vrr, primary } }, только то, что задано вручную.
// Возвращает { "input.kdl": текст, … } — все файлы папки nopox/, кроме keys.kdl (его пишет Binds).
function niriFiles(get, outs) {
    const accent = ACCENTS[get("shell.accent")] ?? ACCENTS.yellow;
    const ring = get("niri.ring");
    const border = get("niri.border");
    const radius = get("niri.rules.radius");
    const inactive = get("niri.rules.inactiveOpacity");
    const files = {};

    files["main.kdl"] = text([
        "// nopox: все настройки niri из nopox-shell — по файлу на раздел.",
        "// Подключается из config.kdl: include \"nopox/main.kdl\". Свои бинды (keys.kdl) — отдельно, в конце config.kdl.",
        "",
        ...NIRI_FILES.map(n => "include " + q(n + ".kdl"))
    ]);

    files["input.kdl"] = text([
        ...head("ввод — клавиатура, мышь, тачпад"),
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
        "}"
    ]);

    const displays = head("мониторы — окно мониторов (Mod+S → system/ → мониторы)");
    for (const name in outs) {
        const o = outs[name];
        const body = [];
        if (o.enabled === false) {
            body.push("    off");
        } else {
            if (o.mode) body.push("    mode " + q(o.mode));
            if (o.scale !== undefined) body.push("    scale " + f(o.scale));
            if (o.transform) body.push("    transform " + q(o.transform));
            // окно мониторов пишет обе координаты, но в старых настройках бывает одна — вторая тогда 0
            if (o.x !== undefined || o.y !== undefined) body.push("    position x=" + Math.round(o.x ?? 0) + " y=" + Math.round(o.y ?? 0));
            if (o.vrr) body.push("    variable-refresh-rate");
            if (o.primary) body.push("    focus-at-startup");
        }
        if (body.length) displays.push("output " + q(name) + " {", ...body, "}", "");
    }
    if (displays.length === 4) displays.push("// ничего не задано — niri настраивает мониторы сам");
    files["displays.kdl"] = text(displays);

    files["layout.kdl"] = text([
        ...head("раскладка окон — отступы, колонки, рамка фокуса, обводка, тени"),
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
        "}"
    ]);

    files["window-rules.kdl"] = text([
        ...head("правила окон"),
        ...(radius > 0 ? [
            "// скруглённые углы у всех окон",
            "window-rule {",
            "    geometry-corner-radius " + radius,
            "    clip-to-geometry true",
            "}",
            ""] : []),
        ...(inactive < 100 ? [
            "// неактивные окна полупрозрачные",
            "window-rule {",
            "    match is-active=false",
            "    opacity " + (inactive / 100).toFixed(2),
            "}",
            ""] : []),
        "// терминалы, открытые из меню nopox (install / remove / update …), — плавающие по центру",
        "window-rule {",
        // [.] вместо \. — в строках KDL такой escape недопустим
        '    match app-id="^(nopox-term|dev[.]nopox[.]term)$"',
        "    open-floating true",
        "    default-column-width { fixed 960; }",
        "    default-window-height { fixed 600; }",
        "}",
        "",
        "// обои quickshell видны и как фон режима обзора",
        "layer-rule {",
        '    match namespace="^nopox-wallpaper$"',
        "    place-within-backdrop true",
        "}"
    ]);

    files["cursor.kdl"] = text([
        ...head("курсор"),
        "cursor {",
        "    xcursor-size " + get("niri.cursor.size"),
        get("niri.cursor.hide") ? "    hide-when-typing" : null,
        "}"
    ]);

    files["animations.kdl"] = text([
        ...head("анимации"),
        "animations {",
        get("niri.anim") ? null : "    off",
        "    slowdown " + f(get("niri.anim.slowdown")),
        "}"
    ]);

    files["misc.kdl"] = text([
        ...head("прочее"),
        "// просить приложения не рисовать свои заголовки",
        "prefer-no-csd " + (get("niri.csd") ? "true" : "false"),
        "",
        "// горячие углы открывают обзор; ни одного — off (пустой блок niri понял бы как «по умолчанию»)",
        "gestures {",
        "    hot-corners {",
        ...(HOT_CORNERS.some(([k]) => get(k)) ? HOT_CORNERS.filter(([k]) => get(k)).map(([, c]) => "        " + c) : ["        off"]),
        "    }",
        "}",
        ...(get("shell.theme.sync") ? [
            "",
            "// Qt-приложения берут палитру и шрифт из qt6ct — его настраивает shell (темы Qt и GTK)",
            "environment {",
            '    QT_QPA_PLATFORMTHEME "qt6ct"',
            "}"] : [])
    ]);

    files["binds.kdl"] = text([
        ...head("клавиши nopox и автозапуск shell. Свои — в окне биндов (Mod+S → input/ → бинды), они в keys.kdl"),
        'spawn-at-startup "qs"',
        "",
        "binds {",
        "    Mod+Return hotkey-overlay-title=" + q("Open a Terminal: " + get("shell.terminal")) + " { spawn " + termCmd(get("shell.terminal")).map(q).join(" ") + "; }",
        ...(filesCmd(get("shell.terminal"), get("shell.files"))
            ? ["    Mod+E hotkey-overlay-title=" + q("Files: " + get("shell.files")) + " { spawn " + filesCmd(get("shell.terminal"), get("shell.files")).map(q).join(" ") + "; }"]
            : []),
        ...(BROWSERS[get("shell.browser")]
            ? ["    Mod+Shift+B hotkey-overlay-title=" + q("Browser: " + get("shell.browser")) + " { spawn " + q(BROWSERS[get("shell.browser")].bin) + "; }"]
            : []),
        ...Object.keys(MUTE_BINDS).filter(k => COMBO_RE.test(get(k) ?? "")).map(k =>
            "    " + get(k) + " allow-when-locked=true hotkey-overlay-title=" + q(MUTE_BINDS[k].title) + " { " + MUTE_BINDS[k].action + "; }"),
        '    Mod+D hotkey-overlay-title="Menu" { spawn "qs" "ipc" "call" "launcher" "toggle"; }',
        '    Mod+Space hotkey-overlay-title="Run an Application" { spawn "qs" "ipc" "call" "launcher" "apps"; }',
        '    Mod+Shift+W hotkey-overlay-title="Wallpapers" { spawn "qs" "ipc" "call" "wallpaper" "picker"; }',
        '    Mod+Shift+S hotkey-overlay-title="Screenshot" { spawn "qs" "ipc" "call" "shot" "region"; }',
        '    Print hotkey-overlay-title="Screenshot" { spawn "qs" "ipc" "call" "shot" "region"; }',
        '    Mod+S hotkey-overlay-title="Settings" { spawn "qs" "ipc" "call" "settings" "toggle"; }',
        '    Super+Alt+L hotkey-overlay-title="Lock the Screen" { spawn "qs" "ipc" "call" "lock" "lock"; }',
        "}"
    ]);

    return files;
}

// ── темы приложений: GTK и Qt вслед за shell ───────────────────────
// Пишет services/AppTheme.qml: файлы — в ~/.config, параметры GTK — через gsettings
// (их же отдаёт xdg-desktop-portal: Firefox, Chromium, libadwaita).

const GRUVBOX = {
    bg: "#1d2021", bg0: "#282828", bg1: "#3c3836", bg2: "#504945", bg3: "#665c54",
    fg: "#ebdbb2", fg0: "#fbf1c7", gray: "#928374",
    red: "#fb4934", green: "#b8bb26", yellow: "#fabd2f", blue: "#83a598", purple: "#d3869b"
};

const FONT = "Terminess Nerd Font Mono";

// иконки в цветах Gruvbox (AUR gruvbox-plus-icon-theme, ставит install.sh); без них GTK и Qt берут hicolor
const ICONS = "Gruvbox-Plus-Dark";

// accent-color в GNOME — фиксированный набор; точный цвет задаёт nopox.css
const GNOME_ACCENTS = { yellow: "yellow", orange: "orange", green: "green", aqua: "teal", blue: "blue", purple: "purple", red: "red" };

// пиксели shell → пункты GTK/Qt (96 dpi)
function fontPt(get) {
    return Math.max(6, Math.round(get("shell.fontSize") * 0.75));
}

// именованные цвета libadwaita; их понимает и adw-gtk3 для GTK3-приложений
function gtkColors(accent) {
    const c = GRUVBOX;
    const shade = a => "rgba(0, 0, 0, " + a + ")";
    const out = {
        accent_color: accent, accent_bg_color: accent, accent_fg_color: c.bg,
        destructive_color: c.red, destructive_bg_color: c.red, destructive_fg_color: c.bg,
        success_color: c.green, success_bg_color: c.green, success_fg_color: c.bg,
        warning_color: c.yellow, warning_bg_color: c.yellow, warning_fg_color: c.bg,
        error_color: c.red, error_bg_color: c.red, error_fg_color: c.bg,
        window_bg_color: c.bg, window_fg_color: c.fg,
        view_bg_color: c.bg0, view_fg_color: c.fg,
        headerbar_bg_color: c.bg0, headerbar_fg_color: c.fg, headerbar_border_color: c.bg2,
        headerbar_backdrop_color: c.bg, headerbar_shade_color: shade(0.36), headerbar_darker_shade_color: shade(0.9),
        card_bg_color: c.bg0, card_fg_color: c.fg, card_shade_color: shade(0.36),
        dialog_bg_color: c.bg0, dialog_fg_color: c.fg,
        popover_bg_color: c.bg0, popover_fg_color: c.fg, popover_shade_color: shade(0.25),
        thumbnail_bg_color: c.bg1, thumbnail_fg_color: c.fg,
        shade_color: shade(0.25), scrollbar_outline_color: shade(0.5)
    };
    for (const p of ["sidebar", "secondary_sidebar"])
        Object.assign(out, {
            [p + "_bg_color"]: c.bg0, [p + "_fg_color"]: c.fg, [p + "_backdrop_color"]: c.bg,
            [p + "_shade_color"]: shade(0.25), [p + "_border_color"]: c.bg1
        });
    return out;
}

function gtkCss(colors, vars) {
    const head = [
        "/* nopox: палитра shell для GTK — сгенерировано nopox-shell (Mod+S → look/ → темы Qt и GTK).",
        "   Ручные правки перезапишутся; свои стили пишите в gtk.css после строки @import. */",
        ""
    ];
    const defs = Object.keys(colors).map(k => "@define-color " + k + " " + colors[k] + ";");
    // libadwaita ≥ 1.6 читает цвета из CSS-переменных — задаём и их
    const css = vars ? ["", ":root {", ...Object.keys(colors).map(k => "    --" + k.replace(/_/g, "-") + ": " + colors[k] + ";"), "}"] : [];
    return head.concat(defs, css).join("\n") + "\n";
}

// палитра qt6ct: роли QPalette по порядку, от WindowText до Accent
function qtColors(accent, disabled) {
    const c = GRUVBOX;
    const text = disabled ? c.gray : c.fg;
    return [
        text, c.bg1, c.bg2, c.bg1, c.bg, "#32302f",     // WindowText Button Light Midlight Dark Mid
        text, c.fg0, text, c.bg0, c.bg, "#000000",      // Text BrightText ButtonText Base Window Shadow
        disabled ? c.bg2 : accent, c.bg,                // Highlight HighlightedText
        c.blue, c.purple, "#32302f", c.bg,              // Link LinkVisited AlternateBase NoRole
        c.bg0, c.fg, c.gray, disabled ? c.bg2 : accent  // ToolTipBase ToolTipText PlaceholderText Accent
    ].join(", ");
}

// QFont::toString(): семейство, размер в пунктах, -1, 5, вес 50 (обычный), остальное — нули
function qtFont(pt) {
    return '"' + FONT + "," + pt + ',-1,5,50,0,0,0,0,0"';
}

// home — домашняя папка: путь к схеме в qt6ct.conf абсолютный.
// Возвращает { путь от ~/.config: текст }. С выключенной синхронизацией nopox.css пустые — GTK как без shell;
// qt6ct не трогаем: без QT_QPA_PLATFORMTHEME (misc.kdl) он не используется.
function themeFiles(get, home) {
    if (!get("shell.theme.sync")) {
        const off = "/* nopox: синхронизация тем выключена (Mod+S → look/ → темы Qt и GTK) */\n";
        return { "gtk-3.0/nopox.css": off, "gtk-4.0/nopox.css": off };
    }
    const accent = ACCENTS[get("shell.accent")] ?? ACCENTS.yellow;
    const colors = gtkColors(accent);
    const pt = fontPt(get);
    return {
        "gtk-3.0/nopox.css": gtkCss(colors, false),
        "gtk-4.0/nopox.css": gtkCss(colors, true),
        "qt6ct/colors/nopox.conf": [
            "; nopox: палитра shell для Qt — сгенерировано nopox-shell, ручные правки перезапишутся",
            "[ColorScheme]",
            "active_colors=" + qtColors(accent, false),
            "disabled_colors=" + qtColors(accent, true),
            "inactive_colors=" + qtColors(accent, false),
            ""
        ].join("\n"),
        "qt6ct/qt6ct.conf": [
            "; nopox: сгенерировано nopox-shell (Mod+S → look/ → темы Qt и GTK), ручные правки перезапишутся",
            "[Appearance]",
            "color_scheme_path=" + home + "/.config/qt6ct/colors/nopox.conf",
            "custom_palette=true",
            "icon_theme=" + ICONS,
            "standard_dialogs=xdgdesktopportal",
            "style=Fusion",
            "",
            "[Fonts]",
            "fixed=" + qtFont(pt),
            ...(get("shell.theme.font") ? ["general=" + qtFont(pt)] : []),
            ""
        ].join("\n")
    };
}

// [[ключ org.gnome.desktop.interface, значение GVariant | "" — сбросить]].
// С выключенной синхронизацией — ничего: свои настройки GTK пользователь задаёт сам.
function themeGsettings(get) {
    if (!get("shell.theme.sync")) return [];
    const s = v => "'" + v + "'";
    const font = s(FONT + " " + fontPt(get));
    return [
        ["color-scheme", s("prefer-dark")],
        ["gtk-theme", s("adw-gtk3-dark")],
        ["icon-theme", s(ICONS)],
        ["accent-color", s(GNOME_ACCENTS[get("shell.accent")] ?? "yellow")],
        ["cursor-size", String(get("niri.cursor.size"))],
        ["monospace-font-name", font],
        ["font-name", get("shell.theme.font") ? font : ""],
        ["document-font-name", get("shell.theme.font") ? font : ""]
    ];
}
