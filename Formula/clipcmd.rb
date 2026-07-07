# Homebrew Formula for clipcmd
#
# 用户安装:
#   brew install GGGWB/clipcmd/clipcmd
# 或先 tap:
#   brew tap GGGWB/clipcmd
#   brew install clipcmd
#
# 注意:首次发布前 sha256 是占位符。第一个 release 跑完后,
#       从 release 页面的 sha256.txt 里取真实值替换下面的 PLACEHOLDER。
class Clipcmd < Formula
  desc "把剪贴板里的命令,一键送到终端执行"
  homepage "https://github.com/GGGWB/clipcmd"
  url "https://github.com/GGGWB/clipcmd/releases/download/v0.1.0/clipcmd-darwin-arm64"
  sha256 "fd36df5228a9b9a5437b929bc405159741797d218a4c7ed0c3354f6a6f86f25c"
  version "0.1.0"
  license "MIT"

  # 明确只支持 Apple Silicon。Intel Mac 上 brew 会给出清晰错误,而不是下载失败。
  depends_on arch: :arm64

  # 这是预编译二进制,无需 build。下载后直接放进 bin。
  def install
    bin.install "clipcmd-darwin-arm64" => "clipcmd"
  end

  test do
    assert_match "0.1.0", shell_output("#{bin}/clipcmd --version")
  end
end
