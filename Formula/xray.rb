class Xray < Formula
  desc "Platform for building proxies to bypass network restrictions"
  homepage "https://xtls.github.io/"
  license all_of: ["MPL-2.0", "CC-BY-SA-4.0"]

  livecheck do
    skip "Prereleases are tracked by scripts/update_formula.py"
  end

  on_macos do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.31/Xray-macos-arm64-v8a.zip"
      sha256 "0a05dca3bd311b0bc5a89c7ce56350cab1e829e131e4b2bcd48eb304fac07e9a" # macos-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.31/Xray-macos-64.zip"
      sha256 "37c60b63c77ef5edcfb46a0d70349f7d96e0c132e6a356ead4fd20aeeacc5c75" # macos-x86_64
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.31/Xray-linux-arm64-v8a.zip"
      sha256 "1811c8f1da0c3b6dc707ebaf1c8390e987ba39859a8f0a7aadd8526157f2ec8d" # linux-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.31/Xray-linux-64.zip"
      sha256 "e4bd9119f50ae7c41658b1abd0679ae06f98bd864a2907ff33f2f2cf7081b214" # linux-x86_64
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
