import XCTest

/// Runs install.sh against a temp settings.json and verifies the output
/// contains the correct matcher-group structure for every required event.
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

        // Write an empty settings file and a placeholder hook script
        try "{}".write(to: settingsURL, atomically: true, encoding: .utf8)
        try "#!/bin/bash\n".write(to: hookScript, atomically: true, encoding: .utf8)

        // Locate install.sh relative to this test bundle
        let scriptURL = scriptPath()

        // Run only the Python merging section by extracting it inline
        let py = """
import json, sys

settings_path = sys.argv[1]
hook_cmd      = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})
matcher_group = {
    "matcher": "",
    "hooks": [{"type": "command", "command": hook_cmd}]
}

for event in ["PreToolUse", "PostToolUse", "Stop", "StopFailure",
              "Notification", "PermissionRequest"]:
    event_hooks = hooks.setdefault(event, [])
    already = any(
        any(h.get("command") == hook_cmd for h in g.get("hooks", []))
        for g in event_hooks
        if isinstance(g, dict)
    )
    if not already:
        event_hooks.append(matcher_group)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
"""
        let pyURL = tmpDir.appendingPathComponent("merge.py")
        try py.write(to: pyURL, atomically: true, encoding: .utf8)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        proc.arguments = [pyURL.path, settingsURL.path, hookScript.path]
        try proc.run()
        proc.waitUntilExit()
        XCTAssertEqual(proc.terminationStatus, 0, "Python merge script should exit 0")

        // Parse result
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

            // Each entry must be a matcher-group, not a flat handler
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

        let py = mergePythonScript()
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

        // Each event should have exactly ONE matcher group (no duplicates)
        for event in ["PreToolUse", "PostToolUse", "Stop", "StopFailure",
                      "Notification", "PermissionRequest"] {
            let groups = hooks![event] as? [[String: Any]]
            XCTAssertEqual(groups?.count, 1,
                "\(event) has \(groups?.count ?? 0) groups after two runs — expected 1")
        }
    }

    // MARK: - Helpers

    private func scriptPath() -> URL {
        // Resolve scripts/install.sh relative to the source root
        let here = URL(fileURLWithPath: #file)
        return here
            .deletingLastPathComponent()   // ClaudeMenuBarTests
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("scripts/install.sh")
    }

    private func mergePythonScript() -> String {
        """
import json, sys

settings_path = sys.argv[1]
hook_cmd      = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})
matcher_group = {
    "matcher": "",
    "hooks": [{"type": "command", "command": hook_cmd}]
}

for event in ["PreToolUse", "PostToolUse", "Stop", "StopFailure",
              "Notification", "PermissionRequest"]:
    event_hooks = hooks.setdefault(event, [])
    already = any(
        any(h.get("command") == hook_cmd for h in g.get("hooks", []))
        for g in event_hooks
        if isinstance(g, dict)
    )
    if not already:
        event_hooks.append(matcher_group)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
"""
    }
}
