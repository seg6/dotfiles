function clone --description "Clone a git repository"
    set --local target $argv[1]
    if string match -q "meyer*" -- $target
        set --local repo (string replace -r '^meyer/' '' -- $target)
        git clone meyer:MeyerSoundLaboratoriesInc/$repo $argv[2..-1]
    else
        git clone seg6:$target $argv[2..-1]
    end
end
