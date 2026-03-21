return {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    -- Nix store toolchains (ESP-IDF Xtensa/RISC-V)
    "--query-driver="
    .. "/nix/store/*/bin/xtensa-*,"
    .. "/nix/store/*/bin/riscv32-*,"
    .. "/nix/store/*/bin/*-gcc,"
    .. "/nix/store/*/bin/*-g++,"
    -- PlatformIO Espressif toolchains (in ~/.platformio)
    .. vim.env.HOME .. "/.platformio/packages/toolchain-xtensa-esp*/bin/*,"
    .. vim.env.HOME .. "/.platformio/packages/toolchain-riscv32-esp*/bin/*,"
    .. vim.env.HOME .. "/.platformio/packages/toolchain-esp*/bin/*",
    "--compile-commands-dir=.",
    "--header-insertion=iwyu",
    "--suggest-missing-includes",
  },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }, -- Explicitly exclude proto files
  init_options = {
    clangdFileStatus = true,
    usePlaceholders = true,
    completeUnimported = true,
    semanticHighlighting = true,
  }
}
