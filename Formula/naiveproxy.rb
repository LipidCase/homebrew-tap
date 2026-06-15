class Naiveproxy < Formula
  desc "Make a fortune quietly"
  homepage "https://github.com/klzgrad/naiveproxy"
  version "149.0.7827.114-1"

  if Hardware::CPU.arm?
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-arm64-arm64.tar.xz"
    sha256 "1ed97eccc8fc4275bddde6ddb395e2a8221eaa05626998810531118297ee36ba"
  else
    url "https://github.com/klzgrad/naiveproxy/releases/download/v#{version}/naiveproxy-v#{version}-mac-x64-x64.tar.xz"
    sha256 "caced066717e73f8236d3652ed46b670dffe812a80bc490181851aad3e39534c"
  end

  def install
    bin.install "naive"
  end

  test do
    system "#{bin}/naive", "--version"
  end
end