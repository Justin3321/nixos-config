---
description: Safely update flake inputs, check for breaking changes, and validate the build
---

Perform a safe system update of this NixOS flake config. Follow these steps in order and do
not skip or reorder them.

## 1. Verify a clean git tree

Run `git status --porcelain`. If it outputs anything at all, STOP immediately and tell the
user the tree isn't clean — list what's dirty and ask them to commit, stash, or discard
before an update can run safely. Do not proceed to any later step.

## 2. Update flake inputs

Record the current `flake.lock` input revisions/dates (e.g. via `git show HEAD:flake.lock`
or `nix flake metadata`) before updating, so you can diff afterwards.

Run:

```fish
nix flake update
```

Then compare old vs new `flake.lock` (e.g. `git diff flake.lock`, or `nix flake metadata`
before/after) and present a short table of which inputs changed, with old date → new date
(and old rev → new rev) for each. If an input didn't change, omit it from the table.

## 3. Check Caelestia, Hyprland, and home-manager for breaking changes

For each of `caelestia-shell`, `caelestia-dots`, `hyprland` (if present as a flake input),
and `home-manager`, look at the commits that landed between the old and new pinned revision
(e.g. via `git log <old>..<new>` against the actual upstream repo if you have it cloned/cached
locally, or by fetching the relevant commit range/changelog). Flag anything that looks like:

- renamed/removed options or modules this config uses (cross-reference against `home.nix`,
  `configuration.nix`, and the `hypr/` config)
- changed defaults that could affect the Caelestia integration notes in `CLAUDE.md`
  (polkit, systemd autostart, `xdg.configFile."hypr"` handling, the `~/.config/caelestia/`
  scaffold)
- anything explicitly called out as breaking in commit messages or changelogs

If you can't reach upstream history (no network, no cached clone), say so explicitly rather
than silently skipping this step.

## 4. Build and iterate

Run:

```fish
nixos-rebuild build --flake .#nixos
```

If it fails, fix the config (`configuration.nix`, `home.nix`, etc. — never
`hardware-configuration.nix` speculatively) and rebuild, repeating until it passes. Per
`CLAUDE.md`, do NOT run `sudo` or `nixos-rebuild switch` yourself — only `build`. Explain each
fix before applying it, since the user is learning this config.

If after reasonable effort you cannot fix a build failure:

```fish
git checkout flake.lock
```

Explain clearly what broke, which input likely caused it, and why you're reverting rather
than continuing to patch around it. Stop here if you revert.

## 5. Summarize

Once the build passes, give a short summary covering:

- which inputs were bumped (old → new date)
- any config changes you made to fix the build, and why
- anything flagged in step 3 worth manually testing after switching (e.g. "test Hyprland
  autostart", "check polkit prompts still appear", "verify Caelestia shell launches")

## 6. Hand off for switch + commit

Tell the user to run the switch themselves:

```fish
sudo nixos-rebuild switch --flake .#nixos
```

Do NOT commit or push anything yet. Wait for the user to confirm the switch worked (Hyprland/
Caelestia came up fine, nothing regressed). Only after they explicitly confirm, commit the
updated `flake.lock` (and any config fixes) with a message describing which inputs were
bumped, and push if the user also confirms they want it pushed.
