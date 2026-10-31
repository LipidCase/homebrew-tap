class Xray < Formula
  desc "Platform for building proxies to bypass network restrictions"
  homepage "https://xtls.github.io/"
  license all_of: ["MPL-2.0", "CC-BY-SA-4.0"]

  livecheck do
    skip "Prereleases are tracked by scripts/update_formula.py"
  end

  on_macos do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.21/Xray-macos-arm64-v8a.zip"
      sha256 "926cc55fda2a8757dabe4f22dc98772f218ace025f101bd0b68aee232e59d5dc" # macos-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.21/Xray-macos-64.zip"
      sha256 "8e5169b429e76ce5f550c8294db465bc259f30c158ba900aa40802b76ad2f66e" # macos-x86_64
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.21/Xray-linux-arm64-v8a.zip"
      sha256 "d1304946c486d98e6b886e9b931eaaaebb23835b30e217638037b7f2721d4e9c" # linux-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.21/Xray-linux-64.zip"
      sha256 "0eec3ed4163c273d8c8bf821f7d219e257921cf584aa3fb970715e458e631978" # linux-x86_64
    end
  end

  depends_on arch: :arm64 if Hardware::CPU.arm?
  depends_on arch: :x86_64 if Hardware::CPU.intel?

  def install
    libexec.install "xray"
    (bin/"xray").write_env_script libexec/"xray",
      XRAY_LOCATION_ASSET: "${XRAY_LOCATION_ASSET:-#{pkgshare}}"

    pkgshare.install "geoip.dat", "geosite.dat"
    doc.install "LICENSE", "README.md"
    # A valid, inert default: configure an inbound before starting the service.
    (buildpath/"config.json").write <<~JSON
      {
        "log": { "loglevel": "warning" },
        "inbounds": [],
        "outbounds": [{ "protocol": "freedom", "tag": "direct" }]
      }
    JSON
    pkgetc.install "config.json"
  end

  def caveats
    <<~EOS
      This tap tracks upstream releases, including prereleases.
      Configure an inbound in #{etc}/xray/config.json before starting the service.
      Existing configuration is preserved on upgrade.
      Bundled geoip/geosite data is installed in #{pkgshare}.
      Override XRAY_LOCATION_ASSET to use your own data directory.
    EOS
  end

  service do
    run [opt_bin/"xray", "run", "--config", etc/"xray/config.json"]
    run_type :immediate
    keep_alive true
    working_dir var
    log_path var/"log/xray.log"
    error_log_path var/"log/xray.log"
  end
end
