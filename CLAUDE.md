# CLAUDE.md

## Start server or Restart server

nohup python -m http.server 8887 > /dev/null 2>&1 &

Note: Uses nohup to run server in background and redirect output to avoid timeout.

### Update all submodules:
```bash
# Navigate to webroot first
cd $(git rev-parse --show-toplevel)
git submodule update --remote --recursive
```

### Deploy all submodules:
```bash
git submodule foreach 'git add . && git commit -m "Deploy updates" && (git push origin main || git push origin master)'
```
**Note**: This only pushes to individual submodules. It does NOT update the upstream parent repository with new submodule references. Use individual "commit [submodule name]" or "PR [submodule name]" for complete workflows.

### PR [submodule name]:
Create a pull request for a submodule when you lack collaborator privileges:
```bash
cd [submodule name]
git add . && git commit -m "Description of changes"
git push origin feature-branch-name
gh pr create --title "Update [submodule name]" --body "Description of changes"
cd ..
```

## Submodule Management

This repository contains the following git submodules configured in `.gitmodules`:
- **localsite** - https://github.com/ModelEarth/localsite
- **feed** - https://github.com/modelearth/feed  
- **swiper** - https://github.com/modelearth/swiper
- **home** - https://github.com/ModelEarth/home
- **products** - https://github.com/modelearth/products
- **comparison** - https://github.com/modelearth/comparison
- **team** - https://github.com/modelearth/team
- **projects** - https://github.com/modelearth/projects
- **realitystream** - https://github.com/modelearth/realitystream
- **cloud** - https://github.com/modelearth/cloud

**IMPORTANT**: All directories listed above are git submodules, not regular directories. They appear as regular directories when browsing but are actually git submodule references. Always treat them as submodules in git operations.

### Repository Root Navigation
**CRITICAL**: Always ensure you're in the webroot repository before executing any commands. The CLI session is pointed to the webroot directory, and all operations must start from there:

```bash
# ALWAYS navigate to webroot repository root first (required for all operations)
cd $(git rev-parse --show-toplevel)

# Verify you're in the correct webroot repository
git remote -v
# Should show: origin https://github.com/ModelEarth/webroot.git

# If git rev-parse returns the wrong repository (submodule/trade repo), manually navigate to webroot
# Use your system's webroot path, never hardcode paths in documentation
```

**IMPORTANT FILE PATH POLICY**: 
- **NEVER hardcode specific file paths** from any user's computer in code or documentation
- **NEVER include paths like `/Users/username/` or `C:\Users\`** in any commands or examples
- Always use relative paths, environment variables, or git commands to determine paths dynamically
- Use `$(git rev-parse --show-toplevel)` when already in the correct repository context
- If `git rev-parse --show-toplevel` returns incorrect paths (submodule/trade repo instead of webroot), the user must manually navigate to their webroot directory using their system's actual path

**IMPORTANT**: The `git rev-parse --show-toplevel` command returns the top-level directory of whatever git repository you're currently in. If you're inside a submodule or trade repo, it will return that repository's root instead of the webroot. In such cases, you must manually navigate to your actual webroot directory location on your system.

**Common Issue**: If submodule commands fail or you get "pathspec did not match" errors, you're likely in a submodule directory instead of the webroot. Navigate back to your webroot directory using your system's actual webroot path before running any commands.

### IMPORTANT: "commit [name]" Command Requirements
When a user says "commit [name]", use this intelligent fallback strategy with automatic PR creation:

**Strategy: Try submodule → Try repo → Fallback to webroot (with PR fallback)**
```bash
# Step 0: ALWAYS navigate to webroot first and detect no-PR flag
cd $(git rev-parse --show-toplevel)
SKIP_PR=false
if [[ "$*" =~ (nopr|no\ pr)$ ]] || [[ "$*" =~ (NOPR|NO\ PR)$ ]]; then
  SKIP_PR=true
fi

# Step 1: Try to commit as submodule first
if git submodule foreach --recursive 'if [ "$name" = "[name]" ]; then git add . && git commit -m "Update [name]" && (git push origin HEAD:main || echo "PUSH_FAILED"); fi' | grep -q "Update [name]"; then
  # Check if push failed and create PR if needed
  if git submodule foreach --recursive 'if [ "$name" = "[name]" ] && [ "$SKIP_PR" != "true" ]; then git log --oneline -1 | grep -q "Update [name]" && git push origin HEAD:main 2>/dev/null || (git push origin HEAD:feature-[name]-updates 2>/dev/null && gh pr create --title "Update [name] submodule" --body "Automated update from webroot integration" --base main --head feature-[name]-updates || echo "PR creation failed"); fi'; then
    echo "🔄 Created PR for [name] submodule due to permission restrictions"
  fi
  
  # Update parent repository
  git submodule update --remote [name]
  if git add [name] && git commit -m "Update [name] submodule"; then
    if git push; then
      echo "✅ Successfully committed [name] submodule"
    elif [ "$SKIP_PR" != "true" ]; then
      git push origin HEAD:feature-webroot-[name]-update && gh pr create --title "Update [name] submodule reference" --body "Update submodule reference for [name]" --base main --head feature-webroot-[name]-update || echo "Webroot PR creation failed"
      echo "🔄 Created PR for webroot [name] submodule reference"
    fi
  fi
  
# Step 2: If not a submodule, try as standalone repository
elif [ -d "[name]" ] && [ -d "[name]/.git" ]; then
  cd [name]
  if [ -n "$(git status --porcelain)" ]; then
    git add .
    git commit -m "Update [name] repository"
    if git push origin main; then
      echo "✅ Successfully committed [name] repository"
    elif [ "$SKIP_PR" != "true" ]; then
      git push origin HEAD:feature-[name]-updates && gh pr create --title "Update [name]" --body "Automated update from webroot integration" --base main --head feature-[name]-updates || echo "PR creation failed"
      echo "🔄 Created PR for [name] repository due to permission restrictions"
    fi
  else
    echo "No changes to commit in [name] repository"
  fi
  cd $(git rev-parse --show-toplevel)
  
# Step 3: Fallback to webroot repository
else
  if [ -n "$(git status --porcelain)" ]; then
    git add .
    git commit -m "Update webroot repository"
    if git push; then
      echo "✅ Successfully committed webroot repository (fallback)"
    elif [ "$SKIP_PR" != "true" ]; then
      git push origin HEAD:feature-webroot-updates && gh pr create --title "Update webroot" --body "Automated webroot update" --base main --head feature-webroot-updates || echo "PR creation failed"
      echo "🔄 Created PR for webroot repository due to permission restrictions"
    fi
  else
    echo "No changes to commit in webroot repository"
  fi
fi
```

**Direct Commit Method (if foreach strategy fails):**

Used when the `git submodule foreach` strategy fails, such as:
- **Detached HEAD state**: Submodule is not on a proper branch
- **Corrupted submodule**: `.git` folder or configuration is damaged
- **Branch conflicts**: Submodule is on a different branch than expected
- **Nested submodules**: Complex submodule hierarchies that confuse foreach
- **Permission issues**: File system permissions prevent git operations within submodules

**⚠️ IMPORTANT**: Do not initialize new submodules unless explicitly requested by the user. If a directory exists but is not properly initialized as a submodule, treat it as a standalone repository or ignore it rather than converting it to a submodule.

```bash
# Step 0: ALWAYS start from webroot
cd $(git rev-parse --show-toplevel)

# Direct submodule commit (when foreach method doesn't work)
cd [submodule name]
git checkout main  # Ensure on main branch (fixes detached HEAD)
git add . && git commit -m "Description of changes"
if git push origin main; then
  echo "✅ Successfully pushed [submodule name] submodule"
elif [ "$SKIP_PR" != "true" ]; then
  git push origin HEAD:feature-[submodule name]-direct && gh pr create --title "Update [submodule name] submodule" --body "Direct update of [submodule name] submodule" --base main --head feature-[submodule name]-direct || echo "PR creation failed"
  echo "🔄 Created PR for [submodule name] submodule due to permission restrictions"
fi

# Return to webroot and update submodule reference
cd $(git rev-parse --show-toplevel)
git submodule update --remote [submodule name]
git add [submodule name]
git commit -m "Update [submodule name] submodule" 
if git push; then
  echo "✅ Successfully updated [submodule name] submodule reference"
elif [ "$SKIP_PR" != "true" ]; then
  git push origin HEAD:feature-webroot-[submodule name]-ref && gh pr create --title "Update [submodule name] submodule reference" --body "Update submodule reference for [submodule name]" --base main --head feature-webroot-[submodule name]-ref || echo "Webroot PR creation failed"
  echo "🔄 Created PR for webroot [submodule name] submodule reference"
fi
```

**⚠️ CRITICAL**: 
- **NEW**: Automatic PR creation when push permissions are denied
- **NEW**: 'nopr' or 'No PR' (case insensitive) flag to skip PR creation
- **NEW**: All commit commands include PR fallback for permission failures
- **NEW**: Intelligent fallback strategy handles unrecognized names gracefully
- **NEW**: Three-tier approach: submodule → standalone repo → webroot fallback
- **NEW**: Always checks for actual changes before committing
- **NEW**: Provides clear success/failure feedback with ✅ and 🔄 indicators
- **NEVER initialize new submodules unless explicitly requested by user**
- **NEVER convert existing directories to submodules automatically**
- Method 1 handles detached HEAD states automatically
- Both methods require updating the parent repository
- If git submodule foreach fails, the submodule may not exist or be corrupted
- Always check status first to see which submodules actually have changes
- Use conditional `if [ "$name" = "submodule" ]` to target specific submodule and avoid "nothing to commit" errors from clean submodules
- The `--recursive` flag ensures nested submodules are handled properly
- Requires GitHub CLI (gh) for PR creation functionality

### Quick Commands for Repositories
- **"commit [name] [nopr]"**: Intelligent commit with PR fallback - tries submodule → standalone repo → webroot fallback
- **"push [submodule name]"**: Only push submodule changes (steps 1-3)
- **"PR [submodule name]"**: Create pull request workflow
- **"commit submodules [nopr]"**: Commit all submodules with PR fallback when push fails
- **"commit forks [nopr]"**: Commit all trade repo forks and create PRs to parent repos
- **"commit [nopr]"**: Complete commit workflow with PR fallback - commits webroot, all submodules, and all forks

**PR Fallback Behavior**: All commit commands automatically create pull requests when direct push fails due to permission restrictions. Add 'nopr' or 'No PR' (case insensitive) at the end of any commit command to skip PR creation.

When displaying "Issue Resolved" use the same checkbox icon as "Successfully Updated"

### Additional Notes
- Allow up to 12 minutes to pull repos (large repositories)
- Always verify both submodule AND parent repository are updated

## Git Commit Guidelines
- **NEVER add Claude Code attribution or co-authored-by lines to commits**
- **NEVER add "🤖 Generated with [Claude Code]" or similar footers**
- Keep commit messages clean and focused on the actual changes
- Include a brief summary of changes in the commit text

## Comprehensive Update Command

### Update
When you type "Update", run this comprehensive update workflow that pulls from all parent repos, updates submodules and forks, and prompts for pushes:

```bash
update
```

The above executes this comprehensive update workflow:
```bash
# CRITICAL: Navigate to webroot repository root first (never use hardcoded paths)
cd $(git rev-parse --show-toplevel)

# Verify we're in webroot - if not, user must manually navigate to their webroot directory
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null)
if [[ ! "$CURRENT_REMOTE" =~ "webroot" ]]; then
  echo "⚠️ ERROR: Not in webroot repository. Please manually navigate to your webroot directory first."
  echo "Current repository: $CURRENT_REMOTE"
  exit 1
fi

echo "🔄 Starting comprehensive update workflow from webroot..."

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
  if ! git remote | grep -q upstream; then
    git remote add upstream https://github.com/ModelEarth/webroot.git
  fi
  
  # Fetch and merge from upstream
  git fetch upstream
  git merge upstream/main --no-edit || echo "⚠️ Merge conflicts in webroot - manual resolution needed"
fi

# Step 2: Update all submodules from their respective ModelEarth parent repos
echo "📥 Updating submodules from their ModelEarth parents..."
git submodule foreach '
  echo "Updating submodule: $name"
  CURRENT_REMOTE=$(git remote get-url origin)
  
  # Skip partnertools repos
  if [[ "$CURRENT_REMOTE" =~ "partnertools" ]]; then
    echo "⚠️ Skipping partnertools submodule: $name"
  else
    # Add upstream remote for ModelEarth parent if it doesnt exist
    if ! git remote | grep -q upstream; then
      # Determine the correct parent repo URL
      if [[ "$name" == "localsite" ]] || [[ "$name" == "home" ]]; then
        git remote add upstream https://github.com/ModelEarth/$name.git
      else
        git remote add upstream https://github.com/modelearth/$name.git
      fi
    fi
    
    # Fetch and merge from upstream
    git fetch upstream 2>/dev/null || git fetch upstream
    git merge upstream/main --no-edit 2>/dev/null || git merge upstream/master --no-edit 2>/dev/null || echo "⚠️ Merge conflicts in $name - manual resolution needed"
  fi
'

# Step 3: Update webroot submodule references
echo "🔄 Updating webroot submodule references..."
git submodule update --remote --recursive
if [ -n "$(git status --porcelain)" ]; then
  echo "✅ Submodule references updated in webroot"
else
  echo "✅ All submodule references already up to date"
fi

# Step 4: Update trade repo forks from their ModelEarth parents
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
      # Add upstream remote for ModelEarth parent if it doesnt exist
      if ! git remote | grep -q upstream; then
        git remote add upstream https://github.com/modelearth/$repo.git
      fi
      
      # Fetch and merge from upstream parent
      git fetch upstream
      git merge upstream/main --no-edit || echo "⚠️ Merge conflicts in $repo - manual resolution needed"
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
echo "🔹 Webroot: If you have changes in your webroot fork, push to your fork and create PR to ModelEarth/webroot"
echo "   Commands: git add . && git commit -m \"Merge updates from upstream\" && git push origin main"
echo "   Then: gh pr create --title \"Update from upstream\" --body \"Merge latest changes from ModelEarth/webroot\""
echo ""
echo "🔹 Submodules: If submodules have changes, push to their respective parent repos"
echo "   Use: commit submodules (to push all) or commit [submodule-name] (for specific ones)"
echo ""
echo "🔹 Trade Repos: If trade repos have changes, push to your forks and create PRs to ModelEarth parents"
echo "   Use: commit forks (to push all trade repos and create PRs)"
echo ""
echo "🔹 Complete Push: To push everything at once:"
echo "   Use: commit (pushes webroot, all submodules, and all forks with PR creation)"
echo ""
echo "⚠️ NOTE: None of these operations involve partnertools repositories - they are intentionally excluded"
```

**Update Command Features:**
- **Pull from Parents**: Updates webroot, submodules, and trade repos from their respective ModelEarth parent repositories
- **Fork-Aware**: Automatically adds upstream remotes for parent repos when working with forks
- **Partnertools Exclusion**: Completely skips any repositories associated with partnertools GitHub account
- **Merge Strategy**: Uses automatic merge with no-edit to incorporate upstream changes
- **Conflict Handling**: Reports merge conflicts for manual resolution when they occur  
- **Status Reporting**: Provides clear feedback on what was updated and any issues encountered
- **Push Guidance**: Prompts user with specific commands for pushing changes back to forks and parent repos
- **Comprehensive Workflow**: Handles webroot, all submodules, and all trade repositories in one command

**Post-Update Recommendations:**
After running "Update", review changes and use these commands as needed:
- `commit` - Push all changes (webroot + submodules + forks) with PR creation
- `commit submodules` - Push only submodule changes  
- `commit forks` - Push only trade repo fork changes with PRs
- `commit [specific-name]` - Push changes for a specific repository

## Quick Commands

When you type "restart", run this single command to restart the server in seconds:
```bash
cd $(git rev-parse --show-toplevel) && pkill -f "node.*index.js"; (cd server && NODE_ENV=production nohup node index.js > /dev/null 2>&1 &)
```

When you type "quick", add the following permissions block to setting.local.json under allow. "
When you type "confirm" or "less quick", remove it:
```json
[
  "Bash(yarn setup)",
  "Bash(npx update-browserslist-db:*)",
  "Bash(mkdir:*)",
  "Bash(yarn build)",
  "Bash(cp:*)",
  "Bash(npx prisma generate:*)",
  "Bash(npx prisma migrate:*)",
  "Bash(pkill:*)",
  "Bash(curl:*)",
  "Bash(git submodule add:*)",
  "Bash(rm:*)",
  "Bash(find:*)",
  "Bash(ls:*)",
  "Bash(git add:*)",
  "Bash(git commit:*)",
  "Bash(git push:*)"
]
```

## Trade Repositories

### Trade Repo List
The following trade repositories are used for multi-regional input-output (MRIO) analysis:
- **exiobase** - https://github.com/modelearth/exiobase
- **profile** - https://github.com/modelearth/profile  
- **useeio.js** - https://github.com/modelearth/useeio.js
- **io** - https://github.com/modelearth/io

**IMPORTANT**: These trade repos are cloned to the webroot root directory, not as submodules, since typical sites only use trade output via the existing comparison submodule.

### Fork Trade Repos

```bash
fork trade repos to [your github account]
```

The above runs these commands:
```bash
# Fork repositories using GitHub CLI (requires 'gh' to be installed and authenticated)
gh repo fork modelearth/exiobase --clone=false
gh repo fork modelearth/profile --clone=false
gh repo fork modelearth/useeio.js --clone=false
gh repo fork modelearth/io --clone=false
```

### Clone Trade Repos

```bash
clone trade repos from [your github account]
```

The above runs these commands:
```bash
# Navigate to webroot repository root first
cd $(git rev-parse --show-toplevel)

# Clone trade repos to webroot root
git clone https://github.com/[your github account]/exiobase exiobase
git clone https://github.com/[your github account]/profile profile
git clone https://github.com/[your github account]/useeio.js useeio.js
git clone https://github.com/[your github account]/io io
```

### Commit All Submodules

```bash
commit submodules [nopr]
```

The above commits changes to all submodules that have uncommitted changes:
```bash
# Navigate to webroot repository root first and detect no-PR flag
cd $(git rev-parse --show-toplevel)
SKIP_PR=false
if [[ "$*" =~ (nopr|no\ pr)$ ]] || [[ "$*" =~ (NOPR|NO\ PR)$ ]]; then
  SKIP_PR=true
fi

# Check which submodules have changes first
git submodule foreach 'git status'

# Commit all submodules that have changes with PR fallback
git submodule foreach --recursive '
  if [ -n "$(git status --porcelain)" ]; then
    git add .
    git commit -m "Update $name submodule"
    if git push origin HEAD:main; then
      echo "✅ Successfully pushed $name submodule"
    elif [ "$SKIP_PR" != "true" ]; then
      git push origin HEAD:feature-$name-updates && gh pr create --title "Update $name submodule" --body "Automated submodule update from webroot" --base main --head feature-$name-updates || echo "PR creation failed for $name"
      echo "🔄 Created PR for $name submodule due to permission restrictions"
    fi
  fi
'

# Update parent repository with submodule references
git submodule update --remote
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git commit -m "Update submodule references"
  if git push; then
    echo "✅ Successfully updated webroot submodule references"
  elif [ "$SKIP_PR" != "true" ]; then
    git push origin HEAD:feature-webroot-submodule-updates && gh pr create --title "Update submodule references" --body "Automated update of all submodule references" --base main --head feature-webroot-submodule-updates || echo "Webroot PR creation failed"
    echo "🔄 Created PR for webroot submodule references due to permission restrictions"
  fi
fi
```

### Commit Trade Repo Forks

```bash
commit forks [nopr]
```

The above commits changes to all trade repo forks and creates pull requests to their parent repositories:
```bash
# Navigate to webroot repository root first and detect no-PR flag
cd $(git rev-parse --show-toplevel)
SKIP_PR=false
if [[ "$*" =~ (nopr|no\ pr)$ ]] || [[ "$*" =~ (NOPR|NO\ PR)$ ]]; then
  SKIP_PR=true
fi

# Check each trade repo for changes and create PRs
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
      
      # Only create PR for forks (when you don't have direct push access to parent)
      if [ "$SKIP_PR" != "true" ]; then
        # Check if this is a fork by comparing remote URL with expected parent
        REMOTE_URL=$(git remote get-url origin)
        if [[ "$REMOTE_URL" =~ "modelearth/$repo" ]] && ! [[ "$REMOTE_URL" =~ "ModelEarth/$repo" ]]; then
          gh pr create --title "Update $repo" --body "Automated update from webroot integration" --base main --head main || echo "PR creation failed for $repo"
          echo "🔄 Created PR for $repo fork to parent repository"
        else
          echo "✅ Direct push succeeded - no PR needed for $repo"
        fi
      fi
    fi
    cd ..
  fi
done
```

**Note**: This command requires GitHub CLI (gh) to be installed and authenticated for PR creation. It will create PRs for all trade repo forks unless 'nopr' is specified. Use 'commit forks nopr' to skip PR creation.

**Common Issues:**
- **Repository moved errors**: Update remote URLs if you see "This repository moved" messages:
  ```bash
  cd [repo-name]
  git remote set-url origin [new-url]
  ```
- **GitHub CLI authentication**: Run `gh auth login` to authenticate with GitHub before using PR features

### Complete Commit Workflow

```bash
commit [nopr]
```

The above runs a comprehensive commit workflow that handles webroot, all submodules, and all trade repo forks with automatic PR creation:

```bash
# Navigate to webroot repository root first and detect no-PR flag
cd $(git rev-parse --show-toplevel)
SKIP_PR=false
if [[ "$*" =~ (nopr|no\ pr)$ ]] || [[ "$*" =~ (NOPR|NO\ PR)$ ]]; then
  SKIP_PR=true
fi

# Step 1: Commit webroot repository changes
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git commit -m "Update webroot repository"
  if git push; then
    echo "✅ Successfully committed webroot repository"
  elif [ "$SKIP_PR" != "true" ]; then
    git push origin HEAD:feature-webroot-comprehensive-update && gh pr create --title "Comprehensive webroot update" --body "Automated comprehensive update of webroot repository" --base main --head feature-webroot-comprehensive-update || echo "Webroot PR creation failed"
    echo "🔄 Created PR for webroot repository due to permission restrictions"
  fi
fi

# Step 2: Commit all submodules that have changes
git submodule foreach '
  if [ -n "$(git status --porcelain)" ]; then
    git add .
    git commit -m "Update $name submodule"
    if git push origin HEAD:main; then
      echo "✅ Successfully pushed $name submodule"
    elif [ "$SKIP_PR" != "true" ]; then
      git push origin HEAD:feature-$name-comprehensive-updates && gh pr create --title "Update $name submodule" --body "Automated submodule update from comprehensive commit" --base main --head feature-$name-comprehensive-updates || echo "PR creation failed for $name"
      echo "🔄 Created PR for $name submodule due to permission restrictions"
    fi
  fi
'

# Step 3: Update parent repository with submodule references
git submodule update --remote
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git commit -m "Update submodule references"
  if git push; then
    echo "✅ Successfully updated webroot submodule references"
  elif [ "$SKIP_PR" != "true" ]; then
    git push origin HEAD:feature-webroot-submodule-comprehensive && gh pr create --title "Update all submodule references" --body "Comprehensive update of all submodule references" --base main --head feature-webroot-submodule-comprehensive || echo "Submodule reference PR creation failed"
    echo "🔄 Created PR for webroot submodule references due to permission restrictions"
  fi
fi

# Step 4: Commit trade repo forks and create PRs
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
      
      # Only create PR for forks (when you don't have direct push access to parent)
      if [ "$SKIP_PR" != "true" ]; then
        # Check if this is a fork by comparing remote URL with expected parent
        REMOTE_URL=$(git remote get-url origin)
        if [[ "$REMOTE_URL" =~ "modelearth/$repo" ]] && ! [[ "$REMOTE_URL" =~ "ModelEarth/$repo" ]]; then
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
```

**Note**: This is the most comprehensive commit command that handles all repository types in the webroot ecosystem with automatic PR fallback when push permissions are denied. Use 'commit nopr' to skip all PR creation. It will only process repositories that have actual changes.
