{
  vimUtils,
  fetchFromGitHub,
}:
{
  base64Plugin = vimUtils.buildVimPlugin {
    pname = "nvim-base64";
    version = "d5d2f3a";
    src = fetchFromGitHub {
      owner = "deponian";
      repo = "nvim-base64";
      rev = "d5d2f3a6787fb62f06a3f15db346ed84749b1c6b";
      hash = "sha256-zBhSQCxcFh5s1ekyoLy48IKB+nkj9JsUfz+KWSYGVYQ=";
    };
  };

  platformioPlugin = vimUtils.buildVimPlugin {
    pname = "nvim-platformio-lua";
    version = "e65fd65";
    src = fetchFromGitHub {
      owner = "anurag3301";
      repo = "nvim-platformio.lua";
      rev = "e65fd65565da5c1d98c568bd0cdcad16627cdb14";
      hash = "sha256-vIO+Un5BAzVU6JmHueSSRGujaTZcjfVBvh+sq/7CLgk=";
    };
  };
}
