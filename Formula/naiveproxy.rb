class Naiveproxy < Formula
  desc "Make a fortune quietly"
  homepage "https://github.com/klzgrad/naiveproxy"
  version "147.0.7727.49-1"

  if Hardware::CPU.arm?
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-arm64-arm64.tar.xz"
    sha256 "e85403f4fc99153bb892186b87a867ba9141dcae029d80e303303a50d3701cb0"
  else
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-x64-x64.tar.xz"
    sha256 "70c81a99cd2fab1f64d41a26d3d2b5eea8f88ec2859352c224e3280c5948dbba"
  end

  def install
    bin.install "naive"
  end

  test do
    system "#{bin}/naive", "--version"
  end
end