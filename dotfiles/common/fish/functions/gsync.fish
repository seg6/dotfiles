function gsync --description "Fetch and rebase the current branch onto its upstream"
    set --local branch (git branch --show-current)
    if test -z "$branch"
        echo "gsync: not on a branch" >&2
        return 1
    end

    git fetch --prune
    git rebase "@{upstream}"
end
