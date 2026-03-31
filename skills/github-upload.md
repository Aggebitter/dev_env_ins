Upload the current project to GitHub. Follow these steps exactly:

1. **Check tools**
   - Run `gh --version` — if not found, tell the user to install it:
     `sudo apt-get install gh` then `gh auth login`
   - Run `gh auth status` — if not authenticated, tell the user to run `gh auth login` and stop.

2. **Check git status**
   - Run `git status` in the current directory.
   - If not a git repo, tell the user to run `new-project.sh` first and stop.
   - If there are uncommitted changes, ask the user if they want to commit them now before pushing.
     If yes, run `git add -A` and ask for a commit message, then commit.

3. **Check for existing remote**
   - Run `git remote -v`.
   - If `origin` already exists, skip to step 5.

4. **Create GitHub repository**
   - Get the project name from the current directory name: `basename $(pwd)`
   - Ask the user:
     - Should the repo be **public** or **private**? (default: private)
     - Optional description (can be left blank)
   - Create the repo:
     `gh repo create <name> --[public|private] --source=. --remote=origin --push`
   - If this succeeds, skip step 5.

5. **Push to GitHub**
   - Run `git push -u origin main`
   - If the branch is not `main`, use `git push -u origin $(git branch --show-current)`

6. **Done**
   - Print the repository URL: `gh repo view --json url -q .url`
   - Tell the user the repo is live and how to clone it on another machine.
