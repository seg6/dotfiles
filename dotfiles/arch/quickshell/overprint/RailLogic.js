.pragma library

function workspaceNames(workspaces, output, occupied) {
    return workspaces.filter(function(workspace) {
        return workspace.monitor && workspace.monitor.name === output
            && (workspace.active || occupied.indexOf(workspace.name) !== -1);
    }).map(function(workspace) { return workspace.name; }).sort(function(a, b) {
        return a.localeCompare(b, undefined, { numeric: true });
    });
}

function occupiedWorkspaces(tree) {
    var names = [];
    function children(node) { return (node.nodes || []).concat(node.floating_nodes || []); }
    function hasWindow(node) {
        return !!(node.app_id || node.window) || children(node).some(hasWindow);
    }
    function visit(node) {
        if (node.type === "workspace") {
            if (node.name !== "__i3_scratch" && hasWindow(node)) names.push(node.name);
        } else children(node).forEach(visit);
    }
    visit(tree);
    return names;
}

// System applets get the rail's own line drawings. Applications keep their icons.
function traySymbol(item) {
    var id = String(item.id || "").toLowerCase();
    if (/nm-applet|networkmanager/.test(id)) return "network";
    if (/blueman|bluetooth/.test(id)) return "bluetooth";
    if (/pasystray|volume|pulseaudio/.test(id)) return "audio";
    if (/vpn/.test(id)) return "shield";
    return "";
}

// Electron apps all register as "<App>_status_icon_1" with an empty title.
function trayName(item) {
    var name = String(item.tooltipTitle || item.title || "").trim();
    if (!name) name = String(item.id || "").replace(/_status_icon_\d+$/, "").replace(/[-_.]+/g, " ").trim();
    return name || "application";
}

function trayTip(item) {
    var detail = String(item.tooltipDescription || "").trim();
    return trayName(item) + (detail && detail.indexOf("<") === -1 ? " · " + detail : "");
}

function trayInitials(item) {
    return trayName(item).slice(0, 2).toLocaleLowerCase();
}

function kittyBorderUpdates(tree) {
    var commands = [];
    function visit(node) {
        var app = String(node.app_id || (node.window_properties || {}).class || "").toLowerCase();
        if (app === "kitty" && Number.isInteger(node.id) && node.border !== "normal") {
            commands.push("[con_id=" + node.id + "] border normal 2");
        }
        // A tiled window that another layout gave a heading goes back to a plain frame.
        if (app && app !== "kitty" && Number.isInteger(node.id) && node.border === "normal" && node.type === "con") {
            commands.push("[con_id=" + node.id + "] border pixel 2");
        }
        (node.nodes || []).concat(node.floating_nodes || []).forEach(visit);
    }
    visit(tree);
    return commands;
}

// ISO 8601: weeks start on Monday and week 1 holds the year's first Thursday.
function isoWeek(date) {
    var day = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    day.setUTCDate(day.getUTCDate() + 4 - (day.getUTCDay() || 7));
    return Math.ceil(((day - Date.UTC(day.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
}

// The weeks that show a month, padded with its neighbours' days.
// firstDay is 0 for Sunday through 6 for Saturday.
function monthWeeks(year, month, firstDay, today) {
    var start = new Date(year, month, 1);
    start.setDate(1 - (start.getDay() - firstDay + 7) % 7);
    var weeks = [];
    while (weeks.length < 6) {
        var days = [];
        for (var i = 0; i < 7; i++) {
            var date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + weeks.length * 7 + i);
            days.push({
                day: date.getDate(),
                inMonth: date.getMonth() === month,
                today: date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() && date.getDate() === today.getDate()
            });
        }
        if (weeks.length >= 4 && !days[0].inMonth) break;
        // The week number belongs to the week's Thursday, wherever the week starts.
        var thursday = new Date(start.getFullYear(), start.getMonth(), start.getDate() + weeks.length * 7 + (4 - firstDay + 7) % 7);
        weeks.push({ week: isoWeek(thursday), days: days });
    }
    return weeks;
}
