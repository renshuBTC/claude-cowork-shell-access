# 01-hello.sh — the smallest possible dropshell example
# Drop this into .dropshell/queue/ ; the watcher will run it.
echo "hello from your shell"
echo "user: $(whoami)"
echo "pwd:  $(pwd)"
echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
