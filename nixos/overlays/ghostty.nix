_: prev: {
  ghostty = prev.ghostty.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./ghostty-idle-animation.patch ];
  });
}
