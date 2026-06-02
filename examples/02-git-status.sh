# 02-git-status.sh — query state on the host, return structured info
# Demonstrates how an AI can ask "what does the current git state look like?"
cd "${1:-.}"   # optional first arg = repo path; default cwd
echo "--- branch ---"
git branch --show-current 2>&1
echo
echo "--- last 5 commits ---"
git log --oneline -5 2>&1
echo
echo "--- working tree (short) ---"
git status --short
echo
echo "--- unpushed commits ---"
git log --oneline @{u}..HEAD 2>&1 | head || echo "(in sync with upstream, or no upstream tracking)"
