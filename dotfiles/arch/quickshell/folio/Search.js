.pragma library

function match(text, token) {
    text = String(text || "").toLocaleLowerCase();
    if (text === token) return 0;
    if (text.indexOf(token) === 0) return 10;
    var at = text.indexOf(token);
    if (at !== -1) return 30 + at;
    var cursor = 0, first = -1, last = 0;
    for (var i = 0; i < token.length; i++) {
        at = text.indexOf(token[i], cursor);
        if (at === -1) return Infinity;
        if (first === -1) first = at;
        last = at;
        cursor = at + 1;
    }
    return 80 + first + last - first - token.length;
}

function rank(entries, query, history, ordered) {
    var tokens = String(query || "").trim().toLocaleLowerCase().split(/\s+/).filter(function(t) { return t.length > 0; });
    return entries.map(function(entry) {
        var metadata = [entry.genericName || "", entry.comment || "", (entry.keywords || []).join(" ")].join(" ");
        var score = tokens.reduce(function(sum, token) {
            return sum + Math.min(match(entry.name, token), match(metadata, token) + 100);
        }, 0);
        return { entry: entry, score: score, used: Number(history[entry.id]) || 0 };
    }).filter(function(row) { return isFinite(row.score); }).sort(function(a, b) {
        return a.score - b.score || (ordered ? 0 : b.used - a.used || a.entry.name.localeCompare(b.entry.name));
    }).map(function(row) { return row.entry; });
}

function clipboard(text) {
    return text.split("\n").filter(function(line) { return /^\d+\t/.test(line); }).map(function(line) {
        var tab = line.indexOf("\t");
        return { id: line.slice(0, tab), name: line.slice(tab + 1), genericName: "Clipboard history", line: line };
    });
}
