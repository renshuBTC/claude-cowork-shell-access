# Dropshell

> A ~90-line shell bridge between an AI assistant and your shell. Paste one line, give your assistant a workbench in your shell. Stop it whenever you want.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![shell: bash](https://img.shields.io/badge/shell-bash-blue.svg)](dropshell.sh)
[![deps: none](https://img.shields.io/badge/deps-none-brightgreen.svg)](dropshell.sh)

## What it does

Dropshell turns a folder on your computer into a drop-box where an AI assistant can leave shell commands for your computer to run.

You start it once. It watches a folder. The AI drops a script in that folder. Dropshell sees the script within a second, runs it on your machine *as you*, with all your normal permissions. The output gets saved into a sibling folder for the AI to read back.

That's the whole product.

```bash
bash dropshell.sh
# in another terminal — or from an AI agent — drop a script:
echo 'echo "hello from your shell"; date' > .dropshell/queue/001-hello.sh
# wait a second; read the result:
cat .dropshell/done/001-hello.out
```

## Who this is for

A small, specific group:

- People using **Claude in Cowork mode** (Anthropic's desktop app) and want their assistant to reach into their real shell without ever typing into a terminal window
- People using **browser-based AI** (Claude in Chrome, etc.) and need a minimal local execution channel
- People on **restricted hosts** where installing a full local agent platform isn't an option
- Anyone who wants the smallest possible auditable bridge between "AI that writes commands" and "computer that runs them"

## Who this is NOT for

Be honest about the alternatives:

- If you want a **full personal AI agent platform** with skills, integrations, scheduling, etc., look at [OpenClaw](https://github.com/openclaw/openclaw). It is much bigger and more polished.
- If you want **AI in your terminal directly** (the obvious answer if you can install it), use [Claude Code](https://docs.claude.com/en/docs/claude-code). It is the official tool for this.
- If you're **vibe-coding** (prompt-to-deployed-app), use Lovable, Bolt, v0, or Replit Agent. Dropshell is the wrong shape.

Dropshell exists in the gap: when your AI is hosted somewhere you can't grant direct shell access, and you don't want to install a whole runtime to bridge it.

## How it works

```
+-----------------+        drops *.sh         +-------------+
|  AI assistant   | -------------------------->| queue/      |
|  (Cowork, etc.) |                            |             |
|                 |<------ reads .out files ---| done/       |
+-----------------+                            +------+------+
                                                      | ~1s poll loop
                                               +------v-------+
                                               | dropshell.sh |
                                               | (you started |
                                               |  this once)  |
                                               +--------------+
```

1. **You start it.** Paste one command: `bash dropshell.sh`. A poll loop wakes up.
2. **AI writes a script to `queue/`.** Any name ending in `.sh`. The watcher picks the oldest file first.
3. **Dropshell runs it.** With a per-script timeout (default 60s). All output (stdout + stderr) goes to `done/<name>.out`. The script file is renamed `.sh.done` so it doesn't re-run.
4. **AI reads the output.** Decides what to do next. Drops another script. Repeat.
5. **You stop it.** `rm .dropshell/.running` from anywhere, or Ctrl+C in the watcher terminal.

That's the whole protocol. Everything is files. Everything is readable. There's no socket, no daemon, no network listener.

## Install

There's no install. It's a single bash script.

```bash
curl -fsSL https://raw.githubusercontent.com/renshuBTC/dropshell/main/dropshell.sh > dropshell.sh
chmod +x dropshell.sh
```

Or clone the repo:

```bash
git clone https://github.com/renshuBTC/dropshell
cd dropshell
bash dropshell.sh
```

Requirements: bash, standard Unix utilities (`ls`, `mv`, `rm`, `timeout`, `sleep`, `kill`, `pkill`). Works on Linux, macOS, and WSL. No Python, no Node, no dependencies of any kind.

## Configuration

All optional, via environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `DROPSHELL_DIR` | `./.dropshell` | Root folder. Will contain `queue/`, `done/`, `.pid`, `.running` |
| `DROPSHELL_TIMEOUT` | `60` | Per-script timeout in seconds. Wedged scripts get killed; watcher keeps running |

Example:

```bash
DROPSHELL_DIR=~/.dropshell DROPSHELL_TIMEOUT=30 bash dropshell.sh
```

## Using it with Claude in Cowork mode

The intended setup:

1. Open Cowork mode. Open the folder you want to work in.
2. Open a terminal in that folder. Paste: `bash dropshell.sh`
3. Tell Claude something like: *"There's a dropshell watcher running at `./.dropshell/`. To run commands on my machine, drop scripts into `queue/` and read results from `done/`."*
4. Claude writes a script using its file tools, watches the output land in `done/`, iterates.

That's the entire integration. No plugin to install, no config to set.

## Permissions and security

**Dropshell needs no special privileges of its own.** No root, no sudo, no special groups, no network ports.

But every script that runs through Dropshell inherits your shell's full privileges. **If you can do it from a terminal, a queued script can too.**

| If you can... | A queued script can too |
|---|---|
| Read your home folder | Read your home folder |
| Push to GitHub via SSH | Push to GitHub via SSH |
| Use your AWS / cloud creds | Use them |
| `sudo` with a cached timestamp | `sudo` without prompting |
| `rm -rf ~/important-stuff` | Same |

By running `bash dropshell.sh`, you're saying: *"I trust whoever can write to my queue folder to send me commands I'd be willing to run."* That trust is real. Three things make it tractable:

1. **You can read each script before it runs.** ~1 second window if you watch closely; longer if you pre-load scripts before starting the watcher.
2. **Everything is logged in plain text.** Every script is in `queue/<name>.sh.done` after running, every output is in `done/<name>.out`. Full audit trail.
3. **You can stop it instantly.** `rm .dropshell/.running` or Ctrl+C.

### Recommended hardening

- **Put `.dropshell/` on a private filesystem.** Don't put it on shared NFS/SMB where other users could write to your queue.
- **Set `chmod 700` on the dir.** Dropshell does this automatically on startup; verify.
- **Don't run as root.** Run as your normal user.
- **Inspect what's in the queue before scripts run** if you're testing a new AI client. The 1-second poll is enough to peek at most things.

## What Dropshell is NOT

- **Not remote access.** The AI is not on your machine. It's leaving notes; your computer carries them out.
- **Not a service or daemon.** It only runs when you start it; dies when you close that terminal.
- **Not a privilege escalator.** It does only what you can already do.
- **Not magic.** It's ~90 lines of bash. Read it.
- **Not a replacement for Claude Code or OpenClaw.** Those are bigger, more capable tools for different use cases.

## Comparison

| | **Dropshell** | **Claude Code** | **OpenClaw** |
|---|---|---|---|
| What it is | Shell bridge | Official AI CLI | Personal AI agent platform |
| Includes the AI | No (assumes AI lives elsewhere) | Yes (Claude) | Yes (bring your own LLM) |
| Install | None (~90 lines bash) | Full CLI install | Full app install |
| Skills/integrations | Zero — runs whatever you give it | Slash commands + hooks | 100+ AgentSkills |
| Native target | Restricted/sandboxed AI clients | Developers in terminals | Self-hosted personal agent |
| Lines of code | ~90 | Large project | Large project |

If you can install Claude Code or OpenClaw, you probably should. Dropshell is for when you can't — or when you want the smallest possible thing that still works.

## FAQ

**Q: Can I run multiple watchers?**
A: No. The script kills any previous watcher (via its `.pid` file) when you start a new one. One watcher per `DROPSHELL_DIR`.

**Q: What happens if a script hangs?**
A: It gets killed after `DROPSHELL_TIMEOUT` seconds (default 60). The `.out` file will contain `===TIMED OUT===` and the watcher keeps going.

**Q: What if my computer reboots while it's running?**
A: It's not a service. After reboot, the watcher is gone. The queue and done directories survive. You can `bash dropshell.sh` again to resume.

**Q: Can I use it without an AI?**
A: Sure. It's just a folder-based job runner. Some people might find it useful as a tiny build pipeline or a way to queue ops on a server.

**Q: Why bash and not Python/Rust/Go?**
A: Bash is everywhere. No install step, no dependencies, no version mismatches. The whole tool is one file you can read in three minutes.

**Q: Is this a security risk?**
A: It's exactly as risky as letting a script write to a directory you've designated for executing scripts. Read [Permissions and security](#permissions-and-security) above. The trust model is explicit, not hidden.

## License

MIT. See [LICENSE](LICENSE).

## Acknowledgments

Inspired by the `at` command's spool directory pattern (since 1979), Maildir-style queueing, and the general "filesystem-as-message-queue" idea. The specific framing as a bridge for safety-policy-restricted AI assistants emerged from working with Claude in Cowork mode in mid-2026.

Built because every existing tool in this space (Claude Code, OpenClaw, Aider, etc.) was bigger than the actual job needed. Sometimes the right answer is a 90-line bash script.
