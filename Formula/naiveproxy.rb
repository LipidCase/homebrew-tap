class Naiveproxy < Formula
  desc "Proxy client using Chromium's network stack to camouflage traffic"
  homepage "https://github.com/klzgrad/naiveproxy"
  version "154.0.8037.49-5"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+(?:-\d+)?)$/i)
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-5/naiveproxy-v154.0.8037.49-5-mac-arm64-arm64.tar.xz"
      sha256 "8b330140e0fed15fae71732cefee16f052325c30352ae3e5638a1e9f9d54d542" # macos-arm64
    end

    on_intel do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-5/naiveproxy-v154.0.8037.49-5-mac-x64-x64.tar.xz"
      sha256 "a3904193bd8d099eb034366c19a019f22573171aeece34e8d0206a92f0b8141d" # macos-x86_64
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-5/naiveproxy-v154.0.8037.49-5-linux-arm64.tar.xz"
      sha256 "8f4d917fa39a5d8cf1c17fc12ffd99ba84c015b62b43461d09cc074ca4114d8d" # linux-arm64
    end

    on_intel do
      url "https://github.com/klzgrad/naiveproxy/releases/download/v154.0.8037.49-5/naiveproxy-v154.0.8037.49-5-linux-x64.tar.xz"
      sha256 "80214dfea1767f6ecf63a3a79dc9f48b203460f51abc609357fff48dd5844c7d" # linux-x86_64
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
