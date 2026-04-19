{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
    cargo-leptos.url = "github:oljoi/cargo-leptos";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
      rust-overlay,
      cargo-leptos,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      cargoToml = fromTOML (builtins.readFile (self + /Cargo.toml));
      inherit (cargoToml.workspace.package) name version;

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

      mkCraneBuild =
        system:
        let
          pkgs = mkPkgs system;
          inherit (pkgs) lib;

          craneLib = (crane.mkLib pkgs).overrideToolchain (
            p:
            p.rust-bin.nightly.latest.default.override {
              targets = [
                "x86_64-unknown-linux-gnu"
                "wasm32-unknown-unknown"
              ];
            }
          );
        in
        rec {
          args = {
            src = lib.cleanSourceWith {
              src = lib.cleanSource self;
              filter =
                path: type:
                (lib.hasSuffix "\.html" path)
                || (lib.hasSuffix "\.scss" path)
                || (lib.hasSuffix "\.css" path)
                || (lib.hasSuffix "tailwind.config.js" path)
                || (lib.hasInfix "/assets/" path)
                || (lib.hasInfix "/css/" path)
                || (lib.hasInfix "/public/" path)
                || (craneLib.filterCargoSources path type);
            };
            pname = name;
            version = version;
            buildInputs = [
              cargo-leptos.packages.${system}.default
              pkgs.binaryen
              pkgs.wasm-bindgen-cli_0_2_114
              pkgs.dart-sass
            ];
          };
          cargoArtifacts = craneLib.buildDepsOnly args;
          buildArgs = args // {
            inherit cargoArtifacts;
            buildPhaseCargoCommand = "cargo leptos build --release -vvv";
            doNotPostBuildInstallCargoBinaries = true;
            nativeBuildInputs = [
              pkgs.makeWrapper
            ];
            installPhaseCommand = ''
              mkdir -p $out/bin
              mv target/release/server $out/bin/${name}
              cp -r target/site $out/bin/
              wrapProgram $out/bin/${name} \
                --set LEPTOS_SITE_ROOT $out/bin/site
            '';
          };
          package = craneLib.buildPackage buildArgs;

          check = craneLib.cargoClippy (
            args
            // {
              inherit cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets --all-features -- --deny warnings";
            }
          );

          doc = craneLib.cargoDoc (
            args
            // {
              inherit cargoArtifacts;
            }
          );
        };
    in
    {
      packages = forAllSystems (system: {
        default = (mkCraneBuild system).package;
      });

      checks = forAllSystems (system: {
        clippy = (mkCraneBuild system).check;
        doc = (mkCraneBuild system).doc;
      });

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.${name};
        in
        with lib;
        {
          options.services.${name} = {
            enable = mkEnableOption "${name} leptos-rs server";

            port = mkOption {
              type = types.port;
              default = 3000;
              description = "port server listens on";
            };

            address = mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = "address to bind to";
            };
          };

          config = mkIf cfg.enable {
            systemd.services.${name} = {
              description = "${name} leptos server";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              serviceConfig = {
                ExecStart = "${self.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/${name}";
                Restart = "on-failure";
                RestartSec = "5s";
                DynamicUser = true;
                Environment = [
                  "LEPTOS_OUTPUT_NAME=${name}"
                  "LEPTOS_SITE_ADDR=${cfg.address}:${toString cfg.port}"
                ];
              };
            };
          };
        };
    };
}
