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
var names = { "helium": "Helium", "kitty": "Kitty", "com.anthropic.claude": "Claude", "org.gnome.nautilus": "Files", "thunar": "Thunar" };

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

// What the desktop has to say, as rich text. Words that name something
// elsewhere are links ("desk:7"). `waiting` lists what wants attention:
// [{name: "Discord", desk: "8", since: Date}].
function sentence(now, place, all, here, waiting) {
    var out = "It is " + spokenTime(now) + " on a " + weekdays[now.getDay()] + (place ? " in " + escape(place) : "") + ". ";
    var mine = all.filter(function(w) { return w.workspace === here; });
    var others = elsewhere(all, here);
    if (mine.length === 0) {
        out += all.length === 0 ? "Nothing is open." : "Nothing is open on this desk.";
    } else {
        var kinds = [];
        mine.forEach(function(w) {
            var found = kinds.filter(function(k) { return k.app === w.app; })[0];
            if (found) found.n++; else kinds.push({ app: w.app, n: 1 });
        });
        var things = list(kinds.map(function(k) { return several(k.app, k.n); }));
        out += things.charAt(0).toUpperCase() + things.slice(1) + (mine.length === 1 ? " is" : " are") + " open here.";
    }
    var waits = (waiting || []).filter(function(w) { return w.desk !== here; });
    var quiet = others.filter(function(o) { return !waits.some(function(w) { return w.desk === o.desk; }); });
    if (quiet.length > 0) {
        var total = quiet.reduce(function(sum, o) { return sum + o.n; }, 0);
        var linked = list(quiet.map(function(o) { return '<a href="desk:' + escape(o.desk) + '">' + escape(o.text) + '</a>'; }));
        out += " " + linked.replace(/^(<a [^>]*>)?([a-z])/, function(_, tag, letter) { return (tag || "") + letter.toUpperCase(); })
            + (total === 1 ? " is" : " are") + " elsewhere";
        out += waits.length > 0 ? ", and " : ".";
    } else if (waits.length > 0) {
        out += " ";
    }
    if (waits.length > 0) {
        var first = waits[0];
        var minutes = first.since ? Math.round((now - first.since) / 60000) : 0;
        var name = '<a href="desk:' + escape(first.desk) + '">' + escape(first.name) + '</a>';
        if (quiet.length === 0) name = name.replace(/>([a-z])/, function(_, letter) { return ">" + letter.toUpperCase(); });
        out += name + " <i>" + (minutes >= 2 ? "has been waiting " + count(minutes) + " minutes" : "wants you")
            + (waits.length > 1 ? ", and so " + (waits.length === 2 ? "does one other" : "do " + count(waits.length - 1) + " others") : "") + ".</i>";
    }
    return out;
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

// "3D 04H" from seconds.
function uptime(seconds) {
    var days = Math.floor(seconds / 86400), hours = Math.floor(seconds % 86400 / 3600), minutes = Math.floor(seconds % 3600 / 60);
    function two(n) { return (n < 10 ? "0" : "") + n; }
    return days > 0 ? days + "D " + two(hours) + "H" : hours + "H " + two(minutes) + "M";
}

function duration(seconds) {
    seconds = Math.max(0, Math.floor(seconds || 0));
    var minutes = Math.floor(seconds / 60), left = seconds % 60;
    return minutes + ":" + (left < 10 ? "0" : "") + left;
}
