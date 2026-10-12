# Jlauncher: Jagex Launcher profile switcher

Switch the Jagex Launcher between several Jagex accounts in one click, without signing in again each time.

The Jagex Launcher stores only **one** signed-in session per Windows user. `JagexProfiles.ps1` saves that session into a named profile and restores another one while the launcher is closed. It doesn't automate gameplay, type passwords, or contact Jagex servers. It only moves the launcher's own local files.

## Quick start

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

## Commands

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

## Safety design

- **No mixing between accounts.** The live folders and registry key are fully cleared before a profile is restored. Copying over the top would leave the previous account's files behind.
- **Never overwrites an unknown session.** If the live session isn't recorded as belonging to a profile, `switch` and `new` refuse to run until you `save` it, or until you pass `-Discard`.
- **Backups never damage a good copy.** A session is first saved to a temporary folder. It replaces the old copy only after the save succeeds.
- **Failures don't spread.** While a swap is in progress, no profile is marked active. If a swap fails, the half-swapped state can't be saved over a good profile later.
- **Stored privately.** Profiles live in `%LOCALAPPDATA%\JagexProfiles`. That folder is private to your Windows user and isn't synced by OneDrive.

> **Treat `%LOCALAPPDATA%\JagexProfiles` like a password vault.** Each profile contains live sign-in tokens. Anyone who copies that folder may be able to use your accounts. Don't upload it, sync it, or back it up anywhere you don't fully control. If a copy leaks, sign out of all sessions from each account's Jagex account settings page.

## Configuration

The paths are at the top of the script:

```powershell
$SessionDirs  = @("$env:APPDATA\JagexLauncher", "$env:LOCALAPPDATA\JagexLauncher")
$RegistryKey  = 'HKCU\Software\Jagex\Jagex Launcher'
$LauncherExe  = "${env:ProgramFiles(x86)}\Jagex Launcher\JagexLauncher.exe"
```

If `discover` shows the launcher keeps its data somewhere else, edit `$SessionDirs`. **Don't** add `C:\ProgramData\Jagex`. That folder holds the shared game installs, not sign-ins. Copying it would be slow and pointless.

After changing the paths, test with two accounts: switch back and forth a few times and confirm each one opens signed in.

## Alternatives

- **[Bolt Launcher](https://bolt.adamcake.com/)** is a free, open-source third-party launcher. It can stay signed in to several Jagex accounts at once.
- **RuneLite only:** RuneLite's [Jagex account guide](https://github.com/runelite/runelite/wiki/Using-Jagex-Accounts) explains `--insecure-write-credentials`, which saves a credentials file for RuneLite to use without the launcher. You can keep one such file per account.
