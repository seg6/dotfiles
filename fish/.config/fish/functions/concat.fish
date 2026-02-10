function concat
    if test (count $argv) -ne 1
        return 1
    end

    set dir $argv[1]
    
    set extensions \
        "rs" "go" "js" "ts" "jsx" "tsx" "py" "rb" "java" "cpp" "cc" "c" \
        "hpp" "h" "cs" "php" "swift" "kt" "scala" "sh" "fish" "bash" "pl" \
        "ex" "exs" "erl" "ml" "hs" "lua" "r" "md" "txt" "yaml" "yml" "wit" \
        "json" "toml" "ini" "conf" "css" "scss" "sass" "html" "xml" "svg" \
        "Makefile" "svelte" "Caddyfile" "hcl" "vue" "sql" "ld" "nasm" "asm" \
        "justfile"

    set ignore_patterns \
        ".git" "node_modules" "target" "build" "dist" "venv" "__pycache__" ".DS_Store" \
        "*.pyc" "*.exe" "*.dll" "*.so" "*.dylib" "*.class" "*.o" "*.obj" \
        "*.bin" "*.dat" "*.db" "*.sqlite" "*.log" "*.lock" "*.sum" \
        ".Spotlight-V100" ".Trashes" "ehthumbs.db" "Thumbs.db"

    echo "# Project Structure"
    echo '```'
    tree -I (string join '|' $ignore_patterns) -a --dirsfirst $dir
    echo '```'
    echo

    echo "# File Contents"
    echo

    set ignore_args
    for pattern in $ignore_patterns
        set ignore_args $ignore_args --exclude $pattern
    end

    for ext in $extensions
        fd -e $ext . $dir $ignore_args --type f | while read -l file
            if file --mime-encoding $file | string match -q "*binary"
                continue
            end
            
            if test (stat -c %s $file) -gt 1048576
                echo "## File: $file (Skipped - too large)"
                continue
            end

            echo "## File: $file"
            echo '```'$ext
            cat $file
            echo '```'
            echo
        end
    end

    fd "LICENSE*" $dir $ignore_args --type f --glob | while read -l file
        if test (stat -c %s $file) -le 1048576
            echo "## File: $file"
            echo '```'
            cat $file
            echo '```'
            echo
        end
    end
end
