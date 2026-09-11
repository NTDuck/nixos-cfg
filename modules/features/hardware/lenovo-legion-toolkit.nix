{den, ...}: {
  # https://github.com/bolekjar/lenovo-legion-linux-toolkit
  # Kernel driver (LenovoLegion-dkms) + root daemon + Qt6 GUI + CLI, packaged
  # from the upstream Arch PKGBUILD layout. Upstream installs into
  # /opt/LenovoLegion with runtime writes next to the binaries; here the
  # binaries live in the store and state is redirected by source patches to
  # /var/lib/lenovo-legion-daemon (systemd StateDirectory) and
  # $XDG_STATE_HOME/lenovo-legion (GUI).
  den.aspects.hardware.lenovo-legion-toolkit = {
    nixos = {
      config,
      pkgs,
      lib,
      ...
    }: let
      version = "1.4.0";
      src = pkgs.fetchzip {
        name = "lenovo-legion-linux-toolkit-release-${version}";
        url = "https://github.com/bolekjar/lenovo-legion-linux-toolkit/archive/refs/tags/release/${version}.tar.gz";
        hash = "sha256-zPZkvS3EvfuLFaqG6mVIl4zdNfq32NYW1ChDB3b61+M=";
      };

      # The daemon is the only NVML consumer (GPU monitor page): nvml.h comes
      # from cuda_nvml_dev, libnvidia-ml.so from the driver package. Upstream
      # expects an SDK layout at CUDA_PATH: include/ + lib64/.
      nvidia-x11 = config.boot.kernelPackages.nvidia_x11 or null;
      nvml-include = pkgs.cudaPackages.cuda_nvml_dev.include or null;
      cuda-path = pkgs.runCommand "lenovo-legion-toolkit-cuda-path" {} ''
        mkdir -p "$out/include" "$out/lib64"
        ln -s "${nvml-include}/include/nvml.h" "$out/include/nvml.h"
        ln -s "${nvidia-x11}/lib/libnvidia-ml.so" "$out/lib64/"
        ln -s "${nvidia-x11}/lib/libnvidia-ml.so.1" "$out/lib64/"
      '';

      # .qmake.conf hardcodes /usr/bin/* tool paths and derives the version
      # from `git describe` (absent in the tarball). Bare names resolve via
      # PATH when qmake runs system().
      qmake-paths-patch = ''
        sed -i \
          -e 's|^SYSTEM_MKDIR.*|SYSTEM_MKDIR = mkdir|' \
          -e 's|^SYSTEM_CP.*|SYSTEM_CP = cp|' \
          -e 's|^SYSTEM_PROTOC.*|SYSTEM_PROTOC = protoc|' \
          -e 's|^CUDA_PATH.*|CUDA_PATH = ${cuda-path}|' \
          -e "s|^APPLICATION_VERSION.*|APPLICATION_VERSION = ${version}|" \
          .qmake.conf
      '';

      # qmake_all generates every subdir Makefile (the protobuf sources are
      # produced by `protoc` through system() while qmake processes
      # LenovoLegion-PrepareBuild.pro); the PrepareBuild dummy lib then
      # creates the Installation/, Lib/ and modules/ output directories that
      # the parallel sub-builds write into. BJLibs-UnitTests is dropped.
      buildPhase = target: ''
        runHook preBuild
        sed -i -e '/BJLibs-UnitTests/d' BJLibs/BJLibs.pro
        qmake -o LenovoLegion-PrepareBuild/Makefile LenovoLegion-PrepareBuild/LenovoLegion-PrepareBuild.pro
        make -C LenovoLegion-PrepareBuild
        qmake -o BJLibs/Makefile BJLibs/BJLibs.pro
        qmake -o BJLibs/BJLibs-Application/Makefile BJLibs/BJLibs-Application/BJLibs-Application.pro
        make -j $NIX_BUILD_CORES -C BJLibs/BJLibs-Application
        qmake -o ${target}/Makefile ${target}/${target}.pro
        make -j $NIX_BUILD_CORES -C ${target}
        runHook postBuild
      '';

      kernel-module =
        config.boot.kernelPackages.callPackage
        ({
          kernel,
          kernelModuleMakeFlags,
          stdenv,
        }:
          stdenv.mkDerivation {
            pname = "lenovo-legion-toolkit-module";
            inherit version src;

            sourceRoot = "${src.name}/LenovoLegion-dkms";

            hardeningDisable = ["pic"];

            makeFlags =
              kernelModuleMakeFlags
              ++ [
                "KERNEL_VERSION=${kernel.modDirVersion}"
                "KSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
              ];

            installPhase = ''
              runHook preInstall
              install -Dm644 lenovo_legion.ko \
                "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/platform/x86/lenovo_legion.ko"
              runHook postInstall
            '';

            nativeBuildInputs = kernel.moduleBuildDependencies;

            meta = {
              description = "lenovo_legion kernel driver from lenovo-legion-linux-toolkit";
              homepage = "https://github.com/bolekjar/lenovo-legion-linux-toolkit";
              license = lib.licenses.gpl2Only;
              platforms = ["x86_64-linux"];
            };
          }) {};

      daemon =
        pkgs.qt6Packages.callPackage
        ({
          stdenv,
          qmake,
          wrapQtAppsHook,
          pkg-config,
          qtbase,
          qt5compat,
          protobuf,
          hidapi,
          systemd,
        }:
          stdenv.mkDerivation {
            pname = "lenovo-legion-toolkit-daemon";
            inherit version src;

            sourceRoot = "${src.name}/LenovoLegion";

            postPatch = ''
              ${qmake-paths-patch}

              # Static BJLibs references Qt5Compat symbols.
              substituteInPlace LenovoLegion-Daemon/LenovoLegion-Daemon.pro \
                --replace 'QT       += core network' 'QT       += core network core5compat'

              # Redirect log + QSettings from the read-only binary dir to the
              # systemd state directory. The Settings ctor spans lines 14-18;
              # replace its head and drop the orphaned .append lines.
              substituteInPlace LenovoLegion-Daemon/Application.cpp \
                --replace 'QCoreApplication::applicationDirPath().append(QDir::separator()).append(bj::framework::Application::log_dir).append(QDir::separator()).append(bj::framework::Application::apps_names[1]).append(".log").toStdString()' 'std::string("/var/lib/lenovo-legion-daemon/LenovoLegion-Daemon.log")'

              sed -i \
                -e '14s|m_settings(QCoreApplication::applicationDirPath()|m_settings(QString("/var/lib/lenovo-legion-daemon/LenovoLegion-Daemon.ini"), QSettings::IniFormat)|' \
                -e '15,18d' \
                LenovoLegion-Daemon/Settings.cpp
            '';

            nativeBuildInputs = [qmake wrapQtAppsHook pkg-config protobuf];
            buildInputs = [qtbase qt5compat hidapi systemd];

            buildPhase = buildPhase "LenovoLegion-Daemon";

            installPhase = ''
              runHook preInstall
              install -Dm755 Installation/LenovoLegion-Daemon "$out/bin/LenovoLegion-Daemon"
              runHook postInstall
            '';

            meta = {
              description = "Lenovo Legion Toolkit root daemon (sysfs/WMI backend)";
              homepage = "https://github.com/bolekjar/lenovo-legion-linux-toolkit";
              license = lib.licenses.gpl3Only;
              platforms = ["x86_64-linux"];
            };
          }) {};

      desktopItem = pkgs.makeDesktopItem {
        name = "LenovoLegion";
        desktopName = "LenovoLegion";
        exec = "LenovoLegion";
        icon = "LenovoLegion";
        comment = "Lenovo Legion laptop control application";
        categories = ["Utility" "System"];
      };

      gui =
        pkgs.qt6Packages.callPackage
        ({
          stdenv,
          qmake,
          wrapQtAppsHook,
          pkg-config,
          qtbase,
          qtcharts,
          qt5compat,
          protobuf,
        }:
          stdenv.mkDerivation {
            pname = "lenovo-legion-toolkit-gui";
            inherit version src;

            sourceRoot = "${src.name}/LenovoLegion";

            postPatch = ''
                            ${qmake-paths-patch}

                            # Redirect log + QSettings from the read-only binary dir to
                            # $XDG_STATE_HOME/lenovo-legion (Qt StateLocation); the
                            # Application ctor mkpath runs before any Settings instance.
                            substituteInPlace LenovoLegion-Application/Application.cpp \
                              --replace '#include <QDir>' '#include <QDir>
              #include <QStandardPaths>' \
                              --replace 'LoggerHolder::getInstance().init(QApplication::applicationDirPath().append(QDir::separator()).append(bj::framework::Application::log_dir).append(QDir::separator()).append(bj::framework::Application::apps_names[0]).append(".log").toStdString());' 'QDir().mkpath(QStandardPaths::writableLocation(QStandardPaths::StateLocation) + "/lenovo-legion"); LoggerHolder::getInstance().init((QStandardPaths::writableLocation(QStandardPaths::StateLocation) + "/lenovo-legion/LenovoLegion.log").toStdString());'

                            substituteInPlace LenovoLegion-Application/Settings.cpp \
                              --replace '#include <QDir>' '#include <QDir>
              #include <QStandardPaths>' \
                              --replace 'std::filesystem::path(QCoreApplication::applicationDirPath().toStdString()).append(bj::framework::Application::data_dir)' 'std::filesystem::path((QStandardPaths::writableLocation(QStandardPaths::StateLocation) + "/lenovo-legion").toStdString())'
            '';

            nativeBuildInputs = [qmake wrapQtAppsHook pkg-config protobuf];
            buildInputs = [qtbase qtcharts qt5compat];

            buildPhase = buildPhase "LenovoLegion-Application";

            installPhase = ''
              runHook preInstall
              install -Dm755 Installation/LenovoLegion "$out/bin/LenovoLegion"
              install -Dm644 Installation/LenovoLegionIco.png "$out/share/pixmaps/LenovoLegion.png"
              install -Dm644 ${desktopItem}/share/applications/LenovoLegion.desktop \
                "$out/share/applications/LenovoLegion.desktop"
              runHook postInstall
            '';

            meta = {
              description = "Lenovo Legion Toolkit GUI";
              homepage = "https://github.com/bolekjar/lenovo-legion-linux-toolkit";
              license = lib.licenses.gpl3Only;
              platforms = ["x86_64-linux"];
            };
          }) {};

      cli = pkgs.rustPlatform.buildRustPackage {
        pname = "lenovo-legion-toolkit-cli";
        inherit version src;

        sourceRoot = "${src.name}/lenovo-legion-cli";
        cargoLock.lockFile = src + "/lenovo-legion-cli/Cargo.lock";

        meta = {
          description = "Lenovo Legion Toolkit CLI (sysfs controls for the lenovo_legion driver)";
          homepage = "https://github.com/bolekjar/lenovo-legion-linux-toolkit";
          license = lib.licenses.gpl3Only;
          platforms = ["x86_64-linux"];
        };
      };

      rapl-readonly = pkgs.writeShellScriptBin "rapl-readonly" ''
        if [ -e "$1" ]; then
          chmod 0444 "$1"
        fi
      '';

      # Upstream LenovoLegion-dkms/99-rapl-readonly.rules: RAPL limits must be
      # managed exclusively through the lenovo_legion driver.
      rapl-files = [
        "constraint_0_power_limit_uw"
        "constraint_0_time_window_us"
        "constraint_1_power_limit_uw"
        "constraint_1_time_window_us"
        "constraint_2_power_limit_uw"
        "energy_uj"
        "max_energy_range_uj"
        "name"
      ];
    in {
      environment.systemPackages = [
        gui
        cli
      ];

      boot.extraModulePackages = [kernel-module];

      # Companion modules from upstream LenovoLegion-dkms/lenovo-legion.conf,
      # filtered to what the CachyOS 7.2.3 kernel ships; the module's own
      # dependencies (wmi, etc.) load via modprobe.
      boot.kernelModules = [
        "lenovo_legion"
        "intel_rapl"
        "intel_vsec"
        "intel_lpss_pci"
        "intel_cstate"
        "intel_powerclamp"
        "intel_pmc_bxt"
        "intel_tcc_cooling"
        "pmt_telemetry"
        "platform_profile"
      ];

      # The toolkit driver implements its own WMI/gamezone/capdata stack, so
      # the in-kernel equivalents must stay unloaded (upstream
      # blacklist-lenovo-legion.conf).
      boot.extraModprobeConfig = ''
        blacklist ideapad_acpi
        blacklist ideapad_laptop
        blacklist lenovo_wmi_events
        blacklist lenovo_wmi_hotkey_utilities
        blacklist lenovo_wmi_other
        blacklist lenovo_wmi_capdata01
        blacklist lenovo_wmi_gamezone
        blacklist lenovo_wmi_helpers
        blacklist lenovo_wmi_capdata
      '';

      systemd.services.lenovo-legion-daemon = {
        description = "Lenovo Legion Toolkit daemon";
        wantedBy = ["graphical.target"];
        after = ["power-profiles-daemon.service"];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${daemon}/bin/LenovoLegion-Daemon";
          StateDirectory = "lenovo-legion-daemon";
          Environment = "LD_LIBRARY_PATH=${lib.makeLibraryPath (lib.optional (nvidia-x11 != null) nvidia-x11)}";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      services.udev.extraRules =
        lib.concatMapStringsSep "\n" (file: ''
          SUBSYSTEM=="powercap", KERNEL=="intel-rapl*", RUN+="${rapl-readonly}/bin/rapl-readonly $sys$devpath/${file}"
        '')
        rapl-files;
    };
  };
}
