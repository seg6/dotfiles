.pragma library

// Every window in the Sway tree, most recently focused first. Sway keeps each
// container's children in focus order, so following that order through the
// tree gives the order a person would call "last used".
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

// Which workspace each output is showing: {"DP-1": "2"}.
function showing(tree) {
    var seen = {};
    (tree.nodes || []).forEach(function(output) {
        if (output.type === "output" && output.name !== "__i3" && output.current_workspace)
            seen[output.name] = output.current_workspace;
    });
    return seen;
}

// Windows have a hairline and no heading. One that arrives with a heading,
// from another layout, loses it; ones that draw their own frame are left alone.
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

// What a person calls the program: "Helium", not "helium-browser" or
// "com.anthropic.Claude".
var names = { "helium": "Helium", "kitty": "Kitty", "com.anthropic.claude": "Claude", "org.gnome.nautilus": "Files", "thunar": "Thunar", "teams-for-linux": "Teams" };

function proper(app) {
    var key = String(app || "").toLowerCase();
    if (names[key]) return names[key];
    var name = String(app || "").split(/[.\/]/).pop().replace(/[-_]+/g, " ").trim();
    return name ? name.charAt(0).toUpperCase() + name.slice(1) : "Something";
}

var terminals = ["kitty", "alacritty", "foot", "wezterm", "ghostty"];

// "Helium", "a terminal", "three terminals".
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

// The hour the way it is said aloud, to the nearest five minutes: "twenty to
// one", "half past nine", "noon".
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

// How long ago, as a person would put it: "two minutes ago", "yesterday",
// "Monday", "12 November".
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

// What is open on other desks, each thing a link to its desk:
// [{text: "three terminals", desk: "2"}].
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

// The window in focus, as the program and what it is showing. A window whose
// title only repeats the program's name is said once: ["Claude", ""].
function inFocus(app, title) {
    var name = proper(app);
    var showing = String(title || "").trim();
    var bare = showing.toLowerCase().replace(/[^a-z0-9]+/g, "");
    if (bare === name.toLowerCase().replace(/[^a-z0-9]+/g, "") || bare === String(app || "").toLowerCase().replace(/[^a-z0-9]+/g, "")) showing = "";
    return [name, showing];
}

// The first thing the page says: "It is twenty to one on a Wednesday in Berlin."
function headline(now, place) {
    return "It is " + spokenTime(now) + " on a " + weekdays[now.getDay()] + (place ? " in " + place : "") + ".";
}

// What else is true, one fact to a line, each a label and rich text:
//   [{label: "elsewhere", text: '<a href="desk:1">Helium</a> and …'}, …]
// `waiting` lists what wants attention: [{name: "Discord", desk: "8", since: Date}].
// `more` is {playing: {title, artist}, missed: 3}. Links are "desk:N", "pause" and "missed".
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

// A desk's name in the line of desks along the top: what is mostly on it.
function deskName(all, desk) {
    var mine = all.filter(function(w) { return w.workspace === desk; });
    if (mine.length === 0) return "here";
    var tally = {};
    mine.forEach(function(w) { tally[w.app] = (tally[w.app] || 0) + 1; });
    var best = Object.keys(tally).sort(function(a, b) { return tally[b] - tally[a]; })[0];
    return proper(best) + (Object.keys(tally).length > 1 ? " +" + (mine.length - tally[best]) : "");
}

// The projects opened most recently, from the `ws` tool's own record
// ({"personal/dotfiles": "2026-11-18T11:16:43Z"}), newest first.
function lately(recent, now, limit) {
    return Object.keys(recent || {}).map(function(id) {
        return { id: id, name: id.split("/").slice(-2).join(" / "), then: new Date(recent[id]) };
    }).filter(function(p) { return !isNaN(p.then); }).sort(function(a, b) { return b.then - a.then; })
        .slice(0, limit).map(function(p) { return { id: p.id, name: p.name, when: since(p.then, now) }; });
}

// How well a name answers what was typed: lower is better, Infinity is no.
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
    // letters scattered across a phrase are a coincidence, not a match
    if (last - first > token.length + 1) return Infinity;
    return 90 + last - first;
}

// What the desktop can simply be told to do.
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
    { id: "shutdown", verb: "Shut", name: "the machine down", words: "shutdown shut down power off", confirm: true }
];

// Everything that answers what was typed, best first, each as the parts of a
// sentence: a verb, a name, and a few words more.
//   {kind: "window" | "project" | "app" | "command", verb, name, detail, ...}
function ask(query, sources, now, limit) {
    var tokens = String(query || "").trim().toLowerCase().split(/\s+/).filter(function(t) { return t.length > 0; });
    if (tokens.length === 0) return [];
    // The first field is the name; a match in a later one counts for less,
    // by `second` (a window's title is as good as its name, a description is not).
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
    return rows.filter(function(r) { return isFinite(r.score); })
        .sort(function(a, b) { return a.score - b.score; }).slice(0, limit || 7);
}

// The rest of a name once what was typed is taken off its front, so the
// request can finish itself: "hel" + "ium".
function rest(query, name) {
    var typed = String(query || "");
    return name.toLowerCase().indexOf(typed.toLowerCase()) === 0 ? name.slice(typed.length) : "";
}

// Where the light is, for the picture: {progress, light, phase}.
// `progress` is how far the sun is across the sky, 0 at rising to 1 at setting;
// after dark it is the moon's, from sunset to sunrise. `light` is 1 by day and
// 0 by night, with three quarters of an hour of dawn and dusk between.
// `phase` is the moon's: 0 new, 0.5 full. Without a latitude, 50 north is assumed.
function sky(now, latitude) {
    var lat = (typeof latitude === "number" ? latitude : 50) * Math.PI / 180;
    var start = new Date(now.getFullYear(), 0, 0);
    var day = Math.floor((now - start) / 86400000);
    var tilt = -23.44 * Math.cos(2 * Math.PI * (day + 10) / 365) * Math.PI / 180;
    var half = Math.acos(Math.max(-1, Math.min(1, -Math.tan(lat) * Math.tan(tilt)))) / Math.PI * 12;
    // Clocks on summer time run an hour ahead of the sun.
    var winter = Math.max(new Date(now.getFullYear(), 0, 1).getTimezoneOffset(), new Date(now.getFullYear(), 6, 1).getTimezoneOffset());
    var noon = 12 + (winter - now.getTimezoneOffset()) / 60;
    var rise = noon - half, set = noon + half;
    var hour = now.getHours() + now.getMinutes() / 60 + now.getSeconds() / 3600;
    var up = hour >= rise && hour <= set;
    var night = 24 - (set - rise);
    var progress = up ? (hour - rise) / Math.max(set - rise, 0.01) : ((hour - set + 24) % 24) / Math.max(night, 0.01);
    var edge = Math.min(Math.abs(hour - rise), Math.abs(hour - set), 24 - Math.abs(hour - rise), 24 - Math.abs(hour - set));
    var light = Math.max(0, Math.min(1, 0.5 + (up ? 1 : -1) * edge / 1.5));
    // Where the sun does not set, or does not rise, there is no dawn to pass through.
    if (half >= 12) { up = true; light = 1; progress = hour / 24; }
    if (half <= 0) { up = false; light = 0; progress = hour / 24; }
    var months = (now.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000 / 29.530588853;
    return { progress: Math.max(0, Math.min(1, progress)), light: light, phase: months - Math.floor(months), rise: rise, set: set };
}

// Short forms for the small capitals: "just now", "4 min", "2 h", "3 d".
function ago(ms) {
    var minutes = Math.max(0, Math.round(ms / 60000));
    if (minutes < 1) return "just now";
    if (minutes < 60) return minutes + " min";
    if (minutes < 60 * 36) return Math.round(minutes / 60) + " h";
    return Math.round(minutes / 1440) + " d";
}

// "48 min", "5 h 12 min", "2 h".
function lasting(ms) {
    var minutes = Math.max(0, Math.round(ms / 60000));
    if (minutes < 60) return minutes + " min";
    return Math.floor(minutes / 60) + " h" + (minutes % 60 ? " " + (minutes % 60) + " min" : "");
}

// "09:05".
function hourMinute(when) {
    var d = new Date(when);
    return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
}

// "2026-11-18", in local time: the name a day's record is kept under.
function dayKey(when) {
    var d = new Date(when);
    return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2);
}

// Where in the day a moment falls, 0 at midnight to 1 at the next.
function dayPart(when) {
    var d = new Date(when);
    return (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400;
}

// A day's record grows by what is on screen now. `spans` is
// [{from, to, desk, name}] in milliseconds; a desk shown again within a few
// minutes carries its span on, anything else starts a new one.
function noteSpan(spans, now, desk, name) {
    var next = spans.slice();
    var last = next[next.length - 1];
    if (last && last.desk === desk && last.name === name && now - last.to < 150000)
        next[next.length - 1] = { from: last.from, to: now, desk: desk, name: name };
    else
        next.push({ from: now, to: now, desk: desk, name: name });
    return next;
}

// What a day's record adds up to: {total, names: [{name, ms}], longest: {ms, from}}.
// Stretches are runs of spans with no more than a few minutes between them.
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

// The other desks in use, the one seen most recently first:
//   [{desk, name, count, urgent, seen}]
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

// Lyrics with their times ("[01:07.27] Caught in a landslide") as
// [{at: 67.27, text: "Caught in a landslide"}], in order. Lines with no
// words are kept: they are the rests.
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

// Which line is being sung at `position` seconds: the last one begun, or -1 before the first.
function lineAt(lines, position) {
    var at = -1;
    for (var i = 0; i < lines.length && lines[i].at <= position + 0.15; i++) at = i;
    return at;
}

// Of the answers a lyrics search gives, the one with timed words whose length is nearest the track's.
function bestLyrics(answers, length) {
    var best = null;
    (Array.isArray(answers) ? answers : []).forEach(function(a) {
        if (!a || !a.syncedLyrics) return;
        var off = length > 0 && a.duration > 0 ? Math.abs(a.duration - length) : 0;
        if (!best || off < best.off) best = { off: off, text: a.syncedLyrics };
    });
    return best && best.off <= 12 ? parseLyrics(best.text) : [];
}
