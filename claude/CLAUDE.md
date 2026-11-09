# Working with me

## Name the session before anything else

Open every session by asking what to call it, and wait for the answer before doing any other work. A first
message that already carries a task still gets named first; ask, then do the task in the same reply once the
name arrives.

Record the answer with `claude-session-name <name>`. That puts it in the statusline, where it stays visible for
the rest of the session and after a resume.

## Passwords go through the sudo pop-up

When a command needs my password (sudo, installing packages, system changes), run it with `sudo -A` through
the Bash tool. `-A` makes sudo ask through `SUDO_ASKPASS` (set in settings.json to `~/.local/bin/claude-askpass`),
which opens a masked pop-up on my screen; the password goes straight to sudo and you never see it. Plain `sudo`
fails here: the Bash tool has no terminal for it to ask in. Sudo started from Claude Code skips the fingerprint
step (`/usr/local/bin/sudo-from-claude` in `/etc/pam.d/sudo`), so the pop-up comes up immediately.

- Never ask me to type a password into the chat, and never put one in a command, a file, or `sudo -S`.
- Don't hand the step back to me with `! sudo …` or switch to `pkexec`; use the pop-up.
- Say in one line what the command does before you run it, so I know what I'm approving.
- If the pop-up doesn't appear (no display, zenity missing), stop and tell me instead of working around it.
- When I'm away, I may run `claude-sudo-store [hours]` to leave the password in the GNOME keyring for a while;
  `claude-askpass` then answers `sudo -A` without a pop-up, and a timer clears it. Never read that entry
  yourself (`secret-tool lookup service claude-sudo`), never print or copy it; only let `sudo -A` use it, and
  only for what the task needs.

## Server commands write a log you can read

I run servers and workers (gunicorn, Celery, uvicorn, npm dev servers, and so on) in my own terminals, and you
can't see a terminal's output. So any command you give me to start one also writes its output to a log file:
append `2>&1 | tee -a ~/.cache/<project>-logs/<process>.log`, put `PYTHONUNBUFFERED=1` in front of Python
processes so lines reach the file at once, and include the `mkdir -p ~/.cache/<project>-logs` it needs. Keep the
logs outside the repo. Read them yourself with `grep` and `tail`, filtered to the lines the task needs, and
don't paste tokens or request bodies from them into the chat.

## Subagents: you orchestrate, Cursor searches and reviews, your agents write code

**Every session, coding or not, hands searching and exploring to `cursor` subagents: finding files or code,
tracing how something works, checking a claim against a codebase, and web research. Don't run those sweeps
yourself or through the Explore agent; a single lookup whose target you already know (one file, one grep) is
fine to do directly.**

There is a `cursor` subagent (`~/.claude/agents/cursor.md`) that hands a task to the Cursor CLI. It is read-only:
it never writes code. For coding work, split it like this:

1. **Cursor agents do the searching.** Finding code, tracing callers, checking a claim against the codebase,
   fetching what a plan needs: brief a `cursor` agent (several in parallel when the areas are independent).
2. **Your own subagents write the code.** Hand them the plan and the Cursor findings; they make the edits.
3. **A Cursor agent reviews it, then the findings get fixed.** Send the written diff to a fresh `cursor` agent
   for review, and have the fixes made from what it reports.
4. **You plan, put the results in order, and run the tests at the end.** You orchestrate: decide what to search,
   triage the reports, brief the agents, and do the final verification yourself.

Searching of any kind goes to Cursor, web research included (tell it to use web search). Anything that needs
this conversation's context stays with your own subagents. Cursor runs on
my company team account, so its usage shows on the team admin's dashboard (request counts, models, tokens,
cost, time; not prompts or code on a Teams plan). Both of its steps, searching and reviewing a diff, are allowed
anywhere, personal repos included. Keep it on Auto (`--model auto`, never a
named model): Cursor picks the model, and named models draw on an API usage pool that runs out fast.
