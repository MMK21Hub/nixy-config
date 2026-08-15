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
    upstreams = {
      "copyparty" = {
         servers = {
          "unix:/dev/shm/copyparty.sock" = {
            fail_timeout = "1s";
          };
        };
        extraConfig = ''
          keepalive 1;
        '';
      };
    };
    virtualHosts = {
      "files.slevel.xyz" = {
        default = true;
        http3 = false;
        addSSL = true;
        enableACME = true;
        extraConfig = ''
          # Allow uploads up to 1GB and be tolerant of super slow uploads
          client_max_body_size 1024M;
          client_header_timeout 610m;
          client_body_timeout 610m;
          send_timeout 610m;
        '';
        locations."/" = {
          # Based on https://github.com/9001/copyparty/blob/hovudstraum/contrib/nginx/copyparty.conf
          proxyPass = "http://copyparty";
          extraConfig = ''
            proxy_redirect off;
            # disable buffering
            proxy_http_version 1.1;
            proxy_buffering off;
            proxy_request_buffering off;
            # improve download speed from 600 to 1500 MiB/s
            proxy_buffers 32 8k;
            proxy_buffer_size 16k;
            proxy_busy_buffers_size 24k;
            # headers
            proxy_set_header Connection "Keep-Alive";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
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
  services.copyparty = {
    enable = true;
    settings = {
      i = "unix:770:nginx:/dev/shm/copyparty.sock";
      rproxy = 1;
      xff-hdr = "X-Forwarded-For";
    };
  };
  users.users.copyparty = {
    extraGroups = [ "nginx" ];
  };

  # Streets.gl!
  virtualisation.docker.enable = true;
}
