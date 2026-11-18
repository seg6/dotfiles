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

function traySymbol(item) {
    var id = String(item.id || "").toLowerCase();
    if (/nm-applet|networkmanager/.test(id)) return "network";
    if (/blueman|bluetooth/.test(id)) return "bluetooth";
    if (/spotify/.test(id)) return "music";
    if (/1password|keepass/.test(id)) return "key";
    if (/pasystray|volume|pulseaudio/.test(id)) return "audio";
    if (/vpn/.test(id)) return "shield";
    if (/discord/.test(id)) return "chat";
    return "";
}

function trayInitials(item) {
    var name = String(item.title || String(item.id || "").split(/[.\/_-]/).pop() || "?");
    return name.slice(0, 2).toLocaleLowerCase();
}

function kittyBorderUpdates(tree) {
    var commands = [];
    function visit(node) {
        var app = String(node.app_id || (node.window_properties || {}).class || "").toLowerCase();
        if (app === "kitty" && Number.isInteger(node.id) && node.border !== "normal") {
            commands.push("[con_id=" + node.id + "] border normal 2");
        }
        (node.nodes || []).concat(node.floating_nodes || []).forEach(visit);
    }
    visit(tree);
    return commands;
}
