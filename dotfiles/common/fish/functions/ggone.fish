function ggone --description "Delete local branches whose upstream is gone"
    set --local branches (git branch -vv | string match -r '^\s*[^*].*\[.*: gone\]' | string replace -r '^\s*(\S+).*' '$1')
    if test (count $branches) -eq 0
        echo "ggone: no gone branches"
        return 0
    end

    printf '%s\n' $branches
    read --local --prompt-str 'delete these branches? [y/N] ' confirm
    if test "$confirm" = y -o "$confirm" = Y
        git branch -d $branches
    end
end
