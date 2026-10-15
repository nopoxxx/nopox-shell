.pragma library

// Нечёткий поиск в духе fzf: символы запроса идут по порядку, но не обязательно подряд.
// Возвращает { score, pos } или null. pos — индексы совпавших символов для подсветки.
function match(query, str) {
    if (!query) return { score: 0, pos: [] };
    const q = query.toLowerCase(), s = str.toLowerCase();
    const pos = [];
    let score = 0, si = 0, prev = -2;

    for (const ch of q) {
        if (ch === " ") continue;
        const i = s.indexOf(ch, si);
        if (i < 0) return null;
        score += 1;
        if (i === prev + 1) score += 5;                        // подряд
        if (i === 0 || " -_./".includes(s[i - 1])) score += 8; // начало слова
        if (pos.length) score -= Math.min(i - si, 10) * 0.5;   // штраф за разрыв
        pos.push(i);
        prev = i;
        si = i + 1;
    }
    if (s === q) score += 50;
    else if (s.startsWith(q)) score += 20;
    return { score, pos };
}

// Текст для StyledText: совпавшие символы выделены цветом
function highlight(str, pos, color) {
    const esc = c => c === "<" ? "&lt;" : c === ">" ? "&gt;" : c === "&" ? "&amp;" : c;
    const set = new Set(pos);
    let out = "";
    for (let i = 0; i < str.length; i++)
        out += set.has(i) ? `<font color="${color}">${esc(str[i])}</font>` : esc(str[i]);
    return out;
}
