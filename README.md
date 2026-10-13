# Jlauncher

Two tools for playing several RuneScape accounts:

- **[`JagexProfiles.ps1`](#windows-jagex-launcher-profile-switcher)** (Windows): switches the official Jagex Launcher between Jagex accounts.
- **[`jlogin`](#linux-one-click-login-for-legacy-accounts)** (Linux): opens RuneLite and logs in to a legacy (non-Jagex) account in one click.

On Linux, use [Bolt](https://bolt.adamcake.com/) for Jagex accounts. It stays signed in to all of them and launches RuneLite.

## Windows: Jagex Launcher profile switcher

Switch the Jagex Launcher between several Jagex accounts in one click, without signing in again each time.

The Jagex Launcher stores only **one** signed-in session per Windows user. `JagexProfiles.ps1` saves that session into a named profile and restores another one while the launcher is closed. It doesn't automate gameplay, type passwords, or contact Jagex servers. It only moves the launcher's own local files.

### Quick start

1. Put `JagexProfiles.ps1` somewhere permanent, such as `C:\Tools\Jlauncher\`.
2. Open PowerShell in that folder and check the paths on your PC:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\JagexProfiles.ps1 discover
   ```
   Every configured location should show `[found]`. If one doesn't, see [Configuration](#configuration).
3. Sign in to your first account in the Jagex Launcher. Then save that session:
   ```powershell
   .\JagexProfiles.ps1 save Main
   ```
4. For each additional account, run `new`. It saves the current profile and opens the launcher signed out:
   ```powershell
   .\JagexProfiles.ps1 new Ironman
   ```
   Sign in to the new account. **Do not click "Sign out"** to leave an account. Signing out can revoke that saved session on Jagex's side. Always use `switch` or `new`.
5. Create desktop shortcuts:
   ```powershell
   .\JagexProfiles.ps1 shortcut Main
   .\JagexProfiles.ps1 shortcut Ironman
   ```
   Double-clicking **Jagex - Ironman** closes the launcher, saves the active account, swaps in Ironman, and reopens the launcher. If anything goes wrong, a pop-up explains what happened.

### Commands

| Command | What it does |
|---|---|
| `list` | List profiles and mark the active one |
| `save <name>` | Save the session that is signed in right now as `<name>` |
| `new <name>` | Save the current profile, clear the session, and open the launcher for a fresh sign-in |
| `switch <name>` | Save the current profile, restore `<name>`, and open the launcher |
| `delete <name>` | Delete a saved profile (it can't be the active one) |
| `shortcut <name>` | Create a one-click desktop shortcut for `<name>` |
| `discover` | Show Jagex folders and registry keys, and which configured paths exist |

Options: `-NoLaunch` swaps without opening the launcher. `-Discard` lets `switch` or `new` throw away a session that isn't saved to any profile.

### Safety design

- **No mixing between accounts.** The live folders and registry key are fully cleared before a profile is restored. Copying over the top would leave the previous account's files behind.
- **Never overwrites an unknown session.** If the live session isn't recorded as belonging to a profile, `switch` and `new` refuse to run until you `save` it, or until you pass `-Discard`.
- **Backups never damage a good copy.** A session is first saved to a temporary folder. It replaces the old copy only after the save succeeds.
- **Failures don't spread.** While a swap is in progress, no profile is marked active. If a swap fails, the half-swapped state can't be saved over a good profile later.
- **Stored privately.** Profiles live in `%LOCALAPPDATA%\JagexProfiles`. That folder is private to your Windows user and isn't synced by OneDrive.

> **Treat `%LOCALAPPDATA%\JagexProfiles` like a password vault.** Each profile contains live sign-in tokens. Anyone who copies that folder may be able to use your accounts. Don't upload it, sync it, or back it up anywhere you don't fully control. If a copy leaks, sign out of all sessions from each account's Jagex account settings page.

### Configuration

The paths are at the top of the script:

```powershell
$SessionDirs  = @("$env:APPDATA\JagexLauncher", "$env:LOCALAPPDATA\JagexLauncher")
$RegistryKey  = 'HKCU\Software\Jagex\Jagex Launcher'
$LauncherExe  = "${env:ProgramFiles(x86)}\Jagex Launcher\JagexLauncher.exe"
```

If `discover` shows the launcher keeps its data somewhere else, edit `$SessionDirs`. **Don't** add `C:\ProgramData\Jagex`. That folder holds the shared game installs, not sign-ins. Copying it would be slow and pointless.

After changing the paths, test with two accounts: switch back and forth a few times and confirm each one opens signed in.

### Alternatives

- **[Bolt Launcher](https://bolt.adamcake.com/)** is a free, open-source third-party launcher. It can stay signed in to several Jagex accounts at once.
- **RuneLite only:** RuneLite's [Jagex account guide](https://github.com/runelite/runelite/wiki/Using-Jagex-Accounts) explains `--insecure-write-credentials`, which saves a credentials file for RuneLite to use without the launcher. You can keep one such file per account.

## Linux: one-click login for legacy accounts

`jlogin` opens a **new** RuneLite window and types a legacy account's login and password into its login screen. It's meant for players who find typing credentials hard.

> **Read this first.** Jagex can treat any program that types into the game client as macroing, even on the login screen. Using `jlogin` is a risk to the accounts you use it with, and that's your decision to make. To keep the risk as low as possible, it does exactly one login per click or key press. It never runs on its own, and it never sends input once you're in the game.

### Setup (inside the Linux VM)

1. **Use an X11 session.** `xdotool` can't type into windows under Wayland. On the desktop's login screen, choose the session named "Xorg" or "X11".
2. **Install the tools:**
   ```bash
   sudo apt install xdotool libsecret-tools libnotify-bin xbindkeys
   ```
   You also need RuneLite. The script finds `runelite` on your PATH, `~/RuneLite.AppImage`, or the Flatpak `net.runelite.RuneLite` automatically.
3. **Install the script and check it:**
   ```bash
   install -m 755 jlogin ~/.local/bin/jlogin
   jlogin check
   ```
4. **Add each account.** The password goes into the desktop keyring (GNOME Keyring or KWallet), never into a file:
   ```bash
   jlogin add Main main@example.com
   jlogin add Skiller skiller@example.com
   ```
5. **Make one-click icons:**
   ```bash
   jlogin desktop Main
   jlogin desktop Skiller
   ```
   This adds **RuneLite - Main** and similar icons to the app menu and the desktop. If an icon errors, a notification explains what went wrong.
6. **Or give each account a key** (see [Hotkeys](#hotkeys)):
   ```bash
   jlogin bind Main ctrl+alt+1
   jlogin bind Skiller ctrl+alt+2
   ```

### Everyday use

- **Log in:** click an account's icon or press its key. RuneLite opens, and about 20 seconds later the login is filled in and submitted. If the account has an authenticator, type the 6-digit code yourself.
- **Switch accounts:** close the RuneLite window, then click another icon or press another key. You can also keep several windows open, one per account.
- **One login at a time.** Pressing a key again, or another account's key, while a login is in progress does nothing. A pop-up says to wait.
- **Hands off while it types.** If another window takes focus, `jlogin` stops immediately instead of typing into it.

### Commands

| Command | What it does |
|---|---|
| `jlogin add <name> <login>` | Save an account (asks for the password twice) |
| `jlogin play <name>` | Open RuneLite and log in |
| `jlogin list` | Show saved accounts |
| `jlogin remove <name>` | Forget an account, its stored password, and its menu icon |
| `jlogin desktop <name>` | Create a one-click icon |
| `jlogin bind <name> <key>` | Log in to `<name>` when `<key>` is pressed |
| `jlogin unbind <name>` | Remove an account's key |
| `jlogin check` | Check that the required tools and RuneLite are found |

### Hotkeys

`jlogin bind` sets a key per account. The keys work in any app, start automatically when you log in to the desktop, and keep working after a restart.

- **Key format:** `ctrl+alt+1`, `super+F9`, `shift+ctrl+m`. Modifiers are `ctrl`, `alt`, `shift` and `super` (the Windows key).
- **Keys on their own are mostly refused.** A key bound with no modifier stops reaching every app, so binding `F5` would break that tab key in the game, and binding a letter would break chat. On their own, only `F13`-`F24`, `Pause` and `Scroll_Lock` are allowed.
- **Accessibility switches and big-button keypads:** most can be programmed to send a key. Set each button to `F13`, `F14` and so on. Nothing else uses those keys, so they're the safest choice:
  ```bash
  jlogin bind Main F13
  jlogin bind Skiller F14
  ```
- **Checking:** `jlogin list` shows each account's key.

`jlogin` uses `xbindkeys` with its own config file, so it doesn't interfere with keys you've set up elsewhere.

### Safety design

- **Only fresh windows.** It types only into a RuneLite window it just opened. It identifies the window by its title, which is `RuneLite` at the login screen and `RuneLite - <name>` in game.
- **Checks before every step.** Before each piece of typing it confirms the window still has focus and is still at the login screen. Otherwise it stops, so a password can't end up in game chat or another app.
- **Passwords stay hidden.** Passwords come from the keyring at the moment of login and are passed to `xdotool` through a pipe, so they never appear in the process list.
- **No authenticator automation.** It never stores or types authenticator codes.

### Tuning

If logins don't go through, create `~/.config/jlauncher/settings` and adjust:

```bash
LOAD_WAIT=30      # seconds for RuneLite to reach the login screen (raise on slow VMs)
KEY_DELAY=120     # milliseconds between keys (raise if characters go missing)
RUNELITE_CMD="$HOME/Apps/RuneLite.AppImage"   # if RuneLite isn't found automatically
```

The login sequence is: Enter (Existing User), clear the field, type the login, Tab, clear the field, type the password, Enter. Leave **Remember username** unticked on the game's login screen. If it's ticked, the cursor starts in the password field and the sequence types into the wrong fields.
