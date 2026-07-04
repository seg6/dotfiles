function fish_prompt
    set -l last_status $status
    set -l dir (basename $PWD)

    echo -n " "

    if test $last_status -ne 0
        set_color red
        echo -n "×$last_status "
    end

    if set -q SSH_CONNECTION; or set -q SSH_TTY
        set_color cyan
        echo -n "ssh:"(prompt_hostname)" "
    end

    set_color normal
    echo -n "$dir"

    if command -q git; and git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l branch (git branch --show-current 2>/dev/null)
        if test -z "$branch"
            set branch (git rev-parse --short HEAD 2>/dev/null)
        end

        set -l dirty ""
        if test -n "$(git status --porcelain --ignore-submodules=dirty --untracked-files=normal 2>/dev/null)"
            set dirty "*"
        end

        set_color brblack
        echo -n " $branch$dirty"
    end

    echo -n " "
    switch $fish_bind_mode
        case insert
            set_color magenta
            echo -n "▄▀ "
        case '*'
            set_color magenta
            echo -n "▀▄ "
    end

    set_color normal
end
