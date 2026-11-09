import Foundation
import Darwin

// Standalone engine smoke test.
//
// Usage:
//   engine-smoke [<opencc-dir>]
//
// When no directory is given, OpenCCResources.directory() is used. Each case
// opens its own OpenCC instance, converts a fixed vector, prints PASS/FAIL and
// exits 1 if any vector mismatches.

struct SmokeCase {
    let name: String
    let config: String
    let input: String
    let expected: String
}

let directory: String
if CommandLine.arguments.count > 1 {
    directory = CommandLine.arguments[1]
} else {
    directory = OpenCCResources.directory()
}

let vectors = [
    SmokeCase(
        name: "s2twp",
        config: "s2twp.json",
        input: "汉字转换测试，软件和硬件。",
        expected: "漢字轉換測試，軟體和硬體。"
    ),
    SmokeCase(
        name: "s2tw",
        config: "s2tw.json",
        input: "汉字转换测试，软件和硬件。",
        expected: "漢字轉換測試，軟件和硬件。"
    ),
    SmokeCase(
        name: "s2hkp",
        config: "s2hkp.json",
        input: "软件和硬盘，鼠标，打印机。",
        expected: "軟件和硬碟，滑鼠，打印機。"
    ),
    SmokeCase(
        name: "tw2sp",
        config: "tw2sp.json",
        input: "漢字轉換測試，軟體和硬體。",
        expected: "汉字转换测试，软件和硬件。"
    ),
]

var failures = 0

for vector in vectors {
    let path = (directory as NSString).appendingPathComponent(vector.config)
    do {
        let engine = try OpenCC(configPath: path)
        defer { engine.close() }

        let result = try engine.convert(vector.input)
        if result == vector.expected {
            print("PASS \(vector.name)")
        } else {
            print("FAIL \(vector.name): got \(result)")
            failures += 1
        }
    } catch {
        print("FAIL \(vector.name): got \(error.localizedDescription)")
        failures += 1
    }
}

if failures > 0 {
    exit(1)
}
