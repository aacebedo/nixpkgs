{
  lib,
  rustPlatform,
  fetchFromGitHub,
  callPackage,
  jq,
  moreutils,
  cargo-tauri,
  pkg-config,
  wrapGAppsHook3,
  coreutils,
  glib-networking,
  gst_all_1,
  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "xenon-dashboard";
  version = "5.2.0";

  src = fetchFromGitHub {
    owner = "marcimastro98";
    repo = "Xenon";
    tag = "v${finalAttrs.version}";
    # apps/native is export-ignore'd, so it is missing from GitHub's tarballs.
    forceFetchGit = true;
    hash = "sha256-4DjvgvTovtL6ANv0auvGbhSVAyVFojBy53nYOKeT/Is=";
  };

  patches = [
    # Start the engine from the Nix store, no self-update, and a login entry
    # that survives garbage collection.
    ./native-nixpkgs.patch
  ];

  postPatch = ''
    # Updater artifacts need upstream's signing key.
    jq '.bundle.createUpdaterArtifacts = false' apps/native/src-tauri/tauri.conf.json \
      | sponge apps/native/src-tauri/tauri.conf.json
    # The bootstrap script downloads and installs the engine into $HOME.
    jq '.bundle.resources = []' apps/native/src-tauri/tauri.linux.conf.json \
      | sponge apps/native/src-tauri/tauri.linux.conf.json
  '';

  cargoRoot = "apps/native/src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  cargoHash = "sha256-lhkgeQ43UKB0izfKch7g4t++m3cduGXZDJ/Q+z96L0Q=";

  nativeBuildInputs = [
    jq
    moreutils
    cargo-tauri.hook
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    glib-networking
    # The dashboard plays sounds (TTS, sound packs, media previews) in WebKit.
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    libayatana-appindicator
    openssl
    webkitgtk_4_1
  ];

  checkFlags = [
    # Expects a debug build, where the `tauri dev` server counts as our own page.
    "--skip=nav_policy::tests::loopback_is_our_page_only_on_our_port"
  ];

  postInstall = ''
    mkdir -p $out/share/systemd/user
    ln -s ${finalAttrs.passthru.backend}/share/systemd/user/xenon-backend.service \
      $out/share/systemd/user/xenon-backend.service
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set-default XENON_BACKEND ${lib.getExe finalAttrs.passthru.backend}
      --set-default XENON_AUTOSTART_EXEC ${finalAttrs.meta.mainProgram}
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
      --suffix PATH : ${lib.makeBinPath [ coreutils ]}
    )
  '';

  # After wrapGAppsHook3: the backend is not a GTK program.
  postFixup = ''
    ln -s ${lib.getExe finalAttrs.passthru.backend} $out/bin/xenon-backend
  '';

  passthru = {
    backend = callPackage ./backend.nix { xenon-dashboard = finalAttrs.finalPackage; };
    inherit (finalAttrs.passthru.backend) capture;
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage"
        "backend"
        "--subpackage"
        "capture"
      ];
    };
  };

  meta = {
    description = "Widgets dashboard for a second screen, tablet or phone: system monitor, media, deck keys";
    longDescription = ''
      Xenon is a local dashboard for any second screen: a monitor, a
      touchscreen, a paired phone or tablet, or a CORSAIR Xeneon Edge. It shows
      media controls, audio devices, calendar, notes, live system stats and
      more.

      `xenon-native` is the full-screen window. It starts the dashboard
      backend (`xenon-backend`, served on http://127.0.0.1:3030) as its own
      child, unless the `xenon-backend.service` systemd user unit shipped in
      this package is enabled, which keeps the dashboard available to paired
      devices while the window is closed. User data lives in
      `$XDG_DATA_HOME/xenon-dashboard`.
    '';
    homepage = "https://xenon-app.com/";
    changelog = "https://github.com/marcimastro98/Xenon/releases/tag/v${finalAttrs.version}";
    # Custom non-commercial license.
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ aacebedo ];
    mainProgram = "xenon-native";
    platforms = lib.platforms.linux;
  };
})
