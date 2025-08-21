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

# Get current GitHub user account
get_current_user() {
    local user=$(gh api user --jq .login 2>/dev/null || echo "")
    if [ -z "$user" ]; then
        # Don't echo error message, just return failure
        return 1
    fi
    echo "$user"
    return 0
}

# Check if current user owns the repository or has write access
is_repo_owner() {
    local repo_name="$1"
    local current_origin=$(git remote get-url origin 2>/dev/null || echo "")
    
    # Extract username from origin URL
    if [[ "$current_origin" =~ github\.com[:/]([^/]+)/$repo_name ]]; then
        local repo_owner="${BASH_REMATCH[1]}"
        
        # Try to get GitHub CLI user first
        local gh_user=$(get_current_user)
        local gh_result=$?
        
        if [ $gh_result -eq 0 ] && [ "$gh_user" = "$repo_owner" ]; then
            return 0  # User owns the repo via GitHub CLI
        fi
        
        # If GitHub CLI fails, check if it's a personal fork (not ModelEarth/modelearth)
        if [[ "$repo_owner" != "ModelEarth" ]] && [[ "$repo_owner" != "modelearth" ]]; then
            return 0  # Likely a fork owned by the user
        fi
        
        # Special case: if pointing to ModelEarth repositories, assume user has access
        # (since they wouldn't have these repos cloned unless they have access)
        if [[ "$repo_owner" == "ModelEarth" ]]; then
            return 0  # Assume user has access to ModelEarth repositories
        fi
    fi
    
    return 1  # Not the owner or couldn't determine
}

# Clear git credentials and setup fresh authentication for current GitHub user
refresh_git_credentials() {
    local current_user="$1"
    
    echo "🔄 Refreshing git credentials for $current_user..."
    
    # Clear cached git credentials
    git credential-manager-core erase 2>/dev/null || true
    git credential erase 2>/dev/null || true
    
    # Clear macOS keychain git credentials
    if command -v security >/dev/null 2>&1; then
        security delete-internet-password -s github.com 2>/dev/null || true
    fi
    
    # Setup git to use GitHub CLI credentials
    gh auth setup-git
    
    echo "✅ Git credentials refreshed for $current_user"
}

# Store last known user in a temporary file for comparison
USER_CACHE_FILE="/tmp/git_sh_last_user"

# Check if current user has changed and update remotes accordingly
check_user_change() {
    local name="$1"
    
    # If user owns the repo, skip GitHub CLI requirement
    if is_repo_owner "$name"; then
        return 0  # User owns the repo, no need to update remotes
    fi
    
    # Try to get current user via GitHub CLI
    local current_user=$(get_current_user)
    if [ $? -ne 0 ] || [ -z "$current_user" ]; then
        # GitHub CLI not authenticated, but check if we can proceed without it
        local current_origin=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ "$current_origin" =~ github\.com[:/]([^/]+)/$name ]]; then
            local repo_owner="${BASH_REMATCH[1]}"
            if [[ "$repo_owner" != "ModelEarth" ]] && [[ "$repo_owner" != "modelearth" ]]; then
                echo "ℹ️ GitHub CLI not authenticated, but using existing fork remote"
                return 0
            elif [[ "$repo_owner" == "ModelEarth" ]] && [[ "$name" == "webroot" ]]; then
                echo "ℹ️ GitHub CLI not authenticated, but have access to ModelEarth/webroot"
                return 0
            fi
        fi
        echo "⚠️ GitHub CLI not authenticated and repository requires it for operations"
        return 1
    fi
    
    # Check if user has changed since last run
    local last_user=""
    if [ -f "$USER_CACHE_FILE" ]; then
        last_user=$(cat "$USER_CACHE_FILE" 2>/dev/null)
    fi
    
    # If user has changed, refresh git credentials
    if [ -n "$last_user" ] && [ "$last_user" != "$current_user" ]; then
        echo "👤 GitHub user changed from $last_user to $current_user"
        refresh_git_credentials "$current_user"
    fi
    
    # Store current user for next comparison
    echo "$current_user" > "$USER_CACHE_FILE"
    
    # Check current origin remote
    local current_origin=$(git remote get-url origin 2>/dev/null || echo "")
    local expected_origin="https://github.com/$current_user/$name.git"
    
    # If origin doesn't match current user, update it
    if [[ "$current_origin" != "$expected_origin" ]]; then
        echo "🔄 GitHub user changed to $current_user - updating origin remote..."
        git remote set-url origin "$expected_origin" 2>/dev/null || {
            echo "⚠️ Failed to update origin remote for $current_user"
            return 1
        }
        echo "🔧 Updated origin to point to $current_user/$name"
    fi
    return 0
}

# Create fork and update remote to user's fork
setup_fork() {
    local name="$1"
    local parent_account="$2"
    
    # If user already owns the repo, no need to fork
    if is_repo_owner "$name"; then
        echo "ℹ️ Already using user's repository, no fork needed"
        return 0
    fi
    
    local current_user=$(get_current_user)
    if [ $? -ne 0 ]; then
        echo "⚠️ Cannot create fork - GitHub CLI not authenticated"
        return 1
    fi
    
    echo "🍴 Creating fork of $parent_account/$name for $current_user..."
    
    # Create fork (gh handles case where fork already exists)
    local fork_url=$(gh repo fork "$parent_account/$name" --clone=false 2>/dev/null || echo "")
    
    if [ -n "$fork_url" ]; then
        echo "✅ Fork created/found: $fork_url"
        
        # Update origin to point to user's fork
        git remote set-url origin "$fork_url.git" 2>/dev/null || \
        git remote set-url origin "https://github.com/$current_user/$name.git"
        
        echo "🔧 Updated origin remote to point to $current_user fork"
        return 0
    else
        echo "⚠️ Failed to create/find fork for $current_user"
        return 1
    fi
}

# Update webroot submodule reference to point to user's fork
update_webroot_submodule_reference() {
    local name="$1"
    local commit_hash="$2"
    
    # Get current user login
    local user_login=$(get_current_user)
    if [ $? -ne 0 ]; then
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

# Fix detached HEAD state by merging into main branch
fix_detached_head() {
    local name="$1"
    
    # Check if we're in detached HEAD state
    local current_branch=$(git symbolic-ref -q HEAD 2>/dev/null || echo "")
    if [ -z "$current_branch" ]; then
        echo "⚠️ $name is in detached HEAD state - fixing..."
        
        # Get the current commit hash
        local detached_commit=$(git rev-parse HEAD)
        
        # Switch to main branch
        git checkout main 2>/dev/null || git checkout master 2>/dev/null || {
            echo "⚠️ No main/master branch found in $name"
            return 1
        }
        
        # Check if we need to merge the detached commit
        if ! git merge-base --is-ancestor "$detached_commit" HEAD; then
            echo "🔄 Merging detached commit $detached_commit into main branch"
            if git merge "$detached_commit" --no-edit 2>/dev/null; then
                echo "✅ Successfully merged detached HEAD in $name"
            else
                echo "⚠️ Merge conflicts in $name - manual resolution needed"
                return 1
            fi
        else
            echo "✅ Detached commit already in $name main branch"
        fi
    fi
    return 0
}

# Ensure all pending commits are pushed to origin
ensure_push_completion() {
    local name="$1"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        # Check if there are unpushed commits
        local unpushed=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        if [ "$unpushed" = "0" ]; then
            echo "✅ All commits pushed for $name"
            return 0
        fi
        
        echo "📤 Pushing $unpushed pending commits for $name..."
        
        # Try different push strategies
        if git push 2>/dev/null; then
            echo "✅ Successfully pushed $name"
            return 0
        elif git push origin HEAD:main 2>/dev/null; then
            echo "✅ Successfully pushed $name to main"
            return 0
        elif git push origin HEAD:master 2>/dev/null; then
            echo "✅ Successfully pushed $name to master"
            return 0
        elif git push --force-with-lease 2>/dev/null; then
            echo "✅ Force pushed $name with lease"
            return 0
        else
            ((retry_count++))
            echo "⚠️ Push attempt $retry_count failed for $name"
            if [ $retry_count -lt $max_retries ]; then
                echo "🔄 Retrying in 2 seconds..."
                sleep 2
            fi
        fi
    done
    
    echo "❌ Failed to push $name after $max_retries attempts"
    echo "💡 You may need to manually resolve this in GitHub Desktop"
    return 1
}

# Enhanced commit and push with automatic fork creation
commit_push() {
    local name="$1"
    local skip_pr="$2"
    
    # Fix detached HEAD before committing
    fix_detached_head "$name"
    
    # Check if there are changes to commit first
    if [ -n "$(git status --porcelain)" ]; then
        # Only check user change and update remotes when there are actual changes
        check_user_change "$name"
        git add .
        git commit -m "Update $name"
        local commit_hash=$(git rev-parse HEAD)
        
        # Determine target branch
        local target_branch="main"
        
        # Check if user owns the repository
        if is_repo_owner "$name"; then
            echo "✅ User owns $name repository - attempting direct push"
            # Try multiple push strategies for owned repositories
            local push_error=""
            if git push origin HEAD:$target_branch 2>/dev/null; then
                echo "✅ Successfully pushed $name to $target_branch branch"
                ensure_push_completion "$name"
                return 0
            elif git push origin $target_branch 2>/dev/null; then
                echo "✅ Successfully pushed $name to $target_branch"
                ensure_push_completion "$name"
                return 0
            elif push_error=$(git push 2>&1); then
                echo "✅ Successfully pushed $name"
                ensure_push_completion "$name"
                return 0
            else
                # Check for specific OAuth workflow scope error
                if [[ "$push_error" == *"workflow"* ]] && [[ "$push_error" == *"OAuth"* ]]; then
                    echo "🔒 GitHub OAuth token lacks 'workflow' scope for updating GitHub Actions"
                    echo "💡 To fix this, run: gh auth refresh -h github.com -s workflow"
                    echo "💡 Then retry the commit command"
                    return 1
                else
                    echo "⚠️ Push failed for owned repository $name with error:"
                    echo "$push_error"
                    echo "💡 Trying force push with lease..."
                    if git push --force-with-lease 2>/dev/null; then
                        echo "✅ Force pushed $name"
                        ensure_push_completion "$name"
                        return 0
                    else
                        echo "❌ All push strategies failed for owned repo $name"
                        return 1
                    fi
                fi
            fi
        else
            echo "🔒 User does not own $name repository - trying fork workflow"
            # Try to push directly first in case we have access
            if git push origin HEAD:$target_branch 2>/dev/null; then
                echo "✅ Successfully pushed $name to $target_branch branch"
                ensure_push_completion "$name"
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
                        ensure_push_completion "$name"
                    else
                        # Force push if normal push fails
                        echo "🔄 Normal push failed, trying force push..."
                        if git push --force-with-lease origin HEAD:$target_branch 2>/dev/null; then
                            echo "✅ Force pushed $name to your fork"
                            ensure_push_completion "$name"
                        else
                            echo "⚠️ Failed to push $name to fork"
                            return 1
                        fi
                    fi
                    
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
                    if [[ "$name" != "webroot" ]] && [[ "$name" != "exiobase" ]] && [[ "$name" != "profile" ]] && [[ "$name" != "io" ]]; then
                        update_webroot_submodule_reference "$name" "$commit_hash"
                    fi
                else
                    echo "⚠️ Failed to push to fork"
                fi
            elif [[ "$skip_pr" != "nopr" ]]; then
                # Other push failure - try feature branch PR
                git push origin HEAD:feature-$name-updates 2>/dev/null && \
                gh pr create --title "Update $name" --body "Automated update" --base $target_branch --head feature-$name-updates 2>/dev/null || \
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
    for sub in cloud comparison feed home localsite products projects realitystream swiper team trade; do
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
    
    # Check for and fix any detached HEAD states after updates
    echo "🔍 Checking for detached HEAD states after update..."
    fix_all_detached_heads
    
    # Update trade repos
    echo "📥 Updating trade repos..."
    for repo in exiobase profile io; do
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

# Check and fix detached HEAD states in all repositories
fix_all_detached_heads() {
    echo "🔍 Checking for detached HEAD states in all repositories..."
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    local fixed_count=0
    
    # Check webroot
    echo "📁 Checking webroot..."
    if fix_detached_head "webroot"; then
        ((fixed_count++))
    fi
    
    # Check all submodules
    echo "📁 Checking submodules..."
    for sub in cloud comparison feed home localsite products projects realitystream swiper team trade; do
        if [ -d "$sub" ]; then
            echo "📁 Checking $sub..."
            cd "$sub"
            if fix_detached_head "$sub"; then
                ((fixed_count++))
            fi
            cd ..
        fi
    done
    
    # Check trade repos
    echo "📁 Checking trade repos..."
    for repo in exiobase profile io; do
        if [ -d "$repo" ]; then
            echo "📁 Checking $repo..."
            cd "$repo"
            if fix_detached_head "$repo"; then
                ((fixed_count++))
            fi
            cd ..
        fi
    done
    
    if [ $fixed_count -gt 0 ]; then
        echo "✅ Fixed detached HEAD states in $fixed_count repositories"
        echo "💡 You may want to run './git.sh commit' to update submodule references"
    else
        echo "✅ No detached HEAD states found"
    fi
}

# Check and update all remotes for current GitHub user
update_all_remotes_for_user() {
    echo "🔄 Updating all remotes for current GitHub user..."
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    local current_user=$(get_current_user)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    echo "👤 Current GitHub user: $current_user"
    local updated_count=0
    
    # Check webroot
    echo "📁 Checking webroot remotes..."
    if check_user_change "webroot"; then
        ((updated_count++))
    fi
    
    # Check all submodules
    echo "📁 Checking submodule remotes..."
    for sub in cloud comparison feed home localsite products projects realitystream swiper team trade; do
        if [ -d "$sub" ]; then
            echo "📁 Checking $sub remotes..."
            cd "$sub"
            if check_user_change "$sub"; then
                ((updated_count++))
            fi
            cd ..
        fi
    done
    
    # Check trade repos
    echo "📁 Checking trade repo remotes..."
    for repo in exiobase profile io; do
        if [ -d "$repo" ]; then
            echo "📁 Checking $repo remotes..."
            cd "$repo"
            if check_user_change "$repo"; then
                ((updated_count++))
            fi
            cd ..
        fi
    done
    
    if [ $updated_count -gt 0 ]; then
        echo "✅ Updated remotes for $updated_count repositories to $current_user"
    else
        echo "✅ All remotes already point to $current_user"
    fi
}

# Create PR for webroot to its parent
create_webroot_pr() {
    local skip_pr="$1"
    
    if [[ "$skip_pr" == "nopr" ]]; then
        return 0
    fi
    
    # Get webroot remote URLs
    local origin_url=$(git remote get-url origin 2>/dev/null || echo "")
    local upstream_url=$(git remote get-url upstream 2>/dev/null || echo "")
    
    # Extract parent account from upstream or determine from origin
    local parent_account=""
    if [[ "$upstream_url" == *"ModelEarth/webroot"* ]]; then
        parent_account="ModelEarth"
    elif [[ "$upstream_url" == *"partnertools/webroot"* ]]; then
        parent_account="partnertools"
    elif [[ "$origin_url" != *"ModelEarth/webroot"* ]] && [[ "$origin_url" != *"partnertools/webroot"* ]]; then
        # This is likely a fork, default to ModelEarth as parent
        parent_account="ModelEarth"
    else
        # Already pointing to parent, no PR needed
        return 0
    fi
    
    echo "📝 Creating webroot PR to $parent_account/webroot..."
    
    # Get current user login for head specification
    local user_login=$(get_current_user)
    local head_spec="main"
    if [ $? -eq 0 ] && [ -n "$user_login" ]; then
        head_spec="$user_login:main"
    else
        echo "⚠️ Could not determine current user for PR creation"
        return 1
    fi
    
    local pr_url=$(gh pr create \
        --title "Update webroot with submodule changes" \
        --body "Automated webroot update from git.sh commit workflow - includes submodule reference updates and configuration changes" \
        --base main \
        --head "$head_spec" \
        --repo "$parent_account/webroot" 2>/dev/null || echo "")
    
    if [ -n "$pr_url" ]; then
        echo "🔄 Created webroot PR: $pr_url"
    else
        echo "⚠️ Webroot PR creation failed or not needed"
    fi
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
            
            # Try to push webroot changes
            if git push 2>/dev/null; then
                echo "✅ Updated $name submodule reference"
            else
                echo "🔄 Webroot push failed for $name - attempting PR workflow"
                create_webroot_pr "$skip_pr"
            fi
        fi
        
        # Check if we need to create a webroot PR (for when webroot push succeeded but we want PR anyway)
        local webroot_commits_ahead=$(git rev-list --count upstream/main..HEAD 2>/dev/null || echo "0")
        if [[ "$webroot_commits_ahead" -gt "0" ]] && [[ "$skip_pr" != "nopr" ]]; then
            create_webroot_pr "$skip_pr"
        fi
        
        # Final push completion check
        echo "🔍 Checking for remaining unpushed commits..."
        final_push_completion_check
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
    for sub in cloud comparison feed home localsite products projects realitystream swiper team trade; do
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
    
    # Final push completion check
    echo "🔍 Checking for remaining unpushed commits..."
    final_push_completion_check
}

# Complete commit workflow
commit_all() {
    local skip_pr="$1"
    
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    # Commit webroot changes
    commit_push "webroot" "$skip_pr"
    
    # Check if webroot needs PR after direct changes
    local webroot_commits_ahead=$(git rev-list --count upstream/main..HEAD 2>/dev/null || echo "0")
    if [[ "$webroot_commits_ahead" -gt "0" ]] && [[ "$skip_pr" != "nopr" ]]; then
        create_webroot_pr "$skip_pr"
    fi
    
    # Commit all submodules
    commit_submodules "$skip_pr"
    
    # Commit trade repos
    for repo in exiobase profile io; do
        [ ! -d "$repo" ] && continue
        cd "$repo"
        commit_push "$repo" "$skip_pr"
        cd ..
    done
    
    # Final push completion check for all repositories
    echo "🔍 Checking for any remaining unpushed commits..."
    final_push_completion_check
    
    echo "✅ Complete commit finished!"
}

# Check all repositories for unpushed commits and push them
final_push_completion_check() {
    cd $(git rev-parse --show-toplevel)
    
    # Check webroot
    if [ -n "$(git rev-list --count @{u}..HEAD 2>/dev/null)" ] && [ "$(git rev-list --count @{u}..HEAD 2>/dev/null)" != "0" ]; then
        echo "📤 Found unpushed commits in webroot..."
        ensure_push_completion "webroot"
    fi
    
    # Check all submodules
    for sub in cloud comparison feed home localsite products projects realitystream swiper team trade; do
        if [ -d "$sub" ]; then
            cd "$sub"
            if [ -n "$(git rev-list --count @{u}..HEAD 2>/dev/null)" ] && [ "$(git rev-list --count @{u}..HEAD 2>/dev/null)" != "0" ]; then
                echo "📤 Found unpushed commits in $sub..."
                ensure_push_completion "$sub"
            fi
            cd ..
        fi
    done
    
    # Check trade repos
    for repo in exiobase profile io; do
        if [ -d "$repo" ]; then
            cd "$repo"
            if [ -n "$(git rev-list --count @{u}..HEAD 2>/dev/null)" ] && [ "$(git rev-list --count @{u}..HEAD 2>/dev/null)" != "0" ]; then
                echo "📤 Found unpushed commits in $repo..."
                ensure_push_completion "$repo"
            fi
            cd ..
        fi
    done
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
    "fix-heads"|"fix")
        fix_all_detached_heads
        ;;
    "update-remotes"|"remotes")
        update_all_remotes_for_user
        ;;
    "refresh-auth"|"auth")
        current_user=$(get_current_user)
        if [ $? -eq 0 ]; then
            refresh_git_credentials "$current_user"
            update_all_remotes_for_user
        fi
        ;;
    *)
        echo "Usage: ./git.sh [update|commit|fix|remotes|auth] [submodule_name|submodules] [nopr]"
        echo ""
        echo "Commands:"
        echo "  ./git.sh update                    - Run comprehensive update workflow"
        echo "  ./git.sh commit                    - Commit webroot, all submodules, and trade repos"
        echo "  ./git.sh commit [name]             - Commit specific submodule"
        echo "  ./git.sh commit submodules         - Commit all submodules only"
        echo "  ./git.sh fix                       - Check and fix detached HEAD states in all repos"
        echo "  ./git.sh remotes                   - Update all remotes to current GitHub user"
        echo "  ./git.sh auth                      - Refresh git credentials for current GitHub user"
        echo ""
        echo "Options:"
        echo "  nopr                               - Skip PR creation on push failures"
        exit 1
        ;;
esac

# Always return to webroot repository root at the end. Webroot may have different names for each user who forks and clones it.
cd $(git rev-parse --show-toplevel)