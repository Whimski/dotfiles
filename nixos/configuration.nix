{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./nvidia-configuration.nix
    ];

  networking.hostName = "rikka";
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    grub = {
       efiSupport = true;
       device = "nodev";
       useOSProber = true;
    };
  };

  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  
  nixpkgs.config.allowUnfree = true;

  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  users.users.tobi = {
    isSystemUser = true;
    home = "/home/tobi";
    group = "tobi";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
  };
  users.groups.tobi = {};
  programs.firefox.enable = true;
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };
  programs.hyprland.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  services.openssh.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;
  services.displayManager = {
    defaultSession = "hyprland";
  };
  services.xserver.displayManager.gdm = {
   enable = true;
  };
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    zsh
    git
    fzf
    python3Full
    nix-search-cli
    kitty
    tmux
    hyprland
    easyeffects
    waybar
    rofi
    gdm
    vesktop
    vscode
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;

  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
  networking.firewall.allowedUDPPorts = [ 22 80 443 ];

  system.copySystemConfiguration = true;
  system.stateVersion = "24.11";

}

