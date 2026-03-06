{
  config,
  lib,
  pkgs,
  hostname,
  ...
}:

{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts = {
      # Ollama reverse proxy
      "ollama.${hostname}.local" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:11434";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
          '';
        };
      };

      # Open-WebUI reverse proxy
      "webui.${hostname}.local" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
        };
      };
    };
  };

  services.avahi.extraServiceFiles = {
    ollama = ''
      <?xml version="1.0" standalone="no"?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name>Ollama</name>
        <service>
          <type>_http._tcp</type>
          <port>80</port>
          <txt-record>path=/</txt-record>
        </service>
      </service-group>
    '';

    webui = ''
      <?xml version="1.0" standalone="no"?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name>Open WebUI</name>
        <service>
          <type>_http._tcp</type>
          <port>80</port>
          <txt-record>path=/</txt-record>
        </service>
      </service-group>
    '';
  };

  networking.firewall.allowedTCPPorts = lib.mkIf config.services.nginx.enable [ 80 ];
}
