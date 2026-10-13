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

  # Workaround for an upstream Hyprland bug: the "hyprland" session nixpkgs
  # generates (programs.hyprland's own sessionPackages entry) has its .desktop
  # Exec= pointing at "start-hyprland", a watchdog wrapper that forks the real
  # Hyprland binary and waits on it from a background thread. On logout,
  # systemd delivers SIGTERM directly to every process in the session scope,
  # including start-hyprland itself. Its signal handler (start/src/core/
  # Instance.cpp forceQuit(), called from start/src/main.cpp onSignal()) does
  # `kill(child); m_hlThread.join();` unconditionally - if the signal happens
  # to land on m_hlThread itself (the kernel picks an arbitrary thread,
  # there's no pthread_sigmask blocking it there), that's a self-join, which
  # libstdc++ turns into an uncaught std::system_error -> std::terminate ->
  # SIGABRT. SDDM then treats the session as "crashed" rather than a clean
  # logout and never respawns the greeter, leaving a black screen on VT1
  # until `systemctl restart display-manager` from a TTY. Confirmed via
  # `coredumpctl info` on this machine; still present as of Hyprland 0.56.2 /
  # upstream main (checked hyprwm/Hyprland's start/src/core/Instance.cpp).
  #
  # Bypassing start-hyprland avoids the race entirely: launching the real
  # Hyprland binary directly (still through its cap_sys_nice wrapper at
  # security.wrapperDir, same as start-hyprland's execvp("Hyprland", ...)
  # would resolve to via PATH) is explicitly supported - Hyprland's own
  # main.cpp just logs "launched without start-hyprland, highly advised
  # against" and continues normally. The only loss is start-hyprland's crash
  # auto-restart-in-safe-mode feature, which isn't worth a black-screen-on-
  # every-logout bug. Set as services.displayManager.sessionPackages /
  # defaultSession below; remove this once upstream fixes the self-join.
  hyprlandDirectSession = pkgs.runCommand "hyprland-direct-session"
    {
      passthru.providedSessions = [ "hyprland-direct" ];
    }
    ''
      mkdir -p $out/share/wayland-sessions
      cat > $out/share/wayland-sessions/hyprland-direct.desktop <<EOF
      [Desktop Entry]
      Name=Hyprland
      Comment=Dynamic tiling Wayland compositor (launched directly; see configuration.nix for why)
      Exec=${config.security.wrapperDir}/Hyprland
      Type=Application
      DesktopNames=Hyprland
      Keywords=tiling;wayland;compositor;
      EOF
    '';

  # Workaround for a long-standing, still-open SDDM bug (e.g. sddm/sddm#1573,
  # #1352, #1733 - no release since 0.21.0/Feb 2024 to pick up a fix): on
  # logout, systemd/logind kills every process in the session scope at once,
  # including sddm-helper itself (confirmed via `journalctl`: "session-N.scope:
  # Killing process N (sddm-helper) with signal SIGTERM"). sddm-helper dying
  # that way is reported to SDDM's Auth class as a non-normal QProcess exit
  # (src/auth/Auth.cpp childExited()), which logs the misleading "Process
  # crashed" line seen in `journalctl -u display-manager` - this is not a
  # real crash, just SDDM mislabeling any signal-killed helper. The actual bug
  # is in src/daemon/Display.cpp slotHelperFinished(): it only calls stop()
  # (the function that recreates the Display and switches the VT back to the
  # greeter) when the resulting exit status is anything other than
  # HELPER_AUTH_ERROR - a guard meant to keep a failed-password greeter on
  # screen - but a signal-killed helper's exit code happens to land on that
  # exact enum value by coincidence, so stop() is silently skipped and the
  # greeter (alive but suspended, confirmed via its Xorg log ending on
  # "Suspending AIGLX clients for VT switch" with nothing after) never comes
  # back on any VT. Confirmed this is independent of the greeter's own
  # backend (reproduced identically with wayland.enable = true and false) and
  # independent of the start-hyprland crash fixed above (reproduced with zero
  # coredumps via hyprland-direct too).
  #
  # This script polls logind for the specific session SDDM launches for
  # senkoi (Service=sddm, Class=user, Name=senkoi - NOT the "login"/tty
  # sessions a plain TTY login or `sudo` produces, which have Service=login
  # and Class=user/manager respectively) and restarts display-manager.service
  # the moment that exact session disappears - the same recovery action done
  # by hand via a TTY until now, just automatic. Remove this once upstream
  # fixes slotHelperFinished().
  restartSddmAfterLogoutScript = pkgs.writeShellScript "restart-sddm-after-logout" ''
    set -eu
    LOGINCTL=${pkgs.systemd}/bin/loginctl
    SYSTEMCTL=${pkgs.systemd}/bin/systemctl
    TARGET_USER="senkoi"

    prev_present=0
    while true; do
      present=0
      while read -r sid _ user _; do
        [ -n "$sid" ] || continue
        service=$("$LOGINCTL" show-session "$sid" -p Service --value 2>/dev/null || true)
        class=$("$LOGINCTL" show-session "$sid" -p Class --value 2>/dev/null || true)
        if [ "$service" = "sddm" ] && [ "$class" = "user" ] && [ "$user" = "$TARGET_USER" ]; then
          present=1
        fi
      done <<EOF
    $("$LOGINCTL" list-sessions --no-legend 2>/dev/null)
    EOF

      if [ "$prev_present" = "1" ] && [ "$present" = "0" ]; then
        if [ "$("$SYSTEMCTL" is-system-running 2>/dev/null)" != "stopping" ]; then
          "$SYSTEMCTL" restart display-manager.service
        fi
      fi
      prev_present=$present
      sleep 2
    done
  '';
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
  #
  # defaultSession picks which one is pre-selected (GDM defaulted to GNOME;
  # SDDM otherwise pre-selects whatever was logged into last, which on a
  # fresh switch to SDDM is nothing, so it falls back to the first entry in
  # sessionNames - GNOME). Value is the hyprland package's providedSessions
  # name ("hyprland"), i.e. the plain hyprland.desktop entry, not
  # "hyprland-uwsm" (programs.hyprland.withUWSM is not enabled here).
  services.displayManager.defaultSession = "hyprland-direct";

  # Adds the hyprland-direct session (see hyprlandDirectSession above) to the
  # picker, alongside the "hyprland"/"hyprland-uwsm" sessions programs.hyprland
  # already registers for itself.
  services.displayManager.sessionPackages = [ hyprlandDirectSession ];

  # wayland.enable is off: nixpkgs' own module calls it "experimental Wayland
  # support", and in practice its embedded Weston greeter never respawns
  # after a Hyprland session ends - confirmed on this machine by a clean
  # (zero-coredump) hyprland-direct logout that still black-screened until
  # `systemctl restart display-manager` from a TTY, with nothing in between
  # in the journal. The mature X11 greeter backend doesn't have this problem.
  # This only changes what renders the *greeter* (sddm-greeter-qt6, so the
  # sddm-astronaut pixel_sakura theme looks identical either way) - the
  # actual session (hyprland-direct) still runs pure Wayland. sddm's module
  # asserts xserver.enable || wayland.enable, hence xserver.enable below.
  services.xserver.enable = true;

  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;
    wayland.enable = false;
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

  # See restartSddmAfterLogoutScript above for why this exists.
  systemd.services.restart-sddm-after-logout = {
    description = "Restart SDDM after the senkoi/sddm Hyprland session ends (workaround for sddm/sddm#1573)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-logind.service" ];
    conflicts = [ "shutdown.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = restartSddmAfterLogoutScript;
      Restart = "always";
      RestartSec = 2;
    };
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

  # nsncd (the default Rust reimplementation of nscd) can't parse
  # GETSERVBYNAME requests on this glibc release and spins logging "Could
  # not parse service request" several times a second forever, burning
  # CPU. Fall back to glibc's own nscd, which is always protocol-compatible
  # with the glibc making the request.
  services.nscd.enableNsncd = false;

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
	vscode
	sddmAstronautTheme # Populates /run/current-system/sw/share/sddm/themes for SDDM's ThemeDir.
	# Terminal eye-candy for the "larping" desktop
	lavat # lava lamp simulation
	cmatrix # Matrix digital rain
	cbonsai # terminal bonsai tree
	cava # audio visualizer
	pipes # animated pipes filling the screen
	asciiquarium # ASCII aquarium
	unimatrix # unicode-based matrix-rain variant
	nyancat # the classic
	hollywood # fills terminal panes with movie-hacker nonsense
	genact # fake "hard at work" progress bars/logs
	tty-clock # big ASCII clock
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
