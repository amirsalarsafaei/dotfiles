{
  config,
  lib,
  pkgs,
  inputs,
  secrets,
  ...
}:
let
  cfg = config.services.amirsalarsafaei-com;
  system = pkgs.system;
  websitePackages = inputs.amirsalarsafaei-com.packages.${system};
  
  # Build frontend with appropriate environment
  frontendPackage = 
    if cfg.frontend.env == "local" 
    then websitePackages.frontendLocal 
    else websitePackages.frontend;

  backendConfigFile = pkgs.writeText "config.toml" ''
    auth_token = "${cfg.authToken}"

    [database]
    url = "postgres://${cfg.database.user}:${cfg.database.password}@localhost:5432/${cfg.database.name}"

    [server]
    host = "127.0.0.1"
    port = ${toString cfg.backend.port}
    allowed_origins = ["${cfg.backend.origin}"]

    [image_server]
    host = "127.0.0.1"
    port = ${toString cfg.backend.imagePort}
    upload_dir = "${cfg.backend.uploadDir}"
  '';

  spotifyConfigFile = pkgs.writeText "spotify.toml" ''
    client_id = "${cfg.spotify.clientId}"
    client_secret = "${cfg.spotify.clientSecret}"
    refresh_token = "${cfg.spotify.refreshToken}"
    redirect_uri = "${cfg.spotify.redirectUri}"
  '';
in
{
  options.services.amirsalarsafaei-com = {
    enable = lib.mkEnableOption "amirsalarsafaei.com personal website";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "amirsalarsafaei.com";
      description = "Domain name for the website";
    };

    authToken = lib.mkOption {
      type = lib.types.str;
      description = "Authentication token for the backend API";
    };

    database = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "amirsalarsafaei";
        description = "PostgreSQL database name";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "amirsalarsafaei";
        description = "PostgreSQL user";
      };

      password = lib.mkOption {
        type = lib.types.str;
        description = "PostgreSQL password";
      };
    };

    spotify = {
      clientId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Spotify client ID";
      };

      clientSecret = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Spotify client secret";
      };

      refreshToken = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Spotify refresh token";
      };

      redirectUri = lib.mkOption {
        type = lib.types.str;
        default = "https://amirsalarsafaei.com/callback";
        description = "Spotify redirect URI";
      };
    };

    backend = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 8000;
        description = "Backend API port";
      };

      imagePort = lib.mkOption {
        type = lib.types.port;
        default = 3001;
        description = "Image server port";
      };

      uploadDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/amirsalarsafaei-com/uploads";
        description = "Upload directory for images";
      };

      origin = lib.mkOption {
        type = lib.types.str;
	default = "https://amirsalarsafaei.com";
	description = "Origin for CORS";
      };
    };

    frontend = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Frontend port";
      };
      
      env = lib.mkOption {
        type = lib.types.enum [ "production" "local" ];
        default = "production";
        description = "Build environment for frontend (production or local)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
      authentication = lib.mkAfter ''
        local ${cfg.database.name} ${cfg.database.user} md5
        host ${cfg.database.name} ${cfg.database.user} 127.0.0.1/32 md5
      '';
    };

    systemd.services.amirsalarsafaei-com-backend = {
      description = "amirsalarsafaei.com Backend";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "postgresql.service"
      ];
      requires = [ "postgresql.service" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${websitePackages.backend}/bin/amirsalarsafaeicom-backend --config-path ${backendConfigFile} --spotify-cred-path ${spotifyConfigFile}";
        Restart = "on-failure";
        RestartSec = "5s";
        User = "amirsalarsafaei";
        Group = "amirsalarsafaei";
        StateDirectory = "amirsalarsafaei-com";
        RuntimeDirectory = "amirsalarsafaei-com";
        WorkingDirectory = "/var/lib/amirsalarsafaei-com";
      };
    };

    users.users.amirsalarsafaei = {
      isSystemUser = true;
      group = "amirsalarsafaei";
      home = "/var/lib/amirsalarsafaei-com";
      createHome = true;
    };

    users.groups.amirsalarsafaei = { };

    systemd.services.amirsalarsafaei-com-frontend = {
      description = "amirsalarsafaei.com Frontend";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "amirsalarsafaei-com-backend.service"
      ];

      environment = {
        PORT = toString cfg.frontend.port;
        HOSTNAME = "127.0.0.1";
        NEXT_PUBLIC_API_URL = "http://127.0.0.1:${toString cfg.backend.port}";
        NODE_ENV = "production";
      };

      serviceConfig = {
        Type = "simple";
        WorkingDirectory = frontendPackage;
        ExecStart = "${pkgs.nodejs_20}/bin/node .next/standalone/server.js";
        Restart = "on-failure";
        RestartSec = "5s";
        User = "amirsalarsafaei";
        Group = "amirsalarsafaei";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.backend.uploadDir} 0755 amirsalarsafaei amirsalarsafaei -"
    ];
  };
}
