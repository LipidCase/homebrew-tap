class Naiveproxy < Formula
  desc "Proxy client using Chromium's network stack to camouflage traffic"
  homepage "https://github.com/klzgrad/naiveproxy"
  version "154.0.8037.49-2"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+(?:-\d+)?)$/i)
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-2/naiveproxy-v154.0.8037.49-2-mac-arm64-arm64.tar.xz"
      sha256 "c34a8cf14ee9998daf88b819136a189f3a0da34cf62c4fd8a5df3708dce4c3d8" # macos-arm64
    end

    on_intel do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-2/naiveproxy-v154.0.8037.49-2-mac-x64-x64.tar.xz"
      sha256 "8f4e6b352dddd319ba61858333248ef194bf35ef1d43cb8499b6e5c43d9e74ad" # macos-x86_64
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-2/naiveproxy-v154.0.8037.49-2-linux-arm64.tar.xz"
      sha256 "e2eab668815b0ee7f44db44009cdb86b863235ef92564d31e39840405e3e18bb" # linux-arm64
    end

    on_intel do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-2/naiveproxy-v154.0.8037.49-2-linux-x64.tar.xz"
      sha256 "4823f654b1a3856efefa6980a97997b6c5153a693e4a4541a9a10e03d7e7d9e3" # linux-x86_64
    end
  end

  depends_on arch: :arm64 if Hardware::CPU.arm?
  depends_on arch: :x86_64 if Hardware::CPU.intel?

  def install
    bin.install "naive"
    doc.install "LICENSE", "USAGE.txt"
  end

  test do
    assert_match version.to_s.split("-").first, shell_output("#{bin}/naive --version 2>&1")
  end
end
