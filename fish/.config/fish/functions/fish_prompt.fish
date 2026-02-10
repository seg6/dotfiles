function fish_prompt
    set -l dir (basename $PWD)
    echo -n " "

    set_color blue
    echo -n "$dir"

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
