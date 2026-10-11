class Xray < Formula
  desc "Platform for building proxies to bypass network restrictions"
  homepage "https://xtls.github.io/"
  license all_of: ["MPL-2.0", "CC-BY-SA-4.0"]

  livecheck do
    skip "Prereleases are tracked by scripts/update_formula.py"
  end

  on_macos do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.10/Xray-macos-arm64-v8a.zip"
      sha256 "7b1711eaeefd90f27082cf49c311aa57dad44ac13146faab3f0c1601158ea6c8" # macos-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.10/Xray-macos-64.zip"
      sha256 "f99119d4aa662ae2e9a2adf57eccf3dad1b43035ae2e06ccc3949c8256e33fd0" # macos-x86_64
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.10/Xray-linux-arm64-v8a.zip"
      sha256 "58e339e67827220175b3a1c6f66f48ccd086b79209f30ba1c0bcb47885d4c22a" # linux-arm64
    end

    on_intel do
      url "https://github.com/XTLS/Xray-core/releases/download/v26.10.10/Xray-linux-64.zip"
      sha256 "72a5fde819713a103c6fc26a87aa025c1518c918a34eba4bc38d64dc0728e5d9" # linux-x86_64
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
