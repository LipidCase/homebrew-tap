class Xray < Formula
  desc "Platform for building proxies to bypass network restrictions"
  homepage "https://xtls.github.io/"
  license all_of: ["MPL-2.0", "CC-BY-SA-4.0"]
  revision 1

  livecheck do
    skip "Prereleases are tracked by scripts/update_formula.py"
  end

  on_macos do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.9.30/Xray-macos-arm64-v8a.zip"
      sha256 "4b363bd924df5bf09f87bd445755ff8e5742b9a8a0480cda261061416c3c7dce" # macos-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.9.30/Xray-macos-64.zip"
      sha256 "1f366aaf21d3c3003d1556d066c4e08f9dd62d1f96555ecedde85b397df0f684" # macos-x86_64
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.9.30/Xray-linux-arm64-v8a.zip"
      sha256 "9886f077f9fd8e6713b84c377c1c7db4e53b9bfa8c276a5bd12561139522b473" # linux-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.9.30/Xray-linux-64.zip"
      sha256 "f851110beaff16e78d643f0ccfd9524b4a44dfd59bae3e34bb52bba378f7690e" # linux-x86_64
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
