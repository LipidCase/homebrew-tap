class Naiveproxy < Formula
  desc "Make a fortune quietly"
  homepage "https://github.com/klzgrad/naiveproxy"
  version "150.0.7871.63-1"

  if Hardware::CPU.arm?
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-arm64-arm64.tar.xz"
    sha256 "315f946fa91a65a30b25b69bba88836a117838f58b616c6a58c970c9ff1d9bbf"
  else
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-x64-x64.tar.xz"
    sha256 "92e7fe5f3cfca5e0cca49798e5c435a5bd7ef05b543c0aa614a5623ad39a50d4"
  end

  def install
    bin.install "naive"
  end

  test do
    system "#{bin}/naive", "--version"
  end
end