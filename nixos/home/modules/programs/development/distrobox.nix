{
  programs.distrobox = {
    enable = true;
    containers = {
      ubuntu = {
        image = "ubuntu:24.04";
        init_hooks = [
          "sudo apt-get update -y"
          "sudo apt-get install -y ca-certificates"
          "mkdir -p /usr/local/bin/"
          "export PATH=/usr/local/bin:$PATH"
        ];
      };
    };
  };
}
