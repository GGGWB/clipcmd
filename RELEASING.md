# 维护者手册:发布与更新

这份文档讲怎么把 clipcmd 推到 GitHub、发第一个 release、更新 Homebrew Formula。
**所有需要联网的步骤都在这里,网络好时照着做即可。**

---

## 一次性:首次发布

### 1. 本地 git 初始化(已由安装脚本完成,跳过)

如果还没初始化:

```bash
cd /path/to/clipcmd
git init
git add .
git commit -m "Initial commit: clipcmd v0.1.0"
```

### 2. 在 GitHub 建仓库

需要能连 `github.com`。两种方式:

**方式 A:命令行(gh CLI)**
```bash
gh repo create clipcmd --public --source=. --remote=origin --push
```

**方式 B:网页**
1. 去 https://github.com/new
2. 仓库名填 `clipcmd`,选 Public
3. **不要**勾选"Initialize with README"(本地已有)
4. 建好后,本地加 remote:
   ```bash
   git remote add origin https://github.com/GGGWB/clipcmd.git
   git push -u origin main   # 或 master,看本地默认分支
   ```

### 3. 推首个 tag,触发自动发版

```bash
git tag v0.1.0
git push origin v0.1.0
```

推送后,GitHub Actions 的 `release.yml` 会自动:
- 在 `macos-15` runner 上 `swift build -c release`
- 把二进制重命名为 `clipcmd-darwin-arm64`
- 算 sha256,生成 `sha256.txt`
- 创建 GitHub Release v0.1.0,上传二进制和 sha256

去 https://github.com/GGGWB/clipcmd/actions 看 CI 跑完没(大约 2-3 分钟)。

### 4. 回填 sha256 到 Formula(让 brew install 可用)

CI 跑完后:

```bash
# 方法 1:从 release 下载 sha256.txt 看
gh release download v0.1.0 -R GGGWB/clipcmd -p sha256.txt -O - --clobber
# 输出形如:9f86d081884c... clipcmd-darwin-arm64
# 前面那串就是 sha256

# 方法 2:手动从 release 页面复制
# https://github.com/GGGWB/clipcmd/releases/tag/v0.1.0
```

拿到 sha256 后,编辑 `Formula/clipcmd.rb`,把这一行的 `PLACEHOLDER` 换成真实值:

```ruby
sha256 "PLACEHOLDER_REPLACE_AFTER_FIRST_RELEASE"   # ← 换成真实 sha256
```

然后提交并推送:

```bash
git add Formula/clipcmd.rb
git commit -m "Update Formula sha256 for v0.1.0"
git push
```

### 5. 验证 brew install 能用

```bash
brew install GGGWB/clipcmd/clipcmd
clipcmd --version   # 应输出 0.1.0
```

如果 brew 报 sha256 不匹配,说明回填的值不对,重新核对。

---

## 后续:发新版本

每次发版只需 3 步:

```bash
# 1. 改代码,把版本号 src/clipcmd/ClipCmdMain.swift 里的 version 改成新值
#    (比如从 "0.1.0" 改成 "0.2.0")

# 2. 提交
git add .
git commit -m "Release v0.2.0"

# 3. 打 tag 并推送(触发自动发版)
git tag v0.2.0
git push origin v0.2.0
```

然后重复"首次发布"的第 4 步:CI 跑完 → 拿新 sha256 → 更新 `Formula/clipcmd.rb` 的 `url`(版本号)和 `sha256` → push。

> 想自动化这一步?后续可以加 `mislav/bump-homebrew-formula-action`,但需要一个有 tap 仓库写权限的 PAT。个人项目手动回填够用。

---

## CI 状态自查

- **CI 测试**:每次 push/PR 自动跑 `swift test`(52 例)。徽章在 README 顶部。
- **Release**:推 `v*` tag 自动构建 + 发版。

去 https://github.com/GGGWB/clipcmd/actions 看所有 workflow 运行历史。

如果 CI 挂了,点进失败的 run 看 log,通常是:
- 测试失败 → 本地 `swift test` 复现,改代码
- 编译失败 → 本地 `swift build` 复现
- macOS runner 变更 → 看是不是 `macos-15` 被废弃了,换成更新的标签

---

## 常见问题

**Q: brew install 提示 "No formulae found"?**
A: Formula 在主仓库的 `Formula/clipcmd.rb`,确保路径正确(是 `Formula/` 不是 `formula/`,大小写敏感)。`brew tap GGGWB/clipcmd` 后 `brew install clipcmd` 也行。

**Q: 用户下载二进制后提示 "无法验证开发者"?**
A: 这是 quarantine 属性,让用户跑 `xattr -d com.apple.quarantine $(which clipcmd)`。CLI 工具不用签名。README 已写。

**Q: 想支持 Intel Mac?**
A: 在 `release.yml` 加 `--arch x86_64` 编译,在 Formula 用 `on_arm` / `on_intel` 块分架构给不同 url。见 `RELEASING.md` 的后续扩展。
