{
  description = "rules_wasm_component — Bazel rules for WebAssembly components";

  # Nix provides the *host* environment Bazel runs inside (Bazel, a C/C++
  # compiler, git, python). It deliberately does NOT provide the WebAssembly
  # toolchains — wasm-tools, wasmtime, tinygo, wasi-sdk, spar, witness, synth
  # and friends are downloaded hermetically by Bazel itself, pinned by SHA256
  # in checksums/tools/*.json. The two pinning layers are orthogonal.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # `.bazelversion` (8.2.1) is the single source of truth for the Bazel
        # version. bazelisk reads it and fetches exactly that release, so we
        # never pin the Bazel version twice. Expose it as `bazel` so the
        # documented `bazel build //...` invocation works unchanged.
        bazel = pkgs.writeShellScriptBin "bazel" ''
          exec ${pkgs.bazelisk}/bin/bazelisk "$@"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          name = "rules_wasm_component";

          packages = with pkgs; [
            bazel
            bazelisk

            # Host build prerequisites Bazel itself relies on.
            git
            python3
            cacert
            coreutils

            # Host Rust toolchain for the standalone cargo projects under
            # tools/ and tools-builder/ (lockfile maintenance, dependabot-
            # style updates). The component builds use rules_rust, not this.
            cargo
            rustc

            # Convenience tooling for repository workflows.
            gh
            jq
          ];

          shellHook = ''
            export BAZELISK_HOME="''${BAZELISK_HOME:-$HOME/.cache/bazelisk}"
            echo "rules_wasm_component dev shell"
            echo "  Bazel pinned by .bazelversion ($(cat .bazelversion 2>/dev/null || echo '?'))"
            echo "  Build:  bazel build //..."
          '';
        };
      });
}
