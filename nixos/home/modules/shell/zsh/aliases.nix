{
  # General
  vim = "nvim";

  # Git
  gitrecent = "git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:short) %(refname:short)'";
  gitshort = "git rev-parse --short=8 HEAD";

  # System
  vpn = "pidof openfortivpn || sudo cat ~/totp-pass | totp-cli generate divar vpn | sudo openfortivpn";
}
