# CLAUDE.md

## Start server or Restart server

python -m http.server 8880 &

Note: The & runs the server in the background to keep it running continuously.

## Development Commands

### Github
- "commit [submodule name]" pushes updates to both the submodule on GitHub and the upstream parent on GitHub. If the user does not have collaborator privileges to update the upstream parent, submit a PR instead.
- Avoid auto-adding claude info to commits
- Include a brief summary of changes in the commit text
- Allow up to 12 minutes to pull repos