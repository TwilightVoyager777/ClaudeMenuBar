import XCTest

/// Runs the Python merge logic extracted from the real install.sh
/// against a temp settings.json and verifies the output.
final class InstallScriptTests: XCTestCase {

    private var tmpDir: URL!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    func test_install_sh_registers_all_required_events() throws {
        let settingsURL = tmpDir.appendingPathComponent("settings.json")
        let hookScript  = tmpDir.appendingPathComponent("claudemenubar-hook.sh")

        try "{}".write(to: settingsURL, atomically: true, encoding: .utf8)
        try "#!/bin/bash\n".write(to: hookScript, atomically: true, encoding: .utf8)

        let py = try extractPythonFromInstallScript()
        let pyURL = tmpDir.appendingPathComponent("merge.py")
        try py.write(to: pyURL, atomically: true, encoding: .utf8)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        proc.arguments = [pyURL.path, settingsURL.path, hookScript.path]
        try proc.run()
        proc.waitUntilExit()
        XCTAssertEqual(proc.terminationStatus, 0, "Python merge script should exit 0")

        let data = try Data(contentsOf: settingsURL)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as? [String: Any]
        XCTAssertNotNil(hooks, "settings.json must have a 'hooks' key")

        let required = ["PreToolUse", "PostToolUse", "Stop", "StopFailure",
                        "Notification", "PermissionRequest"]

        for event in required {
            let groups = hooks![event] as? [[String: Any]]
            XCTAssertNotNil(groups, "Missing event: \(event)")
            XCTAssertFalse(groups!.isEmpty, "\(event) group list is empty")

            let first = groups!.first!
            XCTAssertNotNil(first["matcher"],
                "'\(event)' entry missing 'matcher' key — wrong structure")
            let innerHooks = first["hooks"] as? [[String: Any]]
            XCTAssertNotNil(innerHooks,
                "'\(event)' entry missing nested 'hooks' array")
            XCTAssertEqual(innerHooks?.first?["type"] as? String, "command",
                "'\(event)' inner hook should have type 'command'")
            XCTAssertEqual(innerHooks?.first?["command"] as? String, hookScript.path,
                "'\(event)' inner hook should point to the hook script")
        }
    }

    func test_install_sh_is_idempotent() throws {
        let settingsURL = tmpDir.appendingPathComponent("settings.json")
        let hookScript  = tmpDir.appendingPathComponent("claudemenubar-hook.sh")
        try "{}".write(to: settingsURL, atomically: true, encoding: .utf8)
        try "#!/bin/bash\n".write(to: hookScript, atomically: true, encoding: .utf8)

        let py = try extractPythonFromInstallScript()
        let pyURL = tmpDir.appendingPathComponent("merge.py")
        try py.write(to: pyURL, atomically: true, encoding: .utf8)

        // Run twice
        for _ in 0..<2 {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            proc.arguments = [pyURL.path, settingsURL.path, hookScript.path]
            try proc.run()
            proc.waitUntilExit()
        }

        let data = try Data(contentsOf: settingsURL)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as? [String: Any]

        for event in ["PreToolUse", "PostToolUse", "Stop", "StopFailure",
                      "Notification", "PermissionRequest"] {
            let groups = hooks![event] as? [[String: Any]]
            XCTAssertEqual(groups?.count, 1,
                "\(event) has \(groups?.count ?? 0) groups after two runs — expected 1")
        }
    }

    // MARK: - Helpers

    /// Extracts the Python code from the real install.sh between PYEOF markers.
    private func extractPythonFromInstallScript() throws -> String {
        let scriptURL = scriptPath()
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        guard let startRange = script.range(of: "<<'PYEOF'\n"),
              let endRange = script.range(of: "\nPYEOF", range: startRange.upperBound..<script.endIndex)
        else {
            XCTFail("Could not extract Python from install.sh — PYEOF markers not found")
            return ""
        }

        return String(script[startRange.upperBound..<endRange.lowerBound])
    }

    private func scriptPath() -> URL {
        let here = URL(fileURLWithPath: #file)
        return here
            .deletingLastPathComponent()   // ClaudeMenuBarTests
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("scripts/install.sh")
    }
}
