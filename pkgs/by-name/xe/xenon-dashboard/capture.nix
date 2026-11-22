{
  lib,
  rustPlatform,
  xenon-dashboard,
}:

rustPlatform.buildRustPackage {
  pname = "xenon-dashboard-capture";
  inherit (xenon-dashboard) version src;

  cargoRoot = "apps/capture";
  buildAndTestSubdir = "apps/capture";

  cargoHash = "sha256-Ci7swvOEQuUONwm4idqhpX/5NIP1g26ZVpn7rMjJh4M=";

  meta = xenon-dashboard.meta // {
    description = "Screenshot and recording engine of the Xenon dashboard";
    mainProgram = "xenon-capture";
  };
}
