class Naiveproxy < Formula
  desc "Proxy client using Chromium's network stack to camouflage traffic"
  homepage "https://github.com/klzgrad/naiveproxy"
  version "154.0.8037.49-3"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+(?:-\d+)?)$/i)
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-3/naiveproxy-v154.0.8037.49-3-mac-arm64-arm64.tar.xz"
      sha256 "d04337d11c6c7867a9a5f35bff14c35daa2a855a902b131ce07923d08444c684" # macos-arm64
    end

    on_intel do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-3/naiveproxy-v154.0.8037.49-3-mac-x64-x64.tar.xz"
      sha256 "a748dc4d26be4fcb96678a9d6b1df2edb78d70d697723b6c30b9c9be856c2080" # macos-x86_64
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-3/naiveproxy-v154.0.8037.49-3-linux-arm64.tar.xz"
      sha256 "5b398e543a845f7b3e8a0caeddfb6a899a050850ee99604edeb04bb7966b9130" # linux-arm64
    end

    on_intel do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-3/naiveproxy-v154.0.8037.49-3-linux-x64.tar.xz"
      sha256 "a6c47404f7a76d07d984af08ebe70b0a7456f52be4f40ba2245745f8cd93b02c" # linux-x86_64
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
