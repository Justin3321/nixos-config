# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

let
  # sddm-astronaut, pinned to the "pixel_sakura" embedded variant (the animated
  # 8-bit train + cherry blossoms theme, not "pixel_sakura_static"). ScreenWidth/
  # ScreenHeight are overridden via the package's themeConfig knob (written out as
  # Themes/pixel_sakura.conf.user, which SDDM layers on top of the theme's own
  # pixel_sakura.conf) to match this panel's native 2880x1920 panel: the theme's
  # Main.qml sizes its root item from config.ScreenWidth/ScreenHeight if set
  # (falling back to Screen.width/height only when blank), and ships with those
  # defaulting to "1920"/"1080", so without this override the greeter renders in a
  # fixed 1920x1080 canvas instead of filling/scaling to the real screen.
  sddmAstronautTheme = pkgs.sddm-astronaut.override {
    embeddedTheme = "pixel_sakura";
    themeConfig = {
      ScreenWidth = "2880";
      ScreenHeight = "1920";
    };
  };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Compressed RAM swap instead of (or alongside) a disk swap partition.
  zramSwap.enable = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the GNOME Desktop Environment (kept as a fallback session).
  services.displayManager.gdm.enable = false;
  services.desktopManager.gnome.enable = true;

  # SDDM (Qt6, kdePackages build) replaces GDM as the login screen. Session
  # choice (Hyprland vs GNOME) is unaffected: those .desktop entries come from
  # programs.hyprland/services.desktopManager.gnome, not from the display
  # manager, so both still show up in SDDM's session picker.
  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    # Qt plugins the animated (video/gif) astronaut theme needs at runtime:
    # qtmultimedia for the background video/gif playback, qtsvg for its
    # vector icons, qtvirtualkeyboard for the on-screen keyboard toggle.
    extraPackages = with pkgs.kdePackages; [
      qtmultimedia
      qtsvg
      qtvirtualkeyboard
    ];
  };

  # Enable Hyprland as the primary Wayland session.
  programs.hyprland.enable = true;

  # polkit itself; the actual authentication-agent UI is a hyprpolkitagent
  # systemd user service, enabled in home.nix.
  security.polkit.enable = true;

  # Firmware updates (fwupd) and CPU/power profile switching (power-profiles-daemon),
  # both relevant on Framework hardware.
  services.fwupd.enable = true;
  services.power-profiles-daemon.enable = true;

  # GNOME Keyring: works under both the GNOME and Hyprland sessions since the
  # display manager's password prompt is what unlocks it (not the desktop
  # session you launch afterwards). No per-DM enableGnomeKeyring flag is set
  # here (unlike GDM, the nixpkgs sddm module doesn't read one on its "sddm"
  # PAM service - it's a no-op there, since that service sets
  # useDefaultRules = false and the generic enableGnomeKeyring plumbing in
  # pam.nix only fires under useDefaultRules = true). The unlock still
  # happens: services.gnome.gnome-keyring.enable sets
  # security.pam.services.login.enableGnomeKeyring = true, baking
  # pam_gnome_keyring auth/password/session lines into /etc/pam.d/login, and
  # sddm's auth/password/session rules substack/include that same "login"
  # PAM service, inheriting those lines automatically.
  services.gnome.gnome-keyring.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."senkoi" = {
    isNormalUser = true;
    description = "Senkoi";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Registers fish in /etc/shells so it can be used as a login shell above.
  programs.fish.enable = true;

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

nix.settings = {
  experimental-features = [ "nix-command" "flakes" ];
  auto-optimise-store = true;
};

# Keep the nix store from growing unbounded.
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 14d";
};


  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
   environment.systemPackages = with pkgs; [
     vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
     wget
	gh
	git
	claude-code
	vesktop
	sddmAstronautTheme # Populates /run/current-system/sw/share/sddm/themes for SDDM's ThemeDir.
   ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
