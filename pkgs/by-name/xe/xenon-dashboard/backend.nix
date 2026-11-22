{
  lib,
  stdenv,
  buildNpmPackage,
  makeWrapper,
  nodejs,
  callPackage,
  xenon-dashboard,

  # Tools the engine and its capture engine look up on PATH. All optional at
  # runtime: a missing one only hides the feature that needs it. Appended to
  # PATH, so the system's own copies win.
  alsa-utils,
  coreutils,
  curl,
  dbus,
  ffmpeg,
  glib,
  grim,
  gst_all_1,
  iproute2,
  iputils,
  libnotify,
  lm_sensors,
  maim,
  net-tools,
  pipewire,
  playerctl,
  procps,
  pulseaudio,
  slurp,
  unzip,
  wl-clipboard,
  xclip,
  xdg-utils,
  xdotool,
  xinput,
  xprintidle,
  xprop,
  xrandr,
}:

let
  capture = callPackage ./capture.nix { inherit xenon-dashboard; };

  runtimePath = lib.makeBinPath [
    alsa-utils
    coreutils
    curl
    dbus
    ffmpeg
    glib
    grim
    gst_all_1.gstreamer
    iproute2
    iputils
    libnotify
    lm_sensors
    maim
    net-tools
    pipewire
    playerctl
    procps
    pulseaudio
    slurp
    unzip
    wl-clipboard
    xclip
    xdg-utils
    xdotool
    xinput
    xprintidle
    xprop
    xrandr
  ];

  # gst-launch-1.0 reads the ScreenCast portal's PipeWire stream (capture engine).
  gstPluginPath = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    pipewire
  ];
in
buildNpmPackage {
  pname = "xenon-dashboard-backend";
  inherit (xenon-dashboard) version src;

  patches = [
    # User data in $XDG_DATA_HOME/xenon-dashboard instead of the install tree,
    # no self-update, no download of the capture engine or Whisper binary.
    ./backend-nixpkgs.patch
  ];

  npmDepsHash = "sha256-BE2H8Qr4w1W8Rq0mf+Q8PXPjdhmplW1yjbc9IYALNb8=";

  inherit nodejs;

  nativeBuildInputs = [ makeWrapper ];

  # The root postinstall (tools/link-shared.mjs) would link server/shared to the
  # build directory; the link is made relative in installPhase instead.
  npmRebuildFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --no-save --ignore-scripts

    # koffi carries prebuilt binaries for every platform; keep this one's.
    find node_modules/@koromix -mindepth 1 -maxdepth 1 \
      -not -name 'koffi-${stdenv.hostPlatform.node.platform}-${stdenv.hostPlatform.node.arch}' \
      -exec rm -rf {} +
    rm -rf node_modules/@koromix/*/musl_*
    # Workspace links: nothing at runtime resolves them.
    find node_modules -maxdepth 2 -type l -delete

    root=$out/lib/xenon-dashboard
    mkdir -p $root/docs
    cp -r package.json LICENSE node_modules packages server $root/
    cp docs/*.md $root/docs/
    rm -rf $root/server/test $root/packages/*/test
    # Windows only (NirSoft freeware executable).
    rm -rf $root/server/soundvolumeview-x64

    ln -s ../packages/core $root/server/shared
    install -Dm755 ${capture}/bin/xenon-capture $root/server/capture/xenon-capture

    makeWrapper ${lib.getExe nodejs} $out/bin/xenon-backend \
      --add-flags $root/server/server.js \
      --chdir $root \
      --suffix PATH : ${runtimePath} \
      --suffix GST_PLUGIN_SYSTEM_PATH_1_0 : ${gstPluginPath}

    mkdir -p $out/lib/systemd/user
    cat > $out/lib/systemd/user/xenon-backend.service <<EOF
    [Unit]
    Description=Xenon dashboard backend
    Documentation=https://github.com/marcimastro98/Xenon
    After=graphical-session.target network.target

    [Service]
    Type=simple
    ExecStart=$out/bin/xenon-backend
    Restart=on-failure
    RestartSec=3

    [Install]
    WantedBy=graphical-session.target
    EOF

    runHook postInstall
  '';

  passthru = { inherit capture; };

  meta = xenon-dashboard.meta // {
    description = "Backend service of the Xenon dashboard (serves http://127.0.0.1:3030)";
    mainProgram = "xenon-backend";
  };
}
