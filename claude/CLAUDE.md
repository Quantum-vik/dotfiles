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
