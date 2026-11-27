{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.custom.localPostgresql.enable = lib.mkEnableOption "the local PostgreSQL development database";

  config = lib.mkIf config.custom.localPostgresql.enable {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      authentication = lib.mkOverride 10 ''
        local all all peer
        host all all 127.0.0.1/32 scram-sha-256
        host all all ::1/128 scram-sha-256
      '';
      ensureUsers = [
        {
          name = "amirsalar";
          ensureClauses = {
            login = true;
            superuser = true;
            createdb = true;
          };
        }
      ];
    };
  };
}
