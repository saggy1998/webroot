# CLAUDE.md

## Start server or Restart server

nohup python -m http.server 8887 > /dev/null 2>&1 &

Note: Uses nohup to run server in background and redirect output to avoid timeout.

### Update all submodules:
```bash
git submodule foreach 'git pull origin main || git pull origin master'
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

### Submodule Management

#### IMPORTANT: "commit [submodule name]" Command Requirements
When a user says "commit [submodule name]", use these IMPROVED steps to avoid errors:

**Method 1 - Using git submodule foreach (RECOMMENDED):**
```bash
# Step 1a: Check which submodules have changes first
git submodule foreach 'git status'

# Step 1b: Commit ONLY to specific submodule to avoid errors from clean submodules
git submodule foreach --recursive 'if [ "$name" = "[submodule name]" ]; then git add . && git commit -m "Description of changes" && git push origin HEAD:main; fi'

# Step 2: Update parent repository 
git submodule update --remote [submodule name]
git add [submodule name] 
git commit -m "Update [submodule name] submodule"
git push
```

**Method 2 - Manual navigation (if Method 1 fails):**
```bash
# Only use if you can successfully cd into submodule directory
cd [submodule name]
git checkout main  # Ensure on main branch
git add . && git commit -m "Description of changes"
git push origin main
cd ..
git add [submodule name]
git commit -m "Update [submodule name] submodule" 
git push
```

**⚠️ CRITICAL**: 
- Method 1 handles detached HEAD states automatically
- Both methods require updating the parent repository
- If git submodule foreach fails, the submodule may not exist or be corrupted
- **NEW**: Always check status first to see which submodules actually have changes
- **NEW**: Use conditional `if [ "$name" = "submodule" ]` to target specific submodule and avoid "nothing to commit" errors from clean submodules
- **NEW**: The `--recursive` flag ensures nested submodules are handled properly

#### Quick Commands for Submodules
- **"commit [submodule name]"**: Complete 8-step workflow above
- **"push [submodule name]"**: Only push submodule changes (steps 1-3)
- **"PR [submodule name]"**: Create pull request workflow

When displaying "Issue Resolved" use the same checkbox icon as "Successfully Updated"

#### Additional Notes
- Allow up to 12 minutes to pull repos (large repositories)
- Always verify both submodule AND parent repository are updated

### Git Commit Guidelines
- **NEVER add Claude Code attribution or co-authored-by lines to commits**
- **NEVER add "🤖 Generated with [Claude Code]" or similar footers**
- Keep commit messages clean and focused on the actual changes
- Include a brief summary of changes in the commit text

### Quick Commands

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
