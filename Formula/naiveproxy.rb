class Naiveproxy < Formula
  desc "Make a fortune quietly"
  homepage "https://github.com/klzgrad/naiveproxy"
  version "148.0.7778.96-5"

  if Hardware::CPU.arm?
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-arm64-arm64.tar.xz"
    sha256 "9a9e7722a038c0cd9775cabdfccfecbb39139839250bd0f77bb855b086f4e691"
  else
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-x64-x64.tar.xz"
    sha256 "b8e6f6348a7384f30409d67e2c35a6d14de64fc6fcf908385dcf5283bf8815cb"
  end

  def install
    bin.install "naive"
  end

  test do
    system "#{bin}/naive", "--version"
  end
end