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

# Detect parent repository account (modelearth or partnertools)
get_parent_account() {
    local repo_name="$1"
    
    # Check if upstream remote exists and points to expected parent
    local upstream_url=$(git remote get-url upstream 2>/dev/null || echo "")
    if [[ "$upstream_url" == *"modelearth/$repo_name"* ]]; then
        echo "modelearth"
    elif [[ "$upstream_url" == *"partnertools/$repo_name"* ]]; then
        echo "partnertools"
    else
        # Fallback: try to determine from typical parent structure
        if [[ "$repo_name" == "localsite" ]] || [[ "$repo_name" == "home" ]] || [[ "$repo_name" == "webroot" ]]; then
            echo "ModelEarth"  # Capital M for these repos
        else
            echo "modelearth"  # lowercase for others
        fi
    fi
}

# Create fork and update remote to user's fork
setup_fork() {
    local name="$1"
    local parent_account="$2"
    
    echo "🍴 Creating fork of $parent_account/$name..."
    
    # Create fork (gh handles case where fork already exists)
    local fork_url=$(gh repo fork "$parent_account/$name" --clone=false 2>/dev/null || echo "")
    
    if [ -n "$fork_url" ]; then
        echo "✅ Fork created/found: $fork_url"
        
        # Update origin to point to user's fork
        git remote set-url origin "$fork_url.git" 2>/dev/null || \
        git remote set-url origin "https://github.com/$(gh api user --jq .login)/$name.git"
        
        echo "🔧 Updated origin remote to point to your fork"
        return 0
    else
        echo "⚠️ Failed to create/find fork"
        return 1
    fi
}

# Update webroot submodule reference to point to user's fork
update_webroot_submodule_reference() {
    local name="$1"
    local commit_hash="$2"
    
    # Get current user login
    local user_login=$(gh api user --jq .login 2>/dev/null || echo "")
    if [ -z "$user_login" ]; then
        echo "⚠️ Could not determine GitHub username"
        return 1
    fi
    
    echo "🔄 Updating webroot submodule reference..."
    cd $(git rev-parse --show-toplevel)
    
    # Update .gitmodules to point to user's fork
    git config -f .gitmodules submodule.$name.url "https://github.com/$user_login/$name.git"
    
    # Sync the submodule URL change
    git submodule sync "$name"
    
    # Update submodule to point to the specific commit
    cd "$name"
    git checkout "$commit_hash" 2>/dev/null
    cd ..
    
    # Commit the submodule reference update
    if [ -n "$(git status --porcelain | grep -E "($name|\.gitmodules)")" ]; then
        git add "$name" .gitmodules
        git commit -m "Update $name submodule to point to $user_login fork (commit $commit_hash)"
        
        if git push origin main 2>/dev/null; then
            echo "✅ Updated webroot submodule reference to your fork"
        else
            echo "⚠️ Failed to push webroot submodule reference update"
        fi
    fi
}

# Enhanced commit and push with automatic fork creation
commit_push() {
    local name="$1"
    local skip_pr="$2"
    
    if [ -n "$(git status --porcelain)" ]; then
        git add .
        git commit -m "Update $name"
        local commit_hash=$(git rev-parse HEAD)
        
        # Determine target branch
        local target_branch="main"
        if [[ "$name" == "useeio.js" ]]; then
            target_branch="dev"
        fi
        
        # Try to push directly first
        if git push origin HEAD:$target_branch 2>/dev/null; then
            echo "✅ Successfully pushed $name to $target_branch branch"
            return 0
        fi
        
        # If direct push fails, check if it's a permission issue
        local push_output=$(git push origin HEAD:$target_branch 2>&1)
        if [[ "$push_output" == *"Permission denied"* ]] || [[ "$push_output" == *"403"* ]]; then
            echo "🔒 Permission denied - setting up fork workflow..."
            
            # Detect parent account
            local parent_account=$(get_parent_account "$name")
            echo "📍 Detected parent: $parent_account/$name"
            
            # Setup fork and update remote
            if setup_fork "$name" "$parent_account"; then
                # Try pushing to fork
                if git push origin HEAD:$target_branch 2>/dev/null; then
                    echo "✅ Successfully pushed $name to your fork"
                    
                    # Create PR if not skipped
                    if [[ "$skip_pr" != "nopr" ]]; then
                        echo "📝 Creating pull request..."
                        local pr_url=$(gh pr create \
                            --title "Update $name" \
                            --body "Automated update from git.sh commit workflow" \
                            --base $target_branch \
                            --head $target_branch \
                            --repo "$parent_account/$name" 2>/dev/null || echo "")
                        
                        if [ -n "$pr_url" ]; then
                            echo "🔄 Created PR: $pr_url"
                        else
                            echo "⚠️ PR creation failed for $name"
                        fi
                    fi
                    
                    # Update webroot submodule reference if this is a submodule
                    if [[ "$name" != "webroot" ]] && [[ "$name" != "exiobase" ]] && [[ "$name" != "profile" ]] && [[ "$name" != "useeio.js" ]] && [[ "$name" != "io" ]]; then
                        update_webroot_submodule_reference "$name" "$commit_hash"
                    fi
                    
                else
                    echo "⚠️ Failed to push to fork"
                fi
            fi
        elif [[ "$skip_pr" != "nopr" ]]; then
            # Other push failure - try feature branch PR
            git push origin HEAD:feature-$name-updates 2>/dev/null && \
            gh pr create --title "Update $name" --body "Automated update" --base $target_branch --head feature-$name-updates 2>/dev/null || \
            echo "🔄 PR creation failed for $name"
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

# Always return to webroot repository root at the end. Webroot may have different names for each user who forks and clones it.
cd $(git rev-parse --show-toplevel)