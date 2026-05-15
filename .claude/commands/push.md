Commit all staged and unstaged changes, then push to the remote repository.

Steps:
1. Run `git status` to see what changed.
2. If there are no changes (no untracked, modified, or staged files), tell the user "Nothing to push" and stop.
3. Run `git diff` and `git diff --cached` to understand the changes.
4. Stage all relevant changed files (prefer explicit file names over `git add -A`). Do NOT stage `.env`, credentials, or secrets files.
5. Create a commit with a clear, concise message summarizing the changes. End the commit message with:
   Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
6. Push using the token from the `gittoken` env variable and username `jsandy16`:
   ```
   git push https://jsandy16:${gittoken}@github.com/jsandy16/$(basename $(git remote get-url origin) .git).git HEAD
   ```
7. Report the result to the user (success or failure).
