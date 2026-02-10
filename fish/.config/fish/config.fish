if status is-interactive
    set fish_cursor_default block
    set fish_cursor_insert block

    fish_vi_key_bindings
end

function fish_user_key_bindings
    bind -M insert \es 'ws pick; commandline -f repaint'
    bind \es 'ws pick; commandline -f repaint'
end

nvm use 22 > /dev/null
zoxide init fish | source
