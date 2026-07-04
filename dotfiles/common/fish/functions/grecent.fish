function grecent --description "Show recently changed local branches"
    git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:relative)%09%(refname:short)' | column -t -s 	
end
