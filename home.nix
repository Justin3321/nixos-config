{ pkgs, caelestia-shell, caelestia-dots, ... }:

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

  programs.home-manager.enable = true;
}
