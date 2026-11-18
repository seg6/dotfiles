"""Use Kitty's tab surface as a full-width application heading, including a single tab."""
import os
import runpy
from types import SimpleNamespace
from kitty.constants import config_dir
from kitty.fast_data_types import get_boss

header = runpy.run_path(os.path.join(config_dir, 'window_title_bar.py'))


def draw_tab(draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data):
    current = get_boss().tab_for_id(tab.tab_id)
    window = current.active_window if current else None
    width = screen.columns - screen.cursor.x if is_last else max_tab_length
    screen.cursor.bold = False
    screen.cursor.italic = False
    if window:
        data = SimpleNamespace(window_id=window.id, title=window.title)
        text = header['draw_window_title'](data, columns=width)
    else:
        text = tab.title[:width]
    screen.draw(text)
    return screen.cursor.x
