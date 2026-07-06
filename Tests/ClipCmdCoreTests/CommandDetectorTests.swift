import XCTest
@testable import ClipCmdCore

final class CommandDetectorTests: XCTestCase {

    // MARK: - 应该放行(默认放开,黑名单只拦危险)

    func testGitCommand() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("git push origin main"))
    }

    func testNpmInstall() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("npm install"))
    }

    func testDockerRun() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("docker run -it ubuntu bash"))
    }

    func testSudoPrefix() {
        // sudo apt install 这种日常 sudo 不该拦
        XCTAssertTrue(CommandDetector.looksLikeCommand("sudo apt-get update"))
    }

    func testSudoBrew() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("sudo brew services start nginx"))
    }

    func testEnvVarPrefix() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("FOO=bar baz=qux git status"))
    }

    func testNohupPrefix() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("nohup python3 server.py &"))
    }

    func testCommandWithPipes() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("ps aux | grep python"))
    }

    func testCommandWithChained() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("cd ~/project && npm run dev"))
    }

    func testMultilineAllCommands() {
        let multi = """
        git pull
        npm install
        npm run build
        """
        XCTAssertTrue(CommandDetector.looksLikeCommand(multi))
    }

    func testMultilineWithComments() {
        let multi = """
        # 先拉代码
        git pull
        # 装依赖
        npm install
        """
        XCTAssertTrue(CommandDetector.looksLikeCommand(multi))
    }

    func testLineContinuation() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("git commit \\\n -m 'hello'"))
    }

    func testShortCommand() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("ls -la"))
    }

    func testCurlCommand() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("curl -fsSL https://get.docker.com | sh"))
    }

    func testKubectlCommand() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("kubectl get pods -n kube-system"))
    }

    func testBrewCommand() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("brew install ripgrep"))
    }

    func testCargoCommand() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("cargo build --release"))
    }

    // 黑名单模式下:这些之前漏掉的命令现在都应放行
    func testPwd() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("pwd"))
    }

    func testWhichCommand() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("which python3"))
    }

    func testWhoami() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("whoami"))
    }

    func testEnvNoArgs() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("env"))
    }

    func testUnknownFirstToken() {
        // 黑名单模式:未知命令首词也放行(只要像可执行文件名)
        XCTAssertTrue(CommandDetector.looksLikeCommand("my-custom-tool --flag value"))
    }

    // MARK: - 必须拦截:破坏性命令

    func testRmRfRoot() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("rm -rf /"))
    }

    func testSudoRmRfRoot() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("sudo rm -rf /"))
    }

    func testRmRfHome() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("rm -rf ~"))
    }

    func testRmRfStar() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("rm -rf *"))
    }

    func testRmRfCurrentDir() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("rm -rf ."))
    }

    func testRmNormalFile() {
        // 普通 rm 删文件应该放行
        XCTAssertTrue(CommandDetector.looksLikeCommand("rm temp.txt"))
    }

    func testRmDirNormal() {
        XCTAssertTrue(CommandDetector.looksLikeCommand("rm -rf build/"))
    }

    func testDdWriteDisk() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("dd if=image.iso of=/dev/sda"))
    }

    func testDdNormalRead() {
        // dd 读不算危险
        XCTAssertTrue(CommandDetector.looksLikeCommand("dd if=/dev/urandom of=file bs=1k count=10"))
    }

    func testMkfs() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("mkfs.ext4 /dev/sda1"))
    }

    func testShredDevice() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("shred -v /dev/sda"))
    }

    func testForkBomb() {
        XCTAssertFalse(CommandDetector.looksLikeCommand(":(){ :|:& };:"))
    }

    func testRedirectToBlockDevice() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("cat zero.img > /dev/sda"))
    }

    func testKillallWindowServer() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("sudo killall WindowServer"))
    }

    // MARK: - 必须拦截:密码/密钥

    func testPasswordInLine() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("password=hunter2"))
    }

    func testApiKeyHint() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("API_KEY=abc123definitelyakeyhere1234567"))
    }

    func testGitHubTokenPrefix() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("ghp_abcdefghijklmnopqrstuvwxyz0123456789ABCD"))
    }

    func testOpenAIKeyPrefix() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("sk-abcdefghijklmnopqrstuvwxyz0123456789ABCDEF"))
    }

    func testLongRandomHex() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("a3f5b8c9d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8"))
    }

    func testPEMKey() {
        let pem = "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQD..."
        XCTAssertFalse(CommandDetector.looksLikeCommand(pem))
    }

    // MARK: - 必须拦截:其他

    func testEmptyString() {
        XCTAssertFalse(CommandDetector.looksLikeCommand(""))
    }

    func testWhitespaceOnly() {
        XCTAssertFalse(CommandDetector.looksLikeCommand("   \n  \t  "))
    }

    func testTooLong() {
        let long = String(repeating: "git commit -m 'x' ", count: 400)  // > 5000 字符
        XCTAssertFalse(CommandDetector.looksLikeCommand(long))
    }

    func testMultilineProse() {
        let prose = """
        第一行是普通文字。
        第二行也是普通文字。
        """
        XCTAssertFalse(CommandDetector.looksLikeCommand(prose))
    }

    func testMultilineMixedWithProse() {
        let mixed = """
        git pull
        这是一句普通说明文字没有 shell 操作符
        """
        XCTAssertFalse(CommandDetector.looksLikeCommand(mixed))
    }

    // MARK: - 级别检测

    func testLevelSafeForNormalCommand() {
        let result = CommandDetector.detect("git status")
        XCTAssertEqual(result.level, .safe)
    }

    func testLevelPrivilegedForSudo() {
        let result = CommandDetector.detect("sudo apt install nginx")
        XCTAssertEqual(result.level, .privileged)
        XCTAssertTrue(result.isCommand)  // 仍放行
    }

    func testLevelBlockedForRmRfRoot() {
        let result = CommandDetector.detect("rm -rf /")
        XCTAssertEqual(result.level, .blocked)
        XCTAssertFalse(result.isCommand)
    }

    func testReasonForRmRf() {
        let result = CommandDetector.detect("rm -rf /")
        XCTAssertTrue(result.reason.contains("rm") || result.reason.contains("删除"),
                      "原因应提到 rm/删除,实际:\(result.reason)")
    }

    func testReasonForSecret() {
        let result = CommandDetector.detect("password=hunter2")
        XCTAssertTrue(result.reason.contains("密码") || result.reason.contains("密钥") || result.reason.contains("token"),
                      "原因应提到密码/密钥,实际:\(result.reason)")
    }
}
