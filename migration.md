# Hermes → Windows native (Desktop GUI) migration

This folder is the live Project Zomboid mod bind:

`C:\Users\jesse\Zomboid\mods\AchievementFramework\`

It holds:

| File | Purpose |
|------|---------|
| `migration.md` | These instructions |
| `hermes-backup-20260825.zip` | Full Hermes home backup from the source machine (secrets included; 129 MB compressed) |

**Treat the zip like a password vault.** It contains `.env`, `auth.json`, API keys, OAuth tokens, sessions, memory, and skills. Do not email it or put it in a public cloud share unencrypted.

Source snapshot (this backup):

- Hermes Agent **v0.18.0** (upstream `5445e42b`)
- `HERMES_HOME` on source: `/opt/data` (container/desktop-container layout)
- Active profile: **default**
- Model/provider in use: **grok-4.5** / **xai-oauth**
- Approx. home size before zip: ~420 MB (mostly `state.db`)

Windows native Hermes data lives under:

```text
%LOCALAPPDATA%\hermes
```

Typical expanded path:

```text
C:\Users\jesse\AppData\Local\hermes
```

That is **not** the same as WSL `~/.hermes`. Native and WSL installs do not share data automatically.

---

## What you are doing

1. **Back up** the old Hermes home (already done if the zip is next to this file).
2. **Install** Hermes on the main PC with the **Windows Desktop GUI installer**.
3. **Import** the backup into `%LOCALAPPDATA%\hermes`.
4. **Open Desktop**, re-check auth/model, fix any hard-coded paths, smoke-test.

---

## Part A — Backup (source machine)

You only need this again if you want a fresher snapshot than the zip already in this folder.

### A1. Preferred: full backup CLI

On the machine/container that currently runs Hermes:

```bash
# Stop gateway if it is running (optional but cleaner for state.db)
hermes gateway stop 2>/dev/null || true

# This environment uses HERMES_HOME=/opt/data
export HERMES_HOME=/opt/data

hermes backup -o "/opt/data/workspace/pz-system-apocalypse/mod/Contents/mods/AchievementFramework/hermes-backup-$(date +%Y%m%d).zip"
```

That path is bind-mounted to:

```text
C:\Users\jesse\Zomboid\mods\AchievementFramework\hermes-backup-YYYYMMDD.zip
```

Full backup includes config, `.env`, `auth.json`, skills, memories, sessions, `state.db`, cron, hooks, skins, and other home data. It **excludes** the Hermes codebase itself (reinstalled on the new PC).

### A2. Quick (incomplete) snapshot

```bash
hermes backup --quick -o ".../hermes-quick-$(date +%Y%m%d).zip"
```

Only critical state (config, `state.db`, `.env`, auth, cron). **Do not use this alone for a full migrate.**

### A3. What is *not* “Hermes home”

Game mod trees under `Zomboid\mods\` (KnoxSystem, AchievementFramework **mod files**) are separate from Hermes agent data. This migration moves the **agent**. Your PZ mods stay where they are on Windows.

Project trees that lived *inside* the old `HERMES_HOME` (e.g. Books / Mech Support / workspace copies under `/opt/data`) **are** in the zip if they were under that home. After import they land under `%LOCALAPPDATA%\hermes\...` and paths in config/skills/cron may need updating.

---

## Part B — Install Hermes Desktop on Windows (native GUI)

### Requirements

- Windows **10** or **11**
- Normal user account (admin not required for the standard installer)
- Network for first-run dependency download (Python via `uv`, Node, PortableGit, etc.)

### B1. Download the Desktop installer

1. Open: [https://hermes-agent.nousresearch.com/desktop](https://hermes-agent.nousresearch.com/desktop)
2. Choose **Windows**.
3. Download the official **Hermes Desktop** installer (`.exe`).

Official install docs also list Desktop as the recommended macOS/Windows path:  
[https://hermes-agent.nousresearch.com/docs/getting-started/installation](https://hermes-agent.nousresearch.com/docs/getting-started/installation)

### B2. Run the GUI installer

1. Double-click the downloaded installer.
2. Accept defaults unless you have a reason not to.
3. Finish the wizard and launch **Hermes Desktop** when prompted (or start it from the Start menu).

On first launch the app provisions the native runtime (same stack as the PowerShell installer under the hood): agent code under the LocalAppData Hermes tree, User PATH entry for `hermes`, shared data dir `%LOCALAPPDATA%\hermes`.

### B3. First-launch behavior (before import)

You may see local onboarding (provider/model). You can:

- **Skip / cancel** provider setup if you are about to import a full backup (keys and model come back with the zip), or
- Complete a minimal setup, then **overwrite** with import.

Either way is fine. Import will replace home contents with the backup.

### B4. Optional: PowerShell install (CLI-first, not required)

Only if the GUI installer fails. In PowerShell:

```powershell
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
```

Then either open Desktop from the Start menu or:

```powershell
hermes desktop
```

Desktop and CLI share the same `%LOCALAPPDATA%\hermes` data after install.

### B5. Confirm install

Open a **new** Windows Terminal / PowerShell:

```powershell
hermes --version
hermes doctor
echo $env:LOCALAPPDATA\hermes
dir $env:LOCALAPPDATA\hermes
```

You should see a version line and a hermes home directory. If `hermes` is not found, close and reopen the terminal (PATH refresh) or sign out/in once.

---

## Part C — Import the backup on the main PC

### C1. Locate the zip

In Explorer:

```text
C:\Users\jesse\Zomboid\mods\AchievementFramework\
```

Copy the newest `hermes-backup-*.zip` somewhere easy if you like, e.g. Desktop. Keep a second copy until the new install has worked for a few days.

### C2. Close Hermes before import

1. Quit **Hermes Desktop** fully (tray icon too, if any).
2. If you installed the gateway service and it is running:

```powershell
hermes gateway stop
```

### C3. Restore with `hermes import`

In PowerShell:

```powershell
$zip = "C:\Users\jesse\Zomboid\mods\AchievementFramework\hermes-backup-20260825.zip"

# Fresh Desktop install: import into the default native home
hermes import $zip

# If Hermes already has local data and you are sure you want to overwrite:
# hermes import $zip --force
```

What import does:

- Validates the archive looks like a Hermes backup
- Extracts into the active Hermes home (`%LOCALAPPDATA%\hermes` on native Windows)
- Restores config, secrets, skills, sessions, memory, cron, etc.
- Does **not** replace the agent codebase (already installed by Desktop)

### C4. Desktop UI alternatives (if available on your build)

Some builds expose backup/restore under Desktop settings / command palette (e.g. profile **Export/Import**, or a System backup entry). For a **full** home move including secrets, prefer **`hermes import`** on the zip produced by **`hermes backup`**.

Note: **`hermes profile export` / Import** strips `.env` and `auth.json` on purpose. That is for sharing a profile shape, not for full machine migration.

### C5. Reopen Desktop and verify

1. Start **Hermes Desktop**.
2. Confirm your model shows (expect **grok-4.5** / xAI OAuth if tokens still valid).
3. Open a short chat; check that memory/skills feel familiar.
4. Run health check from a terminal:

```powershell
hermes doctor
hermes status --all
hermes auth list
```

### C6. Re-authenticate if needed

OAuth tokens can be machine- or device-bound.

- In Desktop: open model/provider settings and sign in again (xAI / Nous / Codex / etc.).
- Or CLI: `hermes auth` / `hermes model` / `hermes setup`.

Messaging platforms (Telegram, Discord, WhatsApp QR, etc.):

```powershell
hermes gateway setup
hermes gateway install
hermes gateway start
hermes gateway status
```

Re-pair anything that used a phone QR or device link.

---

## Part D — Path fixes (important for this setup)

The old home was **`/opt/data`**. After import, the home is:

```text
C:\Users\jesse\AppData\Local\hermes\
```

Anything that still points at Linux/container paths will break until updated:

| Old (examples) | New (examples) |
|----------------|----------------|
| `/opt/data/...` | `%LOCALAPPDATA%\hermes\...` or a project folder you choose |
| `/opt/data/Books/Mech_Support` | Wherever you keep Mech Support on Windows |
| `/opt/data/workspace/...` | e.g. `C:\Users\jesse\...` git clones |
| PZ mod binds already on Windows | `C:\Users\jesse\Zomboid\mods\KnoxSystem` and `...\AchievementFramework` (unchanged) |

Where to look:

- `%LOCALAPPDATA%\hermes\config.yaml`
- Cron job `workdir` fields (`hermes cron list`)
- Skills under `%LOCALAPPDATA%\hermes\skills\`
- Memory notes that mention absolute paths
- Any desktop Projects that pointed at container paths

Mech Support / Knox notes from the old environment assumed container + bind mounts. On native Windows, point tools at real Windows folders (your Zomboid mods path already is Windows-native).

---

## Part E — Smoke checklist

- [ ] `hermes --version` works in a new PowerShell window
- [ ] `hermes doctor` is clean enough to use
- [ ] Desktop opens and chat responds
- [ ] Provider/model correct (re-auth if errors)
- [ ] Skills list looks complete (`hermes skills list` or Desktop skills UI)
- [ ] Session history / memory present
- [ ] Cron jobs listed and schedules sane (`hermes cron list`)
- [ ] Gateway platforms connected if you use them
- [ ] Project paths updated off `/opt/data`
- [ ] One real task completed (file read/write on a Windows path you care about)
- [ ] Backup zip kept offline until you trust the new install

---

## Part F — Rollback

If the new PC is wrong:

1. Quit Desktop + `hermes gateway stop`
2. Rename the broken home:  
   `Rename-Item $env:LOCALAPPDATA\hermes hermes-bad-$(Get-Date -Format yyyyMMdd)`
3. Re-run `hermes import` from the zip, or reinstall Desktop and import again
4. Source machine is unchanged until you deliberately retire it

---

## Quick reference

```text
Desktop download:  https://hermes-agent.nousresearch.com/desktop
Install docs:      https://hermes-agent.nousresearch.com/docs/getting-started/installation
Windows native:    https://hermes-agent.nousresearch.com/docs/user-guide/windows-native
Desktop guide:     https://hermes-agent.nousresearch.com/docs/user-guide/desktop

Native home:       %LOCALAPPDATA%\hermes
This folder:       C:\Users\jesse\Zomboid\mods\AchievementFramework\

Backup (source):   hermes backup -o <path>\hermes-backup-YYYYMMDD.zip
Restore (Windows): hermes import <path>\hermes-backup-YYYYMMDD.zip
                   hermes import <path>\hermes-backup-YYYYMMDD.zip --force

Health:            hermes doctor
Auth:              hermes auth   /   hermes model
Gateway:           hermes gateway setup|install|start|status
```

### backup vs profile export

| | `hermes backup` + `hermes import` | `hermes profile export` + `import` |
|--|-----------------------------------|-------------------------------------|
| Use case | Full PC / full home migration | One named profile, shareable |
| Secrets | **Included** | **Stripped** |
| Format | `.zip` | `.tar.gz` |
| This guide | **Use this** | Only if you intentionally want a credential-free profile |

---

## Security notes

1. Restrict NTFS permissions on the zip if other people use this PC.
2. After a successful migrate you may delete the zip from the mods folder (keep an encrypted offline copy first).
3. If the zip was ever copied over an untrusted channel, rotate API keys and re-do OAuth after import.
4. Do not commit the zip to git (mod repos, Steam Workshop folders, etc.).

---

*Generated for Jesse’s Hermes migration to Windows native Desktop. Source environment used `HERMES_HOME=/opt/data`.*
