function gria --description "Interactive rebase with autosquash from a selected base commit"
    set --local selected (git log --format='%h %s' --max-count=50 | fzf --no-sort --prompt='rebase from> ')
    set --local commit (string split --max 1 ' ' -- $selected)[1]
    if test -z "$commit"
        return 0
    end

    git rebase -i --autosquash "$commit^"
end
