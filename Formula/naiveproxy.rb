class Naiveproxy < Formula
  desc "Make a fortune quietly"
  homepage "https://github.com/klzgrad/naiveproxy"
  version "154.0.8037.49-2"

  if Hardware::CPU.arm?
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-arm64-arm64.tar.xz"
    sha256 "c34a8cf14ee9998daf88b819136a189f3a0da34cf62c4fd8a5df3708dce4c3d8"
  else
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-x64-x64.tar.xz"
    sha256 "8f4e6b352dddd319ba61858333248ef194bf35ef1d43cb8499b6e5c43d9e74ad"
  end

  def install
    bin.install "naive"
  end

  test do
    system "#{bin}/naive", "--version"
  end
end