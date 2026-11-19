.pragma library

function windows(tree) {
    var found = [];
    function visit(node, workspace) {
        if (node.type === "workspace") {
            if (node.name === "__i3_scratch") return;
            workspace = node.name;
        }
        var children = (node.nodes || []).concat(node.floating_nodes || []);
        if ((node.app_id || node.window) && children.length === 0 && workspace !== null) {
            found.push({
                id: node.id,
                app: String(node.app_id || (node.window_properties || {}).class || ""),
                title: String(node.name || ""),
                workspace: workspace,
                focused: !!node.focused,
                urgent: !!node.urgent
            });
            return;
        }
        var order = node.focus || [];
        children.slice().sort(function(a, b) {
            var x = order.indexOf(a.id), y = order.indexOf(b.id);
            return (x === -1 ? 1e9 : x) - (y === -1 ? 1e9 : y);
        }).forEach(function(child) { visit(child, workspace); });
    }
    visit(tree, null);
    return found;
}

function showing(tree) {
    var seen = {};
    (tree.nodes || []).forEach(function(output) {
        if (output.type === "output" && output.name !== "__i3" && output.current_workspace)
            seen[output.name] = output.current_workspace;
    });
    return seen;
}

function frameUpdates(tree) {
    var commands = [];
    function visit(node) {
        var children = (node.nodes || []).concat(node.floating_nodes || []);
        if ((node.app_id || node.window) && children.length === 0 && node.border === "normal" && Number.isInteger(node.id))
            commands.push("[con_id=" + node.id + "] border pixel 1");
        children.forEach(visit);
    }
    visit(tree);
    return commands;
}

var numbers = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"];

function count(n) { return numbers[n] || String(n); }

var names = { "helium": "Helium", "kitty": "Kitty", "com.anthropic.claude": "Claude", "org.gnome.nautilus": "Files", "thunar": "Thunar", "teams-for-linux": "Teams" };

function proper(app) {
    var key = String(app || "").toLowerCase();
    if (names[key]) return names[key];
    var name = String(app || "").split(/[.\/]/).pop().replace(/[-_]+/g, " ").trim();
    return name ? name.charAt(0).toUpperCase() + name.slice(1) : "Something";
}

var terminals = ["kitty", "alacritty", "foot", "wezterm", "ghostty"];

function several(app, n) {
    if (terminals.indexOf(String(app).toLowerCase()) !== -1)
        return n === 1 ? "a terminal" : count(n) + " terminals";
    return n === 1 ? proper(app) : count(n) + " " + proper(app) + " windows";
}

function list(items) {
    if (items.length <= 1) return items.join("");
    return items.slice(0, -1).join(", ") + " and " + items[items.length - 1];
}

function escape(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function spokenTime(date) {
    var minutes = Math.round((date.getHours() * 60 + date.getMinutes()) / 5) * 5;
    var hour = Math.floor(minutes / 60) % 24, past = minutes % 60;
    var steps = { 5: "five", 10: "ten", 15: "quarter", 20: "twenty", 25: "twenty-five", 30: "half" };
    function named(h) {
        h = h % 24;
        if (h === 0) return "midnight";
        if (h === 12) return "noon";
        return numbers[h % 12];
    }
    if (past === 0) {
        var whole = named(hour);
        return whole === "midnight" || whole === "noon" ? whole : whole + " o'clock";
    }
    if (past <= 30) return steps[past] + " past " + named(hour);
    return steps[60 - past] + " to " + named(hour + 1);
}

var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

function since(then, now) {
    var minutes = Math.max(0, Math.round((now - then) / 60000));
    if (minutes < 1) return "just now";
    if (minutes === 1) return "a minute ago";
    if (minutes < 20) return count(minutes) + " minutes ago";
    if (minutes < 25) return "twenty minutes ago";
    if (minutes < 40) return "half an hour ago";
    if (minutes < 90) return "an hour ago";
    var midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    var days = Math.ceil((midnight - new Date(then.getFullYear(), then.getMonth(), then.getDate())) / 86400000);
    if (days <= 0) {
        var hours = Math.round(minutes / 60);
        return hours === 1 ? "an hour ago" : count(hours) + " hours ago";
    }
    if (days === 1) return "yesterday";
    if (days < 7) return weekdays[then.getDay()];
    return then.getDate() + " " + months[then.getMonth()];
}

function elsewhere(all, here) {
    var groups = [];
    all.forEach(function(w) {
        if (w.workspace === here) return;
        var found = groups.filter(function(g) { return g.desk === w.workspace && g.app === w.app; })[0];
        if (found) found.n++;
        else groups.push({ desk: w.workspace, app: w.app, n: 1 });
    });
    groups.sort(function(a, b) { return a.desk.localeCompare(b.desk, undefined, { numeric: true }); });
    return groups.map(function(g) { return { text: several(g.app, g.n), desk: g.desk, n: g.n }; });
}

function inFocus(app, title) {
    var name = proper(app);
    var showing = String(title || "").trim();
    var bare = showing.toLowerCase().replace(/[^a-z0-9]+/g, "");
    if (bare === name.toLowerCase().replace(/[^a-z0-9]+/g, "") || bare === String(app || "").toLowerCase().replace(/[^a-z0-9]+/g, "")) showing = "";
    return [name, showing];
}

function headline(now, place) {
    return "It is " + spokenTime(now) + " on a " + weekdays[now.getDay()] + (place ? " in " + place : "") + ".";
}

function facts(now, all, here, waiting, more) {
    var rows = [];
    function capital(html) {
        return html.replace(/^(<a [^>]*>)?([a-z])/, function(_, tag, letter) { return (tag || "") + letter.toUpperCase(); });
    }
    function link(to, text) { return '<a href="' + escape(to) + '">' + escape(text) + "</a>"; }
    var waits = (waiting || []).filter(function(w) { return w.desk !== here; });
    var quiet = elsewhere(all, here).filter(function(o) { return !waits.some(function(w) { return w.desk === o.desk; }); });
    if (quiet.length > 0) {
        rows.push({ label: "elsewhere", text: capital(list(quiet.map(function(o) { return link("desk:" + o.desk, o.text); }))) + "." });
    }
    if (waits.length > 0) {
        rows.push({ label: "waiting", text: list(waits.map(function(w) {
            var minutes = w.since ? Math.round((now - w.since) / 60000) : 0;
            return link("desk:" + w.desk, w.name) + (minutes >= 2 ? ", " + count(minutes) + " minutes" : "");
        })) + "." });
    }
    more = more || {};
    if (more.playing && more.playing.title) {
        rows.push({ label: "playing", text: '<a href="pause"><i>' + escape(more.playing.title) + "</i></a>" + (more.playing.artist ? " by " + escape(more.playing.artist) : "") + "." });
    }
    if (more.missed > 0) {
        rows.push({ label: "missed", text: capital(link("missed", count(more.missed) + (more.missed === 1 ? " notification" : " notifications"))) + "." });
    }
    return rows;
}

function deskName(all, desk) {
    var mine = all.filter(function(w) { return w.workspace === desk; });
    if (mine.length === 0) return "here";
    var tally = {};
    mine.forEach(function(w) { tally[w.app] = (tally[w.app] || 0) + 1; });
    var best = Object.keys(tally).sort(function(a, b) { return tally[b] - tally[a]; })[0];
    return proper(best) + (Object.keys(tally).length > 1 ? " +" + (mine.length - tally[best]) : "");
}

function lately(recent, now, limit) {
    return Object.keys(recent || {}).map(function(id) {
        return { id: id, name: id.split("/").slice(-2).join(" / "), then: new Date(recent[id]) };
    }).filter(function(p) { return !isNaN(p.then); }).sort(function(a, b) { return b.then - a.then; })
        .slice(0, limit).map(function(p) { return { id: p.id, name: p.name, when: since(p.then, now) }; });
}

function match(text, token) {
    text = String(text || "").toLowerCase();
    if (text === token) return 0;
    if (text.indexOf(token) === 0) return 10;
    var words = text.split(/[\s\/._-]+/);
    for (var w = 0; w < words.length; w++) if (words[w].indexOf(token) === 0) return 20 + w;
    var at = text.indexOf(token);
    if (at !== -1) return 40 + at;
    var cursor = 0, first = -1, last = 0;
    for (var i = 0; i < token.length; i++) {
        at = text.indexOf(token[i], cursor);
        if (at === -1) return Infinity;
        if (first === -1) first = at;
        last = at;
        cursor = at + 1;
    }
    if (last - first > token.length + 1) return Infinity;
    return 90 + last - first;
}

var commands = [
    { id: "lock", verb: "Lock", name: "the screen", words: "lock screen" },
    { id: "sleep", verb: "Put", name: "the machine to sleep", words: "sleep suspend" },
    { id: "quiet", verb: "Keep", name: "notifications quiet", words: "quiet silence do not disturb dnd" },
    { id: "loud", verb: "Let", name: "notifications through", words: "loud notifications alerts" },
    { id: "mute", verb: "Mute", name: "the sound", words: "mute sound volume" },
    { id: "pause", verb: "Pause", name: "the music", words: "pause play music stop" },
    { id: "next", verb: "Skip", name: "to the next track", words: "next skip track" },
    { id: "logout", verb: "Log", name: "out", words: "logout log out exit", confirm: true },
    { id: "restart", verb: "Restart", name: "the machine", words: "restart reboot", confirm: true },
    { id: "shutdown", verb: "Shut", name: "the machine down", words: "shutdown shut down power off", confirm: true },
    { id: "view-orbit", verb: "Show", name: "the orbit", words: "view orbit desks bodies" },
    { id: "view-dial", verb: "Show", name: "the dial", words: "view dial day hours" },
    { id: "view-numeral", verb: "Show", name: "the numeral", words: "view numeral number" },
    { id: "view-plate", verb: "Show", name: "the plate", words: "view plate rings" },
    { id: "view-words", verb: "Show", name: "the words", words: "view words lyrics sentence" }
];

function sum(query) {
    var text = String(query || "").trim().replace(/^=\s*/, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, ".");
    if (!/^[\d\s.+\-*\/()%^]+$/.test(text) || !/\d\s*[+\-*\/%^]\s*[\d(.\-]/.test(text)) return null;
    var at = 0, ok = true;
    function skip() { while (text[at] === " ") at++; }
    function atom() {
        skip();
        if (text[at] === "(") { at++; var inner = sums(); skip(); if (text[at] !== ")") ok = false; at++; return inner; }
        var found = /^\d*\.?\d+/.exec(text.slice(at));
        if (!found) { ok = false; return 0; }
        at += found[0].length;
        return Number(found[0]);
    }
    function signed() { skip(); if (text[at] === "-") { at++; return -signed(); } return atom(); }
    function powers() { var base = signed(); skip(); if (text[at] === "^") { at++; return Math.pow(base, powers()); } return base; }
    function products() {
        var value = powers();
        for (skip(); "*/%".indexOf(text[at]) !== -1 && at < text.length; skip()) {
            var op = text[at++], right = powers();
            value = op === "*" ? value * right : (op === "/" ? value / right : value % right);
        }
        return value;
    }
    function sums() {
        var value = products();
        for (skip(); "+-".indexOf(text[at]) !== -1 && at < text.length; skip()) {
            var op = text[at++], right = products();
            value = op === "+" ? value + right : value - right;
        }
        return value;
    }
    var value = sums();
    skip();
    if (!ok || at < text.length || !isFinite(value)) return null;
    return { text: text.replace(/\s+/g, " "), value: String(parseFloat(value.toPrecision(12))) };
}

function suggest(sources, now) {
    var rows = [];
    (sources.windows || []).slice(0, 3).forEach(function(w) {
        rows.push({ kind: "window", verb: "Go to", name: proper(w.app), detail: (w.title ? w.title + ", " : "") + "on desk " + w.workspace, window: w });
    });
    lately(sources.recent, now, 3).forEach(function(p) {
        rows.push({ kind: "project", verb: "Resume", name: p.name, detail: "last opened " + p.when, project: p.id });
    });
    var used = sources.used || {};
    Object.keys(used).sort(function(a, b) { return used[b] - used[a]; }).map(function(id) {
        return (sources.apps || []).filter(function(a) { return a.id === id; })[0];
    }).filter(function(a) { return !!a; }).slice(0, 3).forEach(function(a) {
        rows.push({ kind: "app", verb: "Open", name: a.name, detail: String(a.genericName || a.comment || "").toLowerCase(), app: a });
    });
    return rows;
}

function ask(query, sources, now, limit) {
    var tokens = String(query || "").trim().toLowerCase().split(/\s+/).filter(function(t) { return t.length > 0; });
    if (tokens.length === 0) return suggest(sources, now);
    function score(fields, second) {
        return tokens.reduce(function(sum, token) {
            return sum + Math.min.apply(null, fields.map(function(f, i) { return match(f, token) + i * (second === undefined ? 60 : second); }));
        }, 0);
    }
    var rows = [];
    (sources.windows || []).forEach(function(w) {
        rows.push({ kind: "window", verb: "Go to", name: proper(w.app), detail: (w.title ? w.title + ", " : "") + "on desk " + w.workspace,
            window: w, score: score([proper(w.app), w.title], 3) });
    });
    lately(sources.recent, now, 200).forEach(function(p, i) {
        rows.push({ kind: "project", verb: "Resume", name: p.name, detail: "last opened " + p.when, project: p.id,
            score: score([p.name.split(" / ").pop(), p.name]) + 4 + Math.min(i, 20) * 0.1 });
    });
    (sources.apps || []).forEach(function(a) {
        var detail = String(a.genericName || a.comment || "").toLowerCase();
        rows.push({ kind: "app", verb: "Open", name: a.name, detail: detail, app: a,
            score: score([a.name, detail + " " + (a.keywords || []).join(" ")]) + 6 - (sources.used && sources.used[a.id] ? 3 : 0) });
    });
    commands.forEach(function(c) {
        rows.push({ kind: "command", verb: c.verb, name: c.name, detail: "", command: c.id, confirm: !!c.confirm, score: score([c.words]) + 8 });
    });
    var found = rows.filter(function(r) { return isFinite(r.score); })
        .sort(function(a, b) { return a.score - b.score; }).slice(0, limit || 7);
    var worked = sum(query);
    if (worked) found.unshift({ kind: "sum", verb: "Copy", name: worked.value, detail: "is " + worked.text, value: worked.value });
    return found.slice(0, limit || 7);
}

function rest(query, name) {
    var typed = String(query || "");
    return name.toLowerCase().indexOf(typed.toLowerCase()) === 0 ? name.slice(typed.length) : "";
}

function sky(now, latitude) {
    var lat = (typeof latitude === "number" ? latitude : 50) * Math.PI / 180;
    var start = new Date(now.getFullYear(), 0, 0);
    var day = Math.floor((now - start) / 86400000);
    var tilt = -23.44 * Math.cos(2 * Math.PI * (day + 10) / 365) * Math.PI / 180;
    var half = Math.acos(Math.max(-1, Math.min(1, -Math.tan(lat) * Math.tan(tilt)))) / Math.PI * 12;
    var winter = Math.max(new Date(now.getFullYear(), 0, 1).getTimezoneOffset(), new Date(now.getFullYear(), 6, 1).getTimezoneOffset());
    var noon = 12 + (winter - now.getTimezoneOffset()) / 60;
    var rise = noon - half, set = noon + half;
    var hour = now.getHours() + now.getMinutes() / 60 + now.getSeconds() / 3600;
    var up = hour >= rise && hour <= set;
    var night = 24 - (set - rise);
    var progress = up ? (hour - rise) / Math.max(set - rise, 0.01) : ((hour - set + 24) % 24) / Math.max(night, 0.01);
    var edge = Math.min(Math.abs(hour - rise), Math.abs(hour - set), 24 - Math.abs(hour - rise), 24 - Math.abs(hour - set));
    var light = Math.max(0, Math.min(1, 0.5 + (up ? 1 : -1) * edge / 1.5));
    if (half >= 12) { up = true; light = 1; progress = hour / 24; }
    if (half <= 0) { up = false; light = 0; progress = hour / 24; }
    var months = (now.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000 / 29.530588853;
    return { progress: Math.max(0, Math.min(1, progress)), light: light, phase: months - Math.floor(months), rise: rise, set: set };
}

function ago(ms) {
    var minutes = Math.max(0, Math.round(ms / 60000));
    if (minutes < 1) return "just now";
    if (minutes < 60) return minutes + " min";
    if (minutes < 60 * 36) return Math.round(minutes / 60) + " h";
    return Math.round(minutes / 1440) + " d";
}

function lasting(ms) {
    var minutes = Math.max(0, Math.round(ms / 60000));
    if (minutes < 60) return minutes + " min";
    return Math.floor(minutes / 60) + " h" + (minutes % 60 ? " " + (minutes % 60) + " min" : "");
}

function hourMinute(when) {
    var d = new Date(when);
    return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
}

function dayKey(when) {
    var d = new Date(when);
    return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2);
}

function dayPart(when) {
    var d = new Date(when);
    return (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400;
}

function noteSpan(spans, now, desk, name) {
    var next = spans.slice();
    var last = next[next.length - 1];
    if (last && last.desk === desk && last.name === name && now - last.to < 150000)
        next[next.length - 1] = { from: last.from, to: now, desk: desk, name: name };
    else
        next.push({ from: now, to: now, desk: desk, name: name });
    return next;
}

function dayStats(spans) {
    var total = 0, tally = {}, longest = { ms: 0, from: 0 }, run = null;
    (spans || []).forEach(function(s) {
        var ms = Math.max(0, s.to - s.from);
        total += ms;
        var name = String(s.name || "").replace(/ \+\d+$/, "");
        tally[name] = (tally[name] || 0) + ms;
        if (run && s.from - run.to < 300000) run.to = s.to;
        else run = { from: s.from, to: s.to };
        if (run.to - run.from > longest.ms) longest = { ms: run.to - run.from, from: run.from };
    });
    var names = Object.keys(tally).map(function(name) { return { name: name, ms: tally[name] }; })
        .sort(function(a, b) { return b.ms - a.ms; });
    return { total: total, names: names, longest: longest };
}

function orbits(all, here, waiting, lastSeen) {
    var desks = [];
    all.forEach(function(w) { if (w.workspace !== here && desks.indexOf(w.workspace) === -1) desks.push(w.workspace); });
    return desks.map(function(desk) {
        return {
            desk: desk,
            name: deskName(all, desk).replace(/ \+\d+$/, ""),
            count: all.filter(function(w) { return w.workspace === desk; }).length,
            urgent: !!(waiting || {})[desk],
            seen: (lastSeen || {})[desk] || 0
        };
    }).sort(function(a, b) { return b.seen - a.seen || (a.desk < b.desk ? -1 : 1); });
}

function parseLyrics(text) {
    var lines = [];
    String(text || "").split(/\r?\n/).forEach(function(row) {
        var stamps = [], rest = row, found;
        while ((found = /^\s*\[(\d+):(\d+(?:[.:]\d+)?)\]/.exec(rest))) {
            stamps.push(Number(found[1]) * 60 + Number(found[2].replace(":", ".")));
            rest = rest.slice(found[0].length);
        }
        stamps.forEach(function(at) { lines.push({ at: at, text: rest.trim() }); });
    });
    return lines.sort(function(a, b) { return a.at - b.at; });
}

function lineAt(lines, position) {
    var at = -1;
    for (var i = 0; i < lines.length && lines[i].at <= position + 0.15; i++) at = i;
    return at;
}

function bestLyrics(answers, length) {
    var best = null;
    (Array.isArray(answers) ? answers : []).forEach(function(a) {
        if (!a || !a.syncedLyrics) return;
        var off = length > 0 && a.duration > 0 ? Math.abs(a.duration - length) : 0;
        if (!best || off < best.off) best = { off: off, text: a.syncedLyrics };
    });
    return best && best.off <= 12 ? parseLyrics(best.text) : [];
}
