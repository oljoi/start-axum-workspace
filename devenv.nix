{ pkgs, lib, config, inputs, ... }:

{
  packages = [
    inputs.cargo-leptos.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.binaryen
    pkgs.wasm-bindgen-cli_0_2_114
    pkgs.dart-sass
    pkgs.nixd
    pkgs.rust-analyzer
  ];

  languages.nix = {
    enable = true;
  };

  languages.rust = {
    enable = true;
    channel = {% if nightly == "Yes" %}"nightly"{% else %}"stable"{% endif %};
    components = [ "rustc" "cargo" "clippy" "rustfmt" "rust-analyzer" ];
    targets = [ "wasm32-unknown-unknown" "x86_64-unknown-linux-gnu" ];
  };
}
