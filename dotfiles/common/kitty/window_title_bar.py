"""Overprint's native Kitty window header: foreground program and working folder."""
import os
import unicodedata


def clean(value):
    return ''.join(c for c in value if not unicodedata.category(c).startswith('C'))


def clip(value, width, measure, tail=False):
    if measure(value) <= width:
        return value
    if width < 2:
        return '…' if width else ''
    while value and measure(value) > width - 1:
        value = value[1:] if tail else value[:-1]
    return '…' + value if tail else value + '…'


def format_header(program, cwd, home, columns, measure):
    columns = max(0, columns)
    program, cwd = clean(program), clean(cwd)
    if cwd == home or cwd.startswith(home + '/'):
        cwd = '~' + cwd[len(home):]
    left = clip(program, max(0, columns // 3), measure)
    right = clip(cwd, max(0, columns - measure(left) - 4), measure, tail=True)
    gap = max(0, columns - measure(left) - measure(right) - 2)
    return clip(' ' + left + ' ' * gap + right + ' ', columns, measure)


def foreground_program(pid, fallback, proc_root="/proc"):
    # tmux reports the shell for some Fish jobs. Resolve its terminal's foreground
    # process group without spawning a shell on every header repaint.
    from pathlib import Path
    found = fallback
    try:
        stat = (Path(proc_root) / str(int(pid)) / 'stat').read_text().rsplit(')', 1)[1].split()
        foreground = stat[5]
        pending = [str(int(pid))]
        for _ in range(32):
            if not pending:
                break
            current = pending.pop(0)
            base = Path(proc_root) / current
            record = (base / 'stat').read_text().rsplit(')', 1)[1].split()
            if record[2] == foreground:
                found = (base / 'comm').read_text().strip()
                if found not in {'fish', 'bash', 'zsh', 'sh', 'dash', 'nu'}:
                    return found
            pending.extend((base / 'task' / current / 'children').read_text().split())
    except (OSError, ValueError, IndexError):
        pass
    return found


def draw_window_title(data, columns=None):
    from kitty.fast_data_types import get_boss, wcswidth
    window = get_boss().window_id_map.get(data.window_id)
    if window is None:
        return clean(data.title)
    program = os.path.basename(window.get_exe_of_child() or 'terminal')
    cwd = window.get_cwd_of_child() or ''
    if program.startswith('tmux') and ' · ' in data.title:
        program, _, cwd = data.title.partition(' · ')
        cwd, _, pid = cwd.rpartition(' · ')
        if pid.isdecimal():
            program = foreground_program(pid, program)
    program = {'hx': 'helix', 'bash': 'bash', 'felix': 'felix'}.get(program, program)
    return format_header(program, cwd, os.path.expanduser('~'), columns if columns is not None else window.screen.columns, wcswidth)
