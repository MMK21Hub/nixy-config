{ pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  system.stateVersion = "26.11";

  environment.systemPackages = [
    pkgs.micro
    pkgs.git
  ];

  users.users.mish = {
    isNormalUser = true;
    description = "Mish";
    extraGroups = [ "wheel" ];
  };

  users.users.mish.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEILJXRmN3sgOjMZPvuFP2R5/K0+MNSdI4dXXv6OmFW8 mmk21@mish-arch (Main key)"
  ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 ];

    extraCommands = ''
      # Only allow SSH from LAN
      iptables -A nixos-fw -p tcp --dport 22 -s 192.168.1.0/24 -j ACCEPT
      ip6tables -A nixos-fw -p tcp --dport 22 -s fe80::/10 -j ACCEPT
      ip6tables -A nixos-fw -p tcp --dport 22 -s fd00::/8 -j ACCEPT
    '';
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "mish" ];
      MaxAuthTries = 3;
      PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
    };
  };
}
