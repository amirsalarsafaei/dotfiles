{
  vim = "nvim";

  gitrecent = "git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:short) %(refname:short)'";
  gitshort = "git rev-parse --short=8 HEAD";

  awake = "systemd-inhibit --what=idle:sleep";
  vpn = "pidof openfortivpn || sudo cat ~/totp-pass | totp-cli generate divar vpn | sudo openfortivpn";
}
