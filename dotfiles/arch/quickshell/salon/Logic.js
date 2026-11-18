.pragma library

// Every window in the Sway tree, most recently focused first. Sway keeps each
// container's children in focus order, so following that order through the
// tree gives the order a window switcher wants.
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
                rect: node.rect || { x: 0, y: 0, width: 0, height: 0 },
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

// The windows of one workspace in the order they are laid out, so their
// buttons on the taskbar do not shuffle as focus moves.
function onWorkspace(list, workspace) {
    return list.filter(function(w) { return w.workspace === workspace; })
        .sort(function(a, b) { return a.id - b.id; });
}

function ago(then, now) {
    var seconds = Math.max(0, Math.round((now - then) / 1000));
    if (seconds < 60) return "now";
    if (seconds < 3600) return Math.floor(seconds / 60) + " min";
    if (seconds < 86400) return Math.floor(seconds / 3600) + " h";
    return Math.floor(seconds / 86400) + " d";
}

function duration(seconds) {
    seconds = Math.max(0, Math.floor(seconds || 0));
    var minutes = Math.floor(seconds / 60), rest = seconds % 60;
    return minutes + ":" + (rest < 10 ? "0" : "") + rest;
}

// Works hang without a heading. A window that arrives with one, from another
// layout, loses it; ones that draw their own frame ("csd") are left alone.
function frameUpdates(tree) {
    var commands = [];
    function visit(node) {
        var children = (node.nodes || []).concat(node.floating_nodes || []);
        if ((node.app_id || node.window) && children.length === 0 && node.border === "normal" && Number.isInteger(node.id))
            commands.push("[con_id=" + node.id + "] border pixel 3");
        children.forEach(visit);
    }
    visit(tree);
    return commands;
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

// Walls are numbered as plates are: I, II, III.
function roman(value) {
    var n = parseInt(value, 10);
    if (!(n > 0 && n < 4000)) return String(value);
    var out = "", marks = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
    marks.forEach(function(m) { while (n >= m[0]) { out += m[1]; n -= m[0]; } });
    return out;
}

var counts = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"];

function proper(name) {
    name = String(name || "").split(/[.\/]/).pop().replace(/[-_]+/g, " ").trim();
    return name ? name.charAt(0).toUpperCase() + name.slice(1) : "Untitled";
}

// What a wall's plaque says of the works on it: "Kitty, three works" or
// "Helium and Thunar".
function caption(list, workspace) {
    var works = list.filter(function(w) { return w.workspace === workspace; });
    if (works.length === 0) return "nothing hung";
    var names = [];
    works.forEach(function(w) { var n = proper(w.app); if (names.indexOf(n) === -1) names.push(n); });
    if (names.length === 1)
        return works.length === 1 ? names[0] : names[0] + ", " + (counts[works.length] || works.length) + " works";
    if (names.length === 2) return names[0] + " and " + names[1];
    return names[0] + ", " + names[1] + " and " + (counts[names.length - 2] || names.length - 2) + " more";
}

// Where the other walls hang around the one in view, as fractions of the
// screen: [x, y, width]. Pictures are 16:9; more walls than places go unhung.
var places = [
    [0.082, 0.185, 0.208], [0.710, 0.185, 0.208],
    [0.118, 0.484, 0.172], [0.710, 0.484, 0.172],
    [0.318, 0.660, 0.118], [0.564, 0.660, 0.118]
];

function hang(workspaces, current) {
    var others = workspaces.filter(function(w) { return w !== current; });
    return others.slice(0, places.length).map(function(name, i) {
        return { name: name, x: places[i][0], y: places[i][1], width: places[i][2] };
    });
}

// The moon tonight: 0 is new, 0.5 is full. Good to a few hours.
function moon(date) {
    var days = (date.getTime() / 86400000) - 10962.76; // since the new moon of 6 January 2000, 18:14 UTC
    var phase = (days / 29.530588853) % 1;
    return phase < 0 ? phase + 1 : phase;
}

// The quarters are moments; either side of them the moon is a crescent or gibbous.
function moonName(phase) {
    if (phase < 0.03 || phase > 0.97) return "New moon";
    if (phase < 0.22) return "Waxing crescent";
    if (phase < 0.28) return "First quarter";
    if (phase < 0.47) return "Waxing gibbous";
    if (phase < 0.53) return "Full moon";
    if (phase < 0.72) return "Waning gibbous";
    if (phase < 0.78) return "Last quarter";
    return "Waning crescent";
}
