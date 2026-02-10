function clone --description "Clone a git repository"
    if test (count $argv) -lt 1
        echo "usage: clone repository [git-clone-options]" >&2
        return 2
    end

    git clone seg6:$argv[1] $argv[2..-1]
end
