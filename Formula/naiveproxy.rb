class Naiveproxy < Formula
  desc "Proxy client using Chromium's network stack to camouflage traffic"
  homepage "https://github.com/klzgrad/naiveproxy"
  version "154.0.8037.49-4"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+(?:-\d+)?)$/i)
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-4/naiveproxy-v154.0.8037.49-4-mac-arm64-arm64.tar.xz"
      sha256 "aa91a9f1d743a85db65acdf2bd910c1bba9ca8831687fd947351880e2997b794" # macos-arm64
    end

    on_intel do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-4/naiveproxy-v154.0.8037.49-4-mac-x64-x64.tar.xz"
      sha256 "ae0fb930d982e6ec5d6a6012ec2b87bfc69d8953ad8b0a3517cb609eea9a6af4" # macos-x86_64
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-4/naiveproxy-v154.0.8037.49-4-linux-arm64.tar.xz"
      sha256 "dfa99dc36dafa1ee7f97f48bde14e9ee96bc4011e5cc10c7881fa7883859a036" # linux-arm64
    end

    on_intel do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-4/naiveproxy-v154.0.8037.49-4-linux-x64.tar.xz"
      sha256 "9d765620b90f7c60eb40c7c68b2f82537757cc52a8693dee7a00f8ba8b13dfd0" # linux-x86_64
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
