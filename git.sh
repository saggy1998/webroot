#!/bin/bash

# git.sh - Streamlined git operations for webroot repository
# Usage: ./git.sh [command] [options]

set -e  # Exit on any error

# Helper function to check if we're in webroot
check_webroot() {
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$CURRENT_REMOTE" != *"webroot"* ]]; then
        echo "⚠️ ERROR: Not in webroot repository."
        exit 1
    fi
}

# Add upstream remote if it doesn't exist
add_upstream() {
    local repo_name="$1"
    local is_capital="$2"
    
    if [ -z "$(git remote | grep upstream)" ]; then
        if [[ "$is_capital" == "true" ]]; then
            git remote add upstream "https://github.com/ModelEarth/$repo_name.git"
        else
            git remote add upstream "https://github.com/modelearth/$repo_name.git"
        fi
    fi
}

# Merge from upstream with fallback branches
merge_upstream() {
    local repo_name="$1"
    git fetch upstream 2>/dev/null || git fetch upstream
    
    # Try main/master first for all repos
    if git merge upstream/main --no-edit 2>/dev/null; then
        return 0
    elif git merge upstream/master --no-edit 2>/dev/null; then
        return 0
    # Only try dev branch for useeio.js
    elif [[ "$repo_name" == "useeio.js" ]] && git merge upstream/dev --no-edit 2>/dev/null; then
        return 0
    else
        echo "⚠️ Merge conflicts - manual resolution needed"
        return 1
    fi
}

# Commit and push with PR fallback
commit_push() {
    local name="$1"
    local skip_pr="$2"
    
    if [ -n "$(git status --porcelain)" ]; then
        git add .
        git commit -m "Update $name"
        
        # Special case: push useeio.js to dev branch
        if [[ "$name" == "useeio.js" ]]; then
            if git push origin HEAD:dev 2>/dev/null; then
                echo "✅ Successfully pushed $name to dev branch"
            elif [[ "$skip_pr" != "nopr" ]]; then
                git push origin HEAD:feature-$name-updates 2>/dev/null && \
                gh pr create --title "Update $name" --body "Automated update" --base dev --head feature-$name-updates 2>/dev/null || \
                echo "🔄 PR creation failed for $name"
            fi
        else
            # Standard behavior: push to main branch
            if git push origin HEAD:main 2>/dev/null; then
                echo "✅ Successfully pushed $name"
            elif [[ "$skip_pr" != "nopr" ]]; then
                git push origin HEAD:feature-$name-updates 2>/dev/null && \
                gh pr create --title "Update $name" --body "Automated update" --base main --head feature-$name-updates 2>/dev/null || \
                echo "🔄 PR creation failed for $name"
            fi
        fi
    fi
}

# Update command - streamlined update workflow  
update_command() {
    echo "🔄 Starting update workflow..."
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    # Update webroot
    echo "📥 Updating webroot..."
    git pull origin main 2>/dev/null || echo "⚠️ Pull conflicts in webroot"
    
    # Update webroot from parent (skip partnertools)
    WEBROOT_REMOTE=$(git remote get-url origin)
    if [[ "$WEBROOT_REMOTE" != *"partnertools"* ]]; then
        add_upstream "webroot" "true"
        merge_upstream "webroot"
    fi
    
    # Update submodules
    echo "📥 Updating submodules..."
    for sub in cloud comparison feed home localsite products projects realitystream swiper team; do
        [ ! -d "$sub" ] && continue
        cd "$sub"
        
        REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ "$REMOTE" != *"partnertools"* ]]; then
            if [[ "$sub" == "localsite" ]] || [[ "$sub" == "home" ]]; then
                add_upstream "$sub" "true"
            else
                add_upstream "$sub" "false" 
            fi
            merge_upstream "$sub"
        fi
        cd ..
    done
    
    # Update submodule references
    echo "🔄 Updating submodule references..."
    git submodule update --remote --recursive
    
    # Update trade repos
    echo "📥 Updating trade repos..."
    for repo in exiobase profile useeio.js io; do
        [ ! -d "$repo" ] && continue
        cd "$repo"
        git pull origin main 2>/dev/null || echo "⚠️ Pull conflicts in $repo"
        
        REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ "$REMOTE" != *"partnertools"* ]]; then
            add_upstream "$repo" "false"
            merge_upstream "$repo"
        fi
        cd ..
    done
    
    echo "✅ Update completed! Use: ./git.sh commit"
}

# Commit specific submodule
commit_submodule() {
    local name="$1"
    local skip_pr="$2"
    
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    if [ -d "$name" ]; then
        cd "$name"
        commit_push "$name" "$skip_pr"
        
        # Update webroot submodule reference
        cd ..
        git submodule update --remote "$name"
        if [ -n "$(git status --porcelain | grep $name)" ]; then
            git add "$name"
            git commit -m "Update $name submodule reference"
            git push 2>/dev/null || echo "🔄 Webroot push failed for $name"
            echo "✅ Updated $name submodule reference"
        fi
    else
        echo "⚠️ Repository not found: $name"
    fi
}

# Commit all submodules
commit_submodules() {
    local skip_pr="$1"
    
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    # Commit each submodule with changes
    for sub in cloud comparison feed home localsite products projects realitystream swiper team; do
        [ ! -d "$sub" ] && continue
        cd "$sub"
        commit_push "$sub" "$skip_pr"
        cd ..
    done
    
    # Update webroot submodule references
    git submodule update --remote
    if [ -n "$(git status --porcelain)" ]; then
        git add .
        git commit -m "Update submodule references"
        git push 2>/dev/null || echo "🔄 Webroot push failed"
        echo "✅ Updated submodule references"
    fi
}

# Complete commit workflow
commit_all() {
    local skip_pr="$1"
    
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    # Commit webroot changes
    commit_push "webroot" "$skip_pr"
    
    # Commit all submodules
    commit_submodules "$skip_pr"
    
    # Commit trade repos
    for repo in exiobase profile useeio.js io; do
        [ ! -d "$repo" ] && continue
        cd "$repo"
        commit_push "$repo" "$skip_pr"
        cd ..
    done
    
    echo "✅ Complete commit finished!"
}

# Main command dispatcher
case "$1" in
    "update")
        update_command
        ;;
    "commit")
        if [ "$2" = "submodules" ]; then
            commit_submodules "$3"
        elif [ -n "$2" ]; then
            commit_submodule "$2" "$3"
        else
            commit_all "$2"
        fi
        ;;
    *)
        echo "Usage: ./git.sh [update|commit] [submodule_name|submodules] [nopr]"
        echo ""
        echo "Commands:"
        echo "  ./git.sh update                    - Run comprehensive update workflow"
        echo "  ./git.sh commit                    - Commit webroot, all submodules, and trade repos"
        echo "  ./git.sh commit [name]             - Commit specific submodule"
        echo "  ./git.sh commit submodules         - Commit all submodules only"
        echo ""
        echo "Options:"
        echo "  nopr                               - Skip PR creation on push failures"
        exit 1
        ;;
esac