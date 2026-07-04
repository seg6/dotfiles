if command -q brew
    brew shellenv | source
end

if status is-interactive
    set fish_cursor_default block
    set fish_cursor_insert block

    fish_vi_key_bindings

    if command -q eza
        alias ls 'eza'
        alias ll 'eza -la --git'
        alias la 'eza -a'
        alias tree 'eza --tree'
    end

    if command -q git
        abbr -a g git
        abbr -a gs 'git status --short --branch'
        abbr -a gd 'git diff'
        abbr -a gds 'git diff --staged'
        abbr -a ga 'git add'
        abbr -a gaa 'git add --all'
        abbr -a gc 'git commit -s'
        abbr -a gca 'git commit -s --amend'
        abbr -a gp 'git push'
        abbr -a gpf 'git push --force-with-lease'
        abbr -a gl 'git log --oneline --decorate --graph --all'
        abbr -a gb 'git branch'
        abbr -a gsw 'git switch'
        abbr -a grb 'git rebase'
        abbr -a gri 'git rebase -i'
        abbr -a grc 'git rebase --continue'
        abbr -a gra 'git rebase --abort'
        abbr -a lg lazygit
    end

    if command -q nvm
        nvm use 24 >/dev/null 2>&1
    end
end

function fish_user_key_bindings
    bind -M insert \es 'ws; commandline -f repaint'
    bind \es 'ws; commandline -f repaint'
end

if command -q direnv
    direnv hook fish | source
end

if command -q zoxide
    zoxide init fish | source
end
