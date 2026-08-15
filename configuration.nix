{ pkgs, modulesPath, lib, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];
  system.stateVersion = "26.11";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = [
    pkgs.micro
    pkgs.git
    pkgs.lazygit
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
    allowedTCPPorts = [ 80 443 ];

    extraCommands = ''
      # Only allow SSH and Netdata from LAN
      iptables -A nixos-fw -p tcp -m multiport --dports 22,19999 -s 192.168.1.0/24 -j ACCEPT
      ip6tables -A nixos-fw -p tcp -m multiport --dports 22,19999 -s fe80::/10 -j ACCEPT
      ip6tables -A nixos-fw -p tcp -m multiport --dports 22,19999 -s fd00::/8 -j ACCEPT
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

  environment.variables = {
    EDITOR = "micro";
    VISUAL = "micro";
  };

  services.netdata = {
    enable = true;
    config.global = {
      #"memory mode" = "ram";
      "debug log" = "none";
      "access log" = "none";
      "error log" = "syslog";
    };
    package = pkgs.netdata.override {
      withCloudUi = true;
    };
  };
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "netdata"
  ];

  # Nginx!
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "postmaster@slevel.xyz";

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "files.slevel.xyz" = {
        default = true;
        quic = true;
        http3 = true;
        addSSL = true;
        enableACME = true;

        root = "/var/www/files";
        locations."/" = {
          extraConfig = ''
            autoindex on;
            autoindex_exact_size off; # Human-readable file sizes
            autoindex_localtime on;   # Local time zone timestamps
          '';
        };
      };
      "streets.slevel.xyz" = {
        quic = true;
        http3 = true;
        addSSL = true;
        enableACME = true;
        root = "/var/www/streets-gl";
        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
        };
      };
      "tiles.streets.slevel.xyz" = {
        quic = true;
        http3 = true;
        addSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://localhost:8080";
        };
      };
    };
  };

  # Copyparty!
  #inputs.copyparty.url = "github:9001/copyparty";

  # Streets.gl!
  virtualisation.docker.enable = true;
}
