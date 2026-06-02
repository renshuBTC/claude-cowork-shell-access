# Claude Cowork Shell Command Runner

> A ~90-line bash bridge that lets Claude in Cowork mode run shell commands on your machine. Paste one line, give Claude a workbench in your shell. Stop it whenever you want.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![shell: bash](https://img.shields.io/badge/shell-bash-blue.svg)](ccshell.sh)
[![deps: none](https://img.shields.io/badge/deps-none-brightgreen.svg)](ccshell.sh)

Short name: **`ccshell`** (the script is `ccshell.sh`).

## What it does

Claude in Cowork mode can read and write files in folders you've opened, but it can't run shell commands on your machine. `ccshell` fills that one gap.

You start it once. It watches a folder. Claude drops a script into that folder. `ccshell` runs it on your machine *as you*, with all your normal permissions, and saves the output where Claude can read it back.

That is the whole product.

```bash
# in your terminal:
bash ccshell.sh

# from Claude (it just writes a file in the queue folder):
#   .ccshell/queue/001-hello.sh
# within ~1 second, the result appears at:
#   .ccshell/done/001-hello.out
```

## Who this is for

- **Claude users in Cowork mode** who want their assistant to actually drive their machine — push to GitHub via their SSH key, run their test suite, query their local database, drive a non-trivial workflow — without anyone typing into a terminal.

That is the primary use case. Cowork has file write access to opened folders; that's the only capability `ccshell` needs from the AI side.

## Who this is NOT for

Be honest about the alternatives so people who don't fit can route themselves to the right tool:

- **If you want a full personal AI agent platform** with skills, integrations, scheduling, etc., look at [OpenClaw](https://github.com/openclaw/openclaw). Much bigger and more polished.
- **If you can use [Claude Code](https://docs.claude.com/en/docs/claude-code)**, use that — it's the official terminal-native agent and is strictly better when it fits.
- **If you're vibe-coding** in Lovable, Bolt, v0, or Replit, you don't need this. Those provide their own execution.
- **If your AI lives in a browser** (Claude in Chrome, claude.ai web chat), it can't write to your local filesystem, so `ccshell` won't help. The browser AI has no way to drop scripts into your queue folder.

`ccshell` is specifically for Cowork mode (and any future Claude client that gets the same file-write capability without direct shell access).

## How it works

```
+-----------------+       drops *.sh         +-------------+
|  Claude (Cowork)| ------------------------>| queue/      |
|                 |                          |             |
|                 |<----- reads .out files --| done/       |
+-----------------+                          +------+------+
                                                    | ~1s poll loop
                                             +------v-------+
                                             | ccshell.sh   |
                                             | (you started |
                                             |  this once)  |
                                             +--------------+
```

1. **You start it.** `bash ccshell.sh`. A poll loop wakes up.
2. **Claude writes a script to `queue/`.** Any name ending in `.sh`. Oldest first.
3. **`ccshell` runs it.** Per-script timeout (default 60s). All stdout+stderr land in `done/<name>.out`. The script file gets renamed `.sh.done` so it doesn't re-run.
4. **Claude reads the output.** Decides what to do next. Drops another script.
5. **You stop it.** `rm .ccshell/.running` or Ctrl+C.

Everything is files. Everything is readable. There's no socket, no daemon, no network listener.

## Install

No install. One bash script.

```bash
curl -fsSL https://raw.githubusercontent.com/renshuBTC/claude-cowork-shell-command-runner/main/ccshell.sh > ccshell.sh
chmod +x ccshell.sh
```

Or clone the repo:

```bash
git clone https://github.com/renshuBTC/claude-cowork-shell-command-runner
cd claude-cowork-shell-command-runner
bash ccshell.sh
```

Requirements: bash, standard Unix utilities (`ls`, `mv`, `rm`, `timeout`, `sleep`, `kill`, `pkill`). Works on Linux, macOS, and WSL. No Python, no Node, no dependencies of any kind.

## Configuration

Optional, via environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `CCSHELL_DIR` | `./.ccshell` | Root folder. Will contain `queue/`, `done/`, `.pid`, `.running` |
| `CCSHELL_TIMEOUT` | `60` | Per-script timeout in seconds. Wedged scripts get killed; runner keeps going |

Example:

```bash
CCSHELL_DIR=~/.ccshell CCSHELL_TIMEOUT=30 bash ccshell.sh
```

## Using it with Claude in Cowork mode

The intended setup:

1. Open Cowork mode. Open the folder you want to work in.
2. Open a terminal in that folder. Paste: `bash ccshell.sh`
3. Tell Claude something like: *"There's a ccshell runner at `./.ccshell/`. To run commands on my machine, drop shell scripts into `queue/` and read results from `done/`."*
4. Claude writes a script via its file tools, watches the output file appear in `done/`, iterates.

That's the entire integration. No plugin to install. No config.

## Permissions and security

**`ccshell` needs no special privileges of its own.** No root, no sudo, no special groups, no network ports.

But every script that runs through it inherits your shell's full privileges. **If you can do it from a terminal, a queued script can too.**

| If you can... | A queued script can too |
|---|---|
| Read your home folder | Read your home folder |
| Push to GitHub via SSH | Push to GitHub via SSH |
| Use your AWS / cloud creds | Use them |
| `sudo` with a cached timestamp | `sudo` without prompting |
| `rm -rf ~/important-stuff` | Same |

By running `bash ccshell.sh`, you're saying: *"I trust whoever can write to my queue folder to send me commands I'd be willing to run."* That trust is real. Three things make it tractable:

1. **You can read each script before it runs.** ~1 second window if you watch closely; longer if you pre-load scripts before starting the runner.
2. **Everything is logged in plain text.** Every script is in `queue/<name>.sh.done` after running, every output is in `done/<name>.out`. Full audit trail.
3. **You can stop it instantly.** `rm .ccshell/.running` or Ctrl+C.

### Recommended hardening

- **Put `.ccshell/` on a private filesystem.** Not on shared NFS/SMB where other users could write to your queue.
- **Use `chmod 700`.** The runner does this automatically on startup; verify.
- **Don't run as root.** Run as your normal user.
- **Inspect what lands in the queue** if you're testing a new AI client or workflow.

## What it is NOT

- **Not remote access.** Claude is not on your machine. It's leaving notes; your computer carries them out.
- **Not a service or daemon.** Runs only while you have the terminal open.
- **Not a privilege escalator.** Does only what you can already do.
- **Not magic.** ~90 lines of bash. Read it.
- **Not a Claude Code or OpenClaw replacement.** Those are bigger, more capable tools for different use cases.
- **Not affiliated with Anthropic.** Independent project. "Claude" and "Cowork" are Anthropic trademarks; usage here describes interoperability, not endorsement.

## Comparison

| | **ccshell** | **Claude Code** | **OpenClaw** |
|---|---|---|---|
| What it is | Shell bridge | Official AI CLI | Personal AI agent platform |
| Includes the AI | No (assumes Claude in Cowork) | Yes (Claude) | Yes (bring your own LLM) |
| Install | None (~90 lines bash) | Full CLI install | Full app install |
| Skills/integrations | Zero — runs whatever you give it | Slash commands + hooks | 100+ AgentSkills |
| Native target | Claude in Cowork mode | Developers in terminals | Self-hosted personal agent |
| Lines of code | ~90 | Large project | Large project |

If you can install Claude Code or OpenClaw, you probably should. `ccshell` is for when the right answer is the smallest possible thing.

## FAQ

**Q: Can I run multiple runners?**
A: No. The script kills any previous runner (via its `.pid` file) when you start a new one. One runner per `CCSHELL_DIR`.

**Q: What happens if a script hangs?**
A: It gets killed after `CCSHELL_TIMEOUT` seconds (default 60). The `.out` file will contain `===TIMED OUT===` and the runner keeps going.

**Q: What about reboots?**
A: It's not a service. After reboot, the runner is gone. The queue and done directories survive. `bash ccshell.sh` again to resume.

**Q: Can I use it without an AI?**
A: Sure. It's just a folder-based job runner. Some people might use it as a tiny build pipeline or a way to queue ops on a server.

**Q: Why bash?**
A: Bash is everywhere. No install step, no dependencies, no version mismatches. The whole tool is one file you can read in three minutes.

**Q: Is this affiliated with Anthropic?**
A: No. Independent project that interoperates with Anthropic's Claude in Cowork mode. The name describes who it's for; it is not endorsed or maintained by Anthropic.

## Trademark notice

"Claude" and "Cowork" are trademarks of Anthropic PBC. This project uses them descriptively to identify the AI client it's designed to bridge to. No affiliation or endorsement is claimed or implied.

## License

MIT. See [LICENSE](LICENSE).

## Acknowledgments

Inspired by the `at` command's spool directory pattern (since 1979), Maildir-style queueing, and the general "filesystem-as-message-queue" idea. The specific framing as a bridge for Claude in Cowork mode emerged from real BTX (Bitcoin Terminal Exchange) work in mid-2026, where the AI needed to drive a mainnet wallet, push commits, run cargo tests, and interact with daemons on the user's machine — all without typing into a terminal.

Renamed from `dropshell` in v0.1.1 to better describe the intended audience.
