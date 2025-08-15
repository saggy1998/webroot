#!/bin/bash

# git.sh - Centralized git operations for webroot repository
# Usage: ./git.sh [command] [options]

set -e  # Exit on any error

# Helper function to check if we're in webroot
check_webroot() {
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null)
    if [[ "$CURRENT_REMOTE" != *"webroot"* ]]; then
        echo "⚠️ ERROR: Not in webroot repository. Please navigate to your webroot directory first."
        echo "Current repository: $CURRENT_REMOTE"
        exit 1
    fi
}

# Update command - comprehensive update workflow
update_command() {
    echo "🔄 Starting comprehensive update workflow from webroot..."
    
    # Navigate to webroot repository root first
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    # Step 1: Pull any remote changes in current webroot first
    echo "📥 Pulling latest changes from webroot remote..."
    git pull origin main || echo "⚠️ Pull conflicts in webroot - manual resolution needed"
    
    # Step 2: Update webroot from parent ModelEarth/webroot repository (if this is a fork)
    echo "📥 Updating webroot from parent ModelEarth/webroot..."
    WEBROOT_REMOTE=$(git remote get-url origin)
    if [[ "$WEBROOT_REMOTE" =~ "partnertools" ]]; then
        echo "⚠️ Skipping partnertools webroot - not updating from parent"
    else
        # Add upstream if it doesn't exist (for forks)
        if [ -z "$(git remote | grep upstream)" ]; then
            git remote add upstream https://github.com/ModelEarth/webroot.git
        fi
        
        # Fetch and merge from upstream
        git fetch upstream
        git merge upstream/main --no-edit || echo "⚠️ Merge conflicts in webroot - manual resolution needed"
    fi
    
    # Step 3: Update all submodules from their respective ModelEarth parent repos
    echo "📥 Updating submodules from their ModelEarth parents..."
    for submodule in cloud comparison feed home localsite products projects realitystream swiper team; do
        if [ -d "$submodule" ]; then
            cd "$submodule"
            echo "Updating submodule: $submodule"
            
            CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null)
            
            # Skip partnertools repos
            if [[ "$CURRENT_REMOTE" =~ "partnertools" ]]; then
                echo "⚠️ Skipping partnertools submodule: $submodule"
            else
                # Add upstream remote for ModelEarth parent if it doesn't exist
                if [ -z "$(git remote | grep upstream)" ]; then
                    # Determine the correct parent repo URL
                    if [[ "$submodule" == "localsite" ]] || [[ "$submodule" == "home" ]]; then
                        git remote add upstream https://github.com/ModelEarth/$submodule.git
                    else
                        git remote add upstream https://github.com/modelearth/$submodule.git
                    fi
                fi
                
                # Fetch and merge from upstream
                git fetch upstream 2>/dev/null || git fetch upstream
                git merge upstream/main --no-edit 2>/dev/null || git merge upstream/master --no-edit 2>/dev/null || git merge upstream/dev --no-edit 2>/dev/null || echo "⚠️ Merge conflicts in $submodule - manual resolution needed"
            fi
            cd ..
        else
            echo "⚠️ Submodule not found: $submodule"
        fi
    done
    
    # Step 4: Update webroot submodule references
    echo "🔄 Updating webroot submodule references..."
    git submodule update --remote --recursive
    if [ -n "$(git status --porcelain)" ]; then
        echo "✅ Submodule references updated in webroot"
    else
        echo "✅ All submodule references already up to date"
    fi
    
    # Step 5: Update trade repo forks from their ModelEarth parents
    echo "📥 Updating trade repo forks from ModelEarth parents..."
    for repo in exiobase profile useeio.js io; do
        if [ -d "$repo" ]; then
            cd "$repo"
            echo "Updating trade repo: $repo"
            
            # First pull any remote changes from origin
            echo "📥 Pulling latest changes from $repo remote..."
            git pull origin main || echo "⚠️ Pull conflicts in $repo - manual resolution needed"
            
            TRADE_REMOTE=$(git remote get-url origin)
            # Skip partnertools repos
            if [[ "$TRADE_REMOTE" =~ "partnertools" ]]; then
                echo "⚠️ Skipping partnertools trade repo: $repo"
            else
                # Add upstream remote for ModelEarth parent if it doesn't exist
                if [ -z "$(git remote | grep upstream)" ]; then
                    git remote add upstream https://github.com/modelearth/$repo.git
                fi
                
                # Fetch and merge from upstream parent
                git fetch upstream
                git merge upstream/main --no-edit || git merge upstream/master --no-edit || git merge upstream/dev --no-edit || echo "⚠️ Merge conflicts in $repo - manual resolution needed"
            fi
            cd ..
        else
            echo "⚠️ Trade repo not found: $repo"
        fi
    done
    
    echo "✅ Update workflow completed!"
    echo ""
    echo "📤 PUSH RECOMMENDATIONS:"
    echo "Review the changes and consider pushing your updates:"
    echo ""
    echo "🔹 Use: ./git.sh commit (pushes webroot, all submodules, and all forks with PR creation)"
}

# Commit submodule command
commit_submodule() {
    local submodule_name="$1"
    local skip_pr="$2"
    
    echo "Committing submodule: $submodule_name"
    
    # Navigate to webroot repository root first
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    # Check if it's a submodule or standalone repo
    if [ -d "$submodule_name" ]; then
        cd "$submodule_name"
        if [ -n "$(git status --porcelain)" ]; then
            git add .
            git commit -m "Update $submodule_name"
            if git push origin HEAD:main; then
                echo "✅ Successfully pushed $submodule_name"
            elif [[ "$skip_pr" != "nopr" ]]; then
                git push origin HEAD:feature-$submodule_name-updates && gh pr create --title "Update $submodule_name submodule" --body "Automated update from webroot integration" --base main --head feature-$submodule_name-updates || echo "PR creation failed"
                echo "🔄 Created PR for $submodule_name due to permission restrictions"
            fi
        else
            echo "No changes to commit in $submodule_name"
        fi
        
        # Return to webroot and update submodule reference
        cd ..
        git submodule update --remote "$submodule_name"
        if git add "$submodule_name" && git commit -m "Update $submodule_name submodule"; then
            if git push; then
                echo "✅ Successfully updated $submodule_name submodule reference"
            elif [[ "$skip_pr" != "nopr" ]]; then
                git push origin HEAD:feature-webroot-$submodule_name-ref && gh pr create --title "Update $submodule_name submodule reference" --body "Update submodule reference for $submodule_name" --base main --head feature-webroot-$submodule_name-ref || echo "Webroot PR creation failed"
                echo "🔄 Created PR for webroot $submodule_name submodule reference"
            fi
        fi
    else
        echo "⚠️ Submodule/repo not found: $submodule_name"
    fi
}

# Commit all submodules
commit_submodules() {
    local skip_pr="$1"
    
    echo "Committing all submodules with changes..."
    
    # Navigate to webroot repository root first
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    # Commit all submodules that have changes
    for submodule in cloud comparison feed home localsite products projects realitystream swiper team; do
        if [ -d "$submodule" ]; then
            cd "$submodule"
            if [ -n "$(git status --porcelain)" ]; then
                git add .
                git commit -m "Update $submodule submodule"
                if git push origin HEAD:main; then
                    echo "✅ Successfully pushed $submodule submodule"
                elif [[ "$skip_pr" != "nopr" ]]; then
                    git push origin HEAD:feature-$submodule-updates && gh pr create --title "Update $submodule submodule" --body "Automated submodule update from webroot" --base main --head feature-$submodule-updates || echo "PR creation failed for $submodule"
                    echo "🔄 Created PR for $submodule submodule due to permission restrictions"
                fi
            fi
            cd ..
        fi
    done
    
    # Update parent repository with submodule references
    git submodule update --remote
    if [ -n "$(git status --porcelain)" ]; then
        git add .
        git commit -m "Update submodule references"
        if git push; then
            echo "✅ Successfully updated webroot submodule references"
        elif [[ "$skip_pr" != "nopr" ]]; then
            git push origin HEAD:feature-webroot-submodule-updates && gh pr create --title "Update submodule references" --body "Automated update of all submodule references" --base main --head feature-webroot-submodule-updates || echo "Webroot PR creation failed"
            echo "🔄 Created PR for webroot submodule references due to permission restrictions"
        fi
    fi
}

# Complete commit workflow
commit_all() {
    local skip_pr="$1"
    
    echo "Running complete commit workflow..."
    
    # Navigate to webroot repository root first
    cd $(git rev-parse --show-toplevel)
    check_webroot
    
    # Step 1: Commit webroot repository changes
    if [ -n "$(git status --porcelain)" ]; then
        git add .
        git commit -m "Update webroot repository"
        if git push; then
            echo "✅ Successfully committed webroot repository"
        elif [[ "$skip_pr" != "nopr" ]]; then
            git push origin HEAD:feature-webroot-comprehensive-update && gh pr create --title "Comprehensive webroot update" --body "Automated comprehensive update of webroot repository" --base main --head feature-webroot-comprehensive-update || echo "Webroot PR creation failed"
            echo "🔄 Created PR for webroot repository due to permission restrictions"
        fi
    fi
    
    # Step 2: Commit all submodules
    commit_submodules "$skip_pr"
    
    # Step 3: Commit trade repo forks
    for repo in exiobase profile useeio.js io; do
        if [ -d "$repo" ]; then
            cd "$repo"
            if [ -n "$(git status --porcelain)" ]; then
                git add .
                git commit -m "Update $repo repository"
                if git push origin main; then
                    echo "✅ Successfully pushed $repo repository"
                else
                    echo "⚠️ Push failed for $repo repository"
                fi
                
                # Only create PR for forks
                if [[ "$skip_pr" != "nopr" ]]; then
                    REMOTE_URL=$(git remote get-url origin)
                    if [[ "$REMOTE_URL" =~ "modelearth/$repo" ]] && [[ "$REMOTE_URL" != *"ModelEarth/$repo"* ]]; then
                        gh pr create --title "Update $repo" --body "Automated update from comprehensive webroot commit" --base main --head main || echo "PR creation failed for $repo"
                        echo "🔄 Created PR for $repo fork to parent repository"
                    else
                        echo "✅ Direct push succeeded - no PR needed for $repo"
                    fi
                fi
            fi
            cd ..
        fi
    done
    
    echo "✅ Complete commit workflow finished!"
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