# xpand

A lightweight text expander for macOS. Type a trigger string anywhere and it gets replaced with static text or dynamic output from JavaScript.

## Install

Requires Swift 5.9+ and macOS 13+.

```
just install
```

Grant Accessibility permission to your terminal (System Settings > Privacy & Security > Accessibility).

## Config

Edit `~/.config/xpand/xpand.js`:

```js
({
  ";shrug": "¯\\_(ツ)_/¯",
  ";ymd": () => new Date().toISOString().slice(0, 10),
  ";ip": () => shell("curl -s ifconfig.me"),
  ";home": () => env("HOME")
})
```

Values can be:
- **Strings** — pasted as-is
- **Functions** — called at expansion time, return value is pasted

### JS helpers

| Function | Description |
|----------|-------------|
| `env(name)` | Read an environment variable |
| `shell(cmd)` | Run a shell command, return stdout |

## Usage

```
just run       # run in foreground
just install   # build + start as launch agent (runs on login)
just uninstall # stop the launch agent
just restart   # restart the launch agent
just log       # tail the log
```

## How it works

xpand uses a `CGEventTap` to intercept keystrokes globally. When the typed characters match a trigger, it deletes the trigger text with backspaces, pastes the replacement via the clipboard, and plays a sound.
