# CLAUDE.md

## Start server or Restart server

### Start Server
When you type "start server", run

```bash
nohup python -m http.server 8887 > /dev/null 2>&1 &
```

Note: Uses nohup to run server in background and redirect output to avoid timeout.


### Start Rust API Server
When you type "start rust", change to the team submodule directory in the repository root and run

```bash
cd team
# Ensure Rust is installed and cargo is in PATH
source ~/.cargo/env 2>/dev/null || echo "Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
# Copy .env.example to .env only if .env doesn't exist
[ ! -f .env ] && cp .env.example .env
# Start the server with correct binary name
nohup cargo run --bin partner_tools -- serve > server.log 2>&1 &
```

Note: The team repository is a submodule located in the repository root directory. The Rust API server runs on port 8081. Requires Rust/Cargo to be installed on the system. The .env file is created from .env.example only if it doesn't already exist.

### Update submodules:
When you type "update submodules", run
```bash
# Navigate to webroot first
cd $(git rev-parse --show-toplevel)
git submodule update --remote --recursive
```

### Commit submodules:
When you type "commit submodules", run
```bash
./git.sh commit submodules [nopr]
```
**Note**: This commits all submodules with changes AND updates the webroot parent repository with new submodule references. Includes automatic PR creation on push failures.

### PR [submodule name]:
Create a pull request for a submodule when you lack collaborator privileges:
```bash
cd [submodule name]
git add . && git commit -m "Description of changes"
git push origin feature-branch-name
gh pr create --title "Update [submodule name]" --body "Description of changes"
cd ..
```

## IMPORTANT: Git Commit Policy

**NEVER commit changes without explicit user request.** 

- Only run git commands (add, commit, push) when the user specifically says "commit" or directly requests it
- After making code changes, STOP and wait for user instruction
- Build and test changes as needed, but do not commit automatically
- The user controls when changes are committed to the repository

## Comprehensive Update Command

### Update
When you type "Update", run this comprehensive update workflow that pulls from all parent repos, updates submodules and forks, and prompts for pushes:

```bash
./git.sh update
```

All complex git operations are now handled by the git.sh script to avoid shell parsing issues.

### GitHub Account Management
The git.sh script automatically detects the current GitHub CLI user and adapts accordingly:

```bash
gh auth logout                    # Log out of current GitHub account
gh auth login                     # Log into different GitHub account
./git.sh auth                     # Refresh git credentials and update all remotes
```

When you switch GitHub accounts, the script will:
- **Automatically detect** the new user during commit/update operations
- **Clear cached git credentials** from previous account
- **Refresh authentication** to use new GitHub CLI credentials  
- **Update remote URLs** to point to the new user's forks
- **Create PRs** from the new user's account
- **Fork repositories** to the new user's account when needed

**Automatic Credential Management:**
- Detects when GitHub user has changed since last run
- Clears cached credentials from credential manager and macOS keychain
- Runs `gh auth setup-git` to sync git with GitHub CLI
- Prevents permission denied errors from stale credentials

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
After running "./git.sh update", review changes and use these commands as needed:
- `./git.sh commit` - Push all changes (webroot + submodules + forks) with PR creation
- `./git.sh commit submodules` - Push only submodule changes  
- `./git.sh commit [specific-name]` - Push changes for a specific repository

**Git.sh Usage:**
```bash
./git.sh update                    # Full update workflow  
./git.sh commit                    # Complete commit: webroot, all submodules, and trade repos
./git.sh commit [name]             # Commit specific submodule
./git.sh commit submodules         # Commit all submodules only
./git.sh commit [name] nopr        # Skip PR creation on push failures
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

### Upstream Repository Policy

**CRITICAL**: The maximum upstream level for all repositories is `modelearth` - never pull from higher upstream sources like USEPA.

- **Webroot and Submodules**: Upstream should point to `modelearth` or `ModelEarth` repositories only
- **Trade Repositories**: Upstream should point to `modelearth` repositories only  
- **NEVER use USEPA** as upstream sources in any repository
- **Repository Hierarchy**: `user-fork` → `modelearth` (STOP - do not go higher)

**Example Correct Upstream Configuration:**
```bash
# Correct upstream configuration
git remote add upstream https://github.com/modelearth/useeio.js.git
git remote add upstream https://github.com/ModelEarth/webroot.git

# WRONG - never use these upstream sources
git remote add upstream https://github.com/USEPA/useeio.js.git  # ❌ NEVER
```

**Update Workflow Impact:**
- The `./git.sh update` command respects this policy and only pulls from modelearth-level repositories
- If any upstream is incorrectly configured to point above modelearth level, it must be corrected
- This prevents conflicts from pulling changes from repositories outside the modelearth ecosystem

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
When a user says "commit [name]", use the git.sh script:

```bash
./git.sh commit [name] [nopr]
```

The git.sh script handles all the complex logic including:
- Submodule detection and committing
- Automatic PR creation on push failures  
- Webroot submodule reference updates
- Support for 'nopr' flag to skip PR creation

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
- **trade** - https://github.com/modelearth/trade
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
        if [[ "$REMOTE_URL" =~ "modelearth/$repo" ]] && [[ "$REMOTE_URL" != *"ModelEarth/$repo"* ]]; then
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
```

**Note**: This is the most comprehensive commit command that handles all repository types in the webroot ecosystem with automatic PR fallback when push permissions are denied. Use 'commit nopr' to skip all PR creation. It will only process repositories that have actual changes.


### Background Development Rust Server resides in "team" submodule folder (ALWAYS USE THIS)

**IMPORTANT**: All Rust development occurs in the `team/` submodule directory. Always navigate to `team/` before running Rust commands.

```bash
# Navigate to team directory first
cd team

# ALWAYS use this command to start server - keeps running in background
nohup cargo run serve > server.log 2>&1 &

# Check if dev server is running
curl http://localhost:8081/api/health

# Stop dev background server
lsof -ti:8081 | xargs kill -9
```

#### Rust Development Commands (run from team/ directory)
```bash
# Build and Run
cargo build                  # Build the project
cargo run -- serve         # Start REST API server (blocks terminal - not recommended)
cargo run -- init-db       # Initialize database schema
cargo check                 # Check code without building
cargo clippy                # Run linting
cargo test                  # Run tests

# Database Management
cargo run -- init-db       # Create all tables with relationships and constraints
```

#### Environment Configuration
- Server host/port configurable via `SERVER_HOST`/`SERVER_PORT` environment variables
- **Primary Database**: PostgreSQL (COMMONS_HOST in .env file)
- **Trade Flow Database**: PostgreSQL (EXIOBASE_HOST in .env file)
- Store auth keys in separate config file excluded by `.gitignore`

#### Alternative Commands (NOT RECOMMENDED)
- `cargo run serve` - Blocks terminal, stops when you exit (DO NOT USE)
- `cargo run -- serve` - Same issue, blocks terminal (DO NOT USE)

#### Project Type
This is a **project posting, assignment and to-do tracking system** - a CRM-style tool for managing public-facing listings with searchable directories, team collaboration, and AI integration using Gemini.
