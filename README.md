# Claude Cowork Shell Access

> A ~90-line bash bridge that gives Claude in Cowork mode access to your shell. Paste one line, and Claude can run commands on your machine. Stop it whenever you want.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![shell: bash](https://img.shields.io/badge/shell-bash-blue.svg)](ccshell.sh)
[![deps: none](https://img.shields.io/badge/deps-none-brightgreen.svg)](ccshell.sh)

Short name: **`ccshell`** (the script is `ccshell.sh`).

## What it does

Claude in Cowork mode can read and write files in folders you've opened, but it can't run shell commands on your machine. This project gives it that one capability.

You start it once. It watches a folder. Claude drops a shell script into that folder. The runner picks the script up within a second, executes it on your machine *as you*, with all your normal permissions, and saves the output where Claude can read it back.

That is the whole product.

```bash
# in your terminal:
bash ccshell.sh

# Claude (via its file tools) drops a script:
#   .ccshell/queue/001-hello.sh
# within ~1 second, the result appears at:
#   .ccshell/done/001-hello.out
```

## Who this is for

**Claude users in Cowork mode** who want their assistant to actually drive their machine — push to GitHub via their SSH key, run their test suite, query their local database, manage daemons, drive multi-step workflows — without anyone typing into a terminal.

Cowork has the file-write capability needed to drop scripts into the queue. That's the only thing the runner asks for.

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
3. **The runner executes it.** Per-script timeout (default 60s). All stdout+stderr land in `done/<name>.out`. The script file gets renamed `.sh.done` so it doesn't re-run.
4. **Claude reads the output.** Decides what to do next. Drops another script.
5. **You stop it.** `rm .ccshell/.running` or Ctrl+C.

Everything is files. Everything is readable. There's no socket, no daemon, no network listener.

## Install

No install. One bash script.

```bash
curl -fsSL https://raw.githubusercontent.com/renshuBTC/claude-cowork-shell-access/main/ccshell.sh > ccshell.sh
chmod +x ccshell.sh
```

Or clone the repo:

```bash
git clone https://github.com/renshuBTC/claude-cowork-shell-access
cd claude-cowork-shell-access
bash ccshell.sh
```

Requirements: bash, standard Unix utilities (`ls`, `mv`, `rm`, `timeout`, `sleep`, `kill`, `pkill`). Works on Linux, macOS, and WSL. No Python, no Node, no dependencies of any kind.

## Configuration

All optional, via environment variables:

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

**The runner needs no special privileges of its own.** No root, no sudo, no special groups, no network ports.

But every script that runs through it inherits your shell's full privileges. **If you can do it from a terminal, a queued script can too.**

| If you can... | A queued script can too |
|---|---|
| Read your home folder | Read your home folder |
| Push to GitHub via SSH | Push to GitHub via SSH |
| Use your AWS / cloud credentials | Use them |
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
- **Not affiliated with Anthropic.** Independent project. "Claude" and "Cowork" are Anthropic trademarks; usage here describes interoperability, not endorsement.

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

Inspired by the `at` command's spool directory pattern (since 1979), Maildir-style queueing, and the general "filesystem-as-message-queue" idea. The specific framing as a bridge for Claude in Cowork mode emerged from real Bitcoin protocol work in mid-2026 — the AI needed to drive a mainnet wallet, push commits, run cargo tests, and interact with daemons on the host machine, all without typing into a terminal.

Renamed from `dropshell` (v0.1.0) → `claude-cowork-shell-command-runner` (v0.1.1) → `claude-cowork-shell-access` (v0.1.2).
