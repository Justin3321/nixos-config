{ pkgs, lib, config, caelestia-shell, caelestia-dots, spicetify-nix, ... }:

let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.system};
in
{
  home.username = "senkoi";
  home.homeDirectory = "/home/senkoi";
  home.stateVersion = "26.05";

  imports = [
    caelestia-shell.homeManagerModules.default
    spicetify-nix.homeManagerModules.spicetify
  ];

  # Apps + CLI tools the upstream caelestia-dots hypr/fish config expects
  # (foot/thunar for the SUPER+T / SUPER+E binds, the rest for fish/config.fish
  # and the fish_greeting banner). Firefox (SUPER+W) is already enabled system-wide.
  home.packages = with pkgs; [
    foot
    thunar
    eza
    zoxide
    direnv
    starship
    lazygit
    fastfetch
    pokemon-colorscripts
    btop
    micro
    wl-clipboard
    cliphist

    # Fonts: caskaydia-cove/rubik/material-symbols for caelestia-shell,
    # jetbrains-mono-nerd for hypr/foot/fastfetch per upstream manifest.toml.
    material-symbols
    rubik
    nerd-fonts.caskaydia-cove
    nerd-fonts.jetbrains-mono

    # GTK/Qt theming (see gtk/qt blocks below): adw-gtk3 is the only GTK3
    # theme that actually renders libadwaita's flat dark style instead of
    # the washed-out stock Adwaita; Papirus-Dark is what caelestia's own
    # `caelestia wallpaper`/scheme-apply step (apply_gtk in caelestia-cli)
    # already points dconf's icon-theme at.
    adw-gtk3
    papirus-icon-theme
  ];

  # Hyprland itself: packaging/session only. Real config comes from the
  # upstream hyprland.lua pulled in via xdg.configFile below (Hyprland 0.55+
  # loads hyprland.lua instead of hyprland.conf when it's present), so this
  # extraConfig is just a placeholder to avoid the "empty config" warning.
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    extraConfig = ''
      # Real config lives in hyprland.lua (see xdg.configFile."hypr" in home.nix).
    '';
  };

  # Polkit authentication agent: upstream execs.lua tries to exec a
  # hardcoded /usr/lib/polkit-gnome/... path that doesn't exist on NixOS, so
  # that line silently no-ops. This is the real, Hyprland-native replacement:
  # a proper systemd user service tied to the graphical session.
  services.hyprpolkitagent.enable = true;

  # caelestia-shell's own systemd autostart is disabled: upstream hypr's
  # execs.lua already launches `caelestia shell -d` on hyprland.start, and
  # running both would start the shell twice.
  programs.caelestia = {
    enable = true;
    systemd.enable = false;
    cli.enable = true;
  };

  # Pull the upstream hypr/ directory (hyprland.lua + hyprland/*.lua) in
  # wholesale, unmodified, from the caelestia-dots repo. `recursive = true`
  # keeps the directory itself real/writable (only the leaf files are
  # symlinks into the store) because hyprland.lua writes runtime state next
  # to itself: it copies hypr/scheme/default.lua -> hypr/scheme/current.lua
  # on first run, and misc.lua does `require("scheme.current")` at config
  # load, which would hard-fail Hyprland startup if that copy couldn't
  # happen (i.e. if the whole directory were one read-only symlink).
  xdg.configFile."hypr" = {
    source = "${caelestia-dots}/hypr";
    recursive = true;
  };

  # hypr-user.lua is loaded last by hyprland.lua (after the default "preferred"
  # monitor rule and all of hyprland/*.lua), so values set here win. Declared
  # here instead of left to the create-if-missing scaffold below because we
  # want this content tracked and enforced by rebuilds, not hand-edited.
  #
  # force_zero_scaling alone is the fix for XWayland on a fractional-scale
  # monitor: XWayland renders unscaled and Hyprland upscales the buffer, so
  # X11 apps come out the right size without any toolkit env vars. GDK_SCALE
  # and QT_SCALE_FACTOR were removed: GDK_SCALE only accepts integers (so
  # "1.333333" was being mis-parsed), and both vars apply to native
  # Wayland/Qt clients too (e.g. Quickshell/caelestia-shell itself), which
  # already auto-scale to the monitor's 1.333333 scale via Wayland's
  # fractional-scale protocol - stacking a toolkit-forced scale on top of
  # that double-scaled them.
  xdg.configFile."caelestia/hypr-user.lua".text = ''
    hl.monitor({
        output   = "eDP-1",
        mode     = "2880x1920@120",
        position = "auto",
        scale    = 1.333333,
    })

    hl.config({
        xwayland = {
            force_zero_scaling = true,
        },
    })

    -- NixOS's firefox wrapper already defaults this to "1" when unset, but
    -- set it explicitly so Firefox runs as a native Wayland client (not
    -- XWayland) regardless of upstream wrapper defaults.
    hl.env("MOZ_ENABLE_WAYLAND", "1")

    -- SUPER + I ("gear key"): upstream caelestia-dots never binds a key to
    -- open the settings/control-center window - the only way in is clicking
    -- the gear icon in the bar's utilities popout, which calls
    -- WindowFactory.create() (see caelestia-shell modules/Shortcuts.qml,
    -- CustomShortcut name "nexus"). That's exposed as the Hyprland global
    -- "caelestia:nexus"; bind it here to match GNOME's Super+I convention.
    hl.bind("SUPER + I", hl.dsp.global("caelestia:nexus"))
  '';

  # Starship + fish greeting + foot config pulled declaratively too, verbatim.
  # foot.ini already sets font=JetBrains Mono Nerd Font:size=12, comfortable
  # at the 1.333333 monitor scale.
  xdg.configFile."starship.toml".source = "${caelestia-dots}/starship.toml";
  # fish_greeting is NOT pulled verbatim from upstream like starship/foot
  # below: this is upstream's banner + fastfetch call, with a shiny
  # Charizard (pokemon-colorscripts) tacked on after, same as the old
  # pre-NixOS fish config used to do.
  xdg.configFile."fish/functions/fish_greeting.fish".text = ''
    function fish_greeting
        echo -ne '\x1b[38;5;16m'  # Set colour to primary
        echo '     ______           __          __  _       '
        echo '    / ____/___ ____  / /__  _____/ /_(_)___ _ '
        echo '   / /   / __ `/ _ \/ / _ \/ ___/ __/ / __ `/ '
        echo '  / /___/ /_/ /  __/ /  __(__  ) /_/ / /_/ /  '
        echo '  \____/\__,_/\___/_/\___/____/\__/_/\__,_/   '
        set_color normal
        command -v fastfetch &> /dev/null && fastfetch --key-padding-left 5
        command -v pokemon-colorscripts &> /dev/null && pokemon-colorscripts --no-title -s -n charizard
    end
  '';
  xdg.configFile."foot/foot.ini".source = "${caelestia-dots}/foot/foot.ini";

  programs.fish = {
    enable = true;
    # Upstream fish/config.fish, read verbatim from the fetched repo (not
    # retyped). It already wraps itself in `if status is-interactive`, so
    # shellInit (unconditional) is safe and simplest here.
    shellInit = builtins.readFile "${caelestia-dots}/fish/config.fish";
  };

  # Workflow helpers for this repo. `rebuild`/`update` only prune generations
  # and GC *after* a successful switch, so a broken build never costs
  # existing generations; `nixos-rebuild build` (used elsewhere to validate)
  # never touches generations at all, this is switch-only cleanup.
  xdg.configFile."fish/functions/rebuild.fish".text = ''
    function rebuild --description "Switch to the flake config, then prune old generations"
        sudo nixos-rebuild switch --flake ~/nixos-config#nixos
        if test $status -ne 0
            echo "rebuild: nixos-rebuild switch failed, leaving generations untouched" >&2
            return 1
        end

        echo "rebuild: switch succeeded, pruning generations..."
        sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +3
        sudo nix-collect-garbage -d
        # Re-run the already-built system's activation in "boot" mode: this
        # regenerates the systemd-boot menu from the generations that still
        # exist (pruning entries for the ones just deleted) without building
        # a new generation.
        sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
    end
  '';
  xdg.configFile."fish/functions/update.fish".text = ''
    function update --description "Update flake inputs, then rebuild"
        pushd ~/nixos-config
        or return 1

        # nix flake update already prints a per-input "updated/unchanged"
        # summary on its own, so no extra diffing is needed here.
        nix flake update
        if test $status -ne 0
            popd
            return 1
        end

        popd
        rebuild
    end
  '';
  xdg.configFile."fish/functions/save.fish".text = ''
    function save --description "Commit and push nixos-config" --argument-names message
        if test -z "$message"
            echo "usage: save \"commit message\"" >&2
            return 1
        end

        pushd ~/nixos-config
        or return 1

        git add -A
        git commit -m "$message"
        if test $status -eq 0
            git push
        end

        popd
    end
  '';
  xdg.configFile."fish/functions/gens.fish".text = ''
    function gens --description "List system generations"
        nixos-rebuild list-generations
    end
  '';
  xdg.configFile."fish/functions/cfg.fish".text = ''
    function cfg --description "cd to nixos-config and launch claude"
        cd ~/nixos-config
        claude
    end
  '';

  # hyprland.lua resolves `require("hypr-vars")` / `require("hypr-user")`
  # against ~/.config/caelestia/?.lua, and only auto-creates those two files
  # itself (via maybe_create) if ~/.config/caelestia/ already exists -
  # io.open(file, "w") doesn't make parent directories. Since nothing else
  # here ever creates that directory, hyprland.lua crashed on first login
  # with "module 'hypr-vars' not found" before a single keybind was bound.
  # Scaffold the same files upstream's own installer (manifest.toml) and
  # hyprland.lua's maybe_create would, create-if-missing so later hand edits
  # to these (they're meant to be user-editable overrides) survive rebuilds.
  # hypr-user.lua is excluded here: it's now managed declaratively above via
  # xdg.configFile, which creates it (and ~/.config/caelestia/) itself.
  home.activation.caelestiaConfigScaffold = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/caelestia"
    [ -e "$HOME/.config/caelestia/hypr-vars.lua" ] || run bash -c "printf 'return {}\n' > '$HOME/.config/caelestia/hypr-vars.lua'"
    [ -e "$HOME/.config/caelestia/user-config.fish" ] || run touch "$HOME/.config/caelestia/user-config.fish"
  '';

  # Default wallpaper on first login: `caelestia wallpaper -f` is what the
  # picker itself calls, so this also generates the matching colour scheme
  # instead of just dropping a path into state. Create-if-missing, same as
  # the scaffold above - once the picker has been used, ~/.local/state/
  # caelestia/wallpaper/path.txt exists and this must not override that choice.
  home.activation.caelestiaDefaultWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.local/state/caelestia/wallpaper/path.txt" ] && [ -f "$HOME/Pictures/Wallpapers/shougan_castle.png" ]; then
      run ${config.programs.caelestia.cli.package}/bin/caelestia wallpaper -f "$HOME/Pictures/Wallpapers/shougan_castle.png"
    fi
  '';

  # GTK theming: Thunar and other GTK apps otherwise render in stock
  # (light, washed-out) Adwaita under Hyprland since there's no GNOME
  # session/XDG portal driving gsettings here. adw-gtk3-dark is upstream
  # caelestia-dots' own choice of GTK theme (manifest.toml's "gtk"
  # component installs "adw-gtk-theme" + Papirus on Arch); matching it
  # here means this baseline agrees with what caelestia-cli's own
  # wallpaper/scheme-apply step (apply_gtk in theme.py) writes to dconf
  # every time the wallpaper/scheme changes - that step also drops
  # accent-coloured CSS into ~/.config/gtk-{3,4}.0/gtk.css directly
  # (outside home-manager, since it's regenerated per-wallpaper), which
  # is untouched here because gtk3/gtk4.extraCss is left unset.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Rubik";
      size = 11;
    };
    # Also flips dconf's org/gnome/desktop/interface color-scheme to
    # "prefer-dark" (see gtk3.nix/gtk4.nix), which is what GTK4/libadwaita
    # apps (and caelestia's own re-application of this same key) read to
    # decide light vs dark.
    colorScheme = "dark";
  };

  # Qt platform theme: without this, Qt/KDE apps ignore the GTK theme
  # entirely and fall back to whatever default Qt style ships with the
  # distro, looking inconsistent next to GTK apps. "gtk" makes Qt read
  # the active GTK3 theme (adw-gtk3-dark, set above) directly via
  # qt6gtk2/qtstyleplugins instead of needing a separate Qt theme.
  qt = {
    enable = true;
    platformTheme.name = "gtk";
  };

  # Spicetify: wraps/patches the Nix-store Spotify package, so this replaces
  # any `pkgs.spotify` package reference elsewhere (there isn't one here).
  # StarryNight's "Base" color scheme is a black night sky + shooting-star
  # CSS animation (see theme.js, auto-injected by inject_theme_js, which
  # defaults to true) - the closest built-in match to a dark meteor-shower
  # look. Other bundled schemes in the same theme: Cotton-candy, Forest,
  # Galaxy, Orange, Sky, Sunrise.
  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.starryNight;
    colorScheme = "Base";
    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      shuffle
      fullAppDisplay
    ];
  };

  programs.home-manager.enable = true;
}
