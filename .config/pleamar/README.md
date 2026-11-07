# Whiskey on another computer

Whiskey is the little calico cat that lives on the desktop. It walks around,
naps, crosses monitors, comes to the mouse while **Left Alt** is held, and
clicking it opens a chat with Claude.

It needs: **Hyprland**, **pleamar**, **Claude Code** (logged in), and the
**JetBrainsMono Nerd Font**.

## What is where

| What | Where | In git? |
|---|---|---|
| Whiskey's code | `~/dotfiles/.config/pleamar/shells/whiskey/` (`whiskey.plm`, `whiskey.luau`) | yes |
| Start it with the desktop | `~/dotfiles/.config/pleamar/autostart`, run by `hyprland.lua` | yes |
| Left Alt calls it | the `ALT_L` binds in `~/dotfiles/.config/hypr/hyprland.lua` | yes |
| The cat sprite | `~/.config/pleamar/shells/whiskey/catz.png` | **no** (license) |
| Notes Whiskey reads | `~/.local/share/pleamar/whiskey/preferences.md` | **no** (private) |
| The chat | `~/.local/share/pleamar/whiskey/chat.json` | **no** (private) |

The sprite is from Last Tick's kittens pack. Its license lets it be used here,
but not shared, and this repo is public. The `.gitignore` in the `whiskey`
folder keeps every `.png` out of git.

## Setting it up

Do these one at a time. `laptop` below means the other computer's name.

### 1. Install pleamar

```sh
curl -fsSL https://raw.githubusercontent.com/k4ditano/pleamar/main/install.sh | sh -s -- --alone
```

It builds with Rust. If it fails with a `rustc: symbol lookup error ... LLVM`
message, `rust` and `llvm-libs` come from different repos (this happened on
CachyOS). Put Arch's LLVM back, then run the install again:

```sh
sudo pacman -S extra/llvm-libs extra/llvm
```

### 2. Install Claude Code and log in

Install Claude Code, then run it once and log in:

```sh
claude
```

### 3. Install the font

```sh
sudo pacman -S ttf-jetbrains-mono-nerd
```

### 4. Get the dotfiles and link the pleamar folder

Pull the dotfiles, then:

```sh
ln -s ~/dotfiles/.config/pleamar ~/.config/pleamar
```

### 5. Copy the cat sprite (from the computer that has it)

```sh
scp ~/.config/pleamar/shells/whiskey/catz.png laptop:~/.config/pleamar/shells/whiskey/
```

Any sheet from the kittens pack works: copy it over `catz.png` for another cat.

### 6. Make Whiskey's private folder

On the laptop:

```sh
mkdir -p ~/.local/share/pleamar/whiskey && chmod 700 ~/.local/share/pleamar/whiskey
```

Then copy the notes over (from the computer that has them):

```sh
scp ~/.local/share/pleamar/whiskey/preferences.md laptop:~/.local/share/pleamar/whiskey/
```

### 7. Log out and back in

Hyprland starts Whiskey by itself. To start it now instead:

```sh
pleamar --autostart
```

## Good to know

- **Chats stay on each computer.** The laptop's Whiskey starts its own chat.
- **It needs Hyprland.** Crossing monitors and Left Alt ask Hyprland where
  things are. The monitor layout is read by itself, nothing to set.
- **After editing `whiskey.plm` or `whiskey.luau`, restart it.** Saving does
  not refresh it while it runs on several monitors:

  ```sh
  pleamar --say whiskey quit; pleamar --autostart
  ```

- **Open Whiskey's chat in a terminal** (from its folder, where its chats are kept):

  ```sh
  cd ~/.local/share/pleamar/whiskey && claude --resume
  ```

- **Which Claude it uses:** `MODEL` and `EFFORT` near the chat part of
  `whiskey.luau` (now Opus 5.5, medium).
