class Xray < Formula
  desc "Platform for building proxies to bypass network restrictions"
  homepage "https://xtls.github.io/"
  license all_of: ["MPL-2.0", "CC-BY-SA-4.0"]

  livecheck do
    skip "Prereleases are tracked by scripts/update_formula.py"
  end

  on_macos do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.17/Xray-macos-arm64-v8a.zip"
      sha256 "57531c66df375da671f66cad1443f63e90410b83d09baf226e2f26f2748aae0f" # macos-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.17/Xray-macos-64.zip"
      sha256 "d39e0cb5d0991810f73deaa81ba1147812c77b69bb5ddb0576a6b0096f66eb1a" # macos-x86_64
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.17/Xray-linux-arm64-v8a.zip"
      sha256 "4ebdad86048fa499e65334f88a120b1ed17e662f1c222afd3514afdf8820cdb1" # linux-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.17/Xray-linux-64.zip"
      sha256 "ecdd54eccd24c4c21a8f00968e7dbf7f5996da92383d2321170b560dc4a95158" # linux-x86_64
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

  test do
    assert_match version.to_s, shell_output("#{bin}/xray version")
    (testpath/"config.json").write <<~JSON
      {
        "outbounds": [{ "protocol": "freedom", "tag": "direct" }],
        "routing": {
          "rules": [
            { "type": "field", "ip": ["geoip:private"], "outboundTag": "direct" },
            { "type": "field", "domain": ["geosite:private"], "outboundTag": "direct" }
          ]
        }
      }
    JSON
    assert_match "Configuration OK",
      shell_output("#{bin}/xray run -test -config #{testpath}/config.json 2>&1")
    assert_path_exists pkgshare/"geoip.dat"
    assert_path_exists pkgshare/"geosite.dat"
  end
end
