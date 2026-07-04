function gfixup --description "Create a fixup commit for a selected recent commit"
    set --local selected (git log --format='%h %s' --max-count=50 | fzf --no-sort --prompt='fixup> ')
    set --local commit (string split --max 1 ' ' -- $selected)[1]
    if test -z "$commit"
        return 0
    end

    git commit -s --fixup "$commit"
end
