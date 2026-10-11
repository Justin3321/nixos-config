{ pkgs, lib, config, caelestia-shell, caelestia-dots, ... }:

{
  home.username = "senkoi";
  home.homeDirectory = "/home/senkoi";
  home.stateVersion = "26.05";

  imports = [
    caelestia-shell.homeManagerModules.default
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

  # Starship + fish greeting pulled declaratively too, verbatim.
  xdg.configFile."starship.toml".source = "${caelestia-dots}/starship.toml";
  xdg.configFile."fish/functions/fish_greeting.fish".source =
    "${caelestia-dots}/fish/functions/fish_greeting.fish";

  programs.fish = {
    enable = true;
    # Upstream fish/config.fish, read verbatim from the fetched repo (not
    # retyped). It already wraps itself in `if status is-interactive`, so
    # shellInit (unconditional) is safe and simplest here.
    shellInit = builtins.readFile "${caelestia-dots}/fish/config.fish";
  };

  # hyprland.lua resolves `require("hypr-vars")` / `require("hypr-user")`
  # against ~/.config/caelestia/?.lua, and only auto-creates those two files
  # itself (via maybe_create) if ~/.config/caelestia/ already exists -
  # io.open(file, "w") doesn't make parent directories. Since nothing else
  # here ever creates that directory, hyprland.lua crashed on first login
  # with "module 'hypr-vars' not found" before a single keybind was bound.
  # Scaffold the same files upstream's own installer (manifest.toml) and
  # hyprland.lua's maybe_create would, create-if-missing so later hand edits
  # to these (they're meant to be user-editable overrides) survive rebuilds.
  home.activation.caelestiaConfigScaffold = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/caelestia"
    [ -e "$HOME/.config/caelestia/hypr-vars.lua" ] || run bash -c "printf 'return {}\n' > '$HOME/.config/caelestia/hypr-vars.lua'"
    [ -e "$HOME/.config/caelestia/hypr-user.lua" ] || run touch "$HOME/.config/caelestia/hypr-user.lua"
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

  programs.home-manager.enable = true;
}
