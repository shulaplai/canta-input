import Cocoa
import InputMethodKit
import CantainputCore

let kConnectionName = "Cantainput_1_Connection"
let kBundleIdentifier = "local.cantainput.inputmethod"

final class AppDelegate: NSObject, NSApplicationDelegate {
    var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = IMKServer(name: kConnectionName, bundleIdentifier: kBundleIdentifier)
        NSLog("[Cantainput] IMKServer %@ (%@)", server == nil ? "FAILED" : "started", kConnectionName)
    }
}

func runSelfTest() -> Int32 {
    var failures = 0
    func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        print((ok ? "PASS " : "FAIL ") + name + (detail.isEmpty ? "" : "  [" + detail + "]"))
        if !ok { failures += 1 }
    }

    guard let tsv = Bundle.main.url(forResource: "jyutping", withExtension: "tsv") else {
        print("FAIL lexicon jyutping.tsv missing from bundle")
        return 1
    }
    try? Lexicon.shared.load(from: tsv)
    check("lexicon entries", Lexicon.shared.entryCount == 138_732, "\(Lexicon.shared.entryCount)")

    let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("cantainput-selftest.json")
    try? FileManager.default.removeItem(at: scratch)
    Learning.shared.redirectForTesting(to: scratch)

    func top(_ query: String) -> String {
        Engine.shared.rank(input: query, limit: 1).first?.text ?? ""
    }

    check("nei -> 你", top("nei") == "你", top("nei"))
    check("ngo -> 我", top("ngo") == "我", top("ngo"))
    check("ngodei -> 我哋", top("ngodei") == "我哋", top("ngodei"))
    check("mgoi -> 唔該", top("mgoi") == "唔該", top("mgoi"))

    let toned = Engine.shared.rank(input: "ngo4", limit: 5)
    check("tone filter keeps ngo4", !toned.isEmpty && toned.allSatisfy { $0.code.hasPrefix("ngo4") })
    check("unknown input is empty", Engine.shared.rank(input: "zzzzzz", limit: 5).isEmpty)

    for _ in 0..<30 { Learning.shared.record(code: "nei", text: "呢") }
    check("learning promotes 呢", top("nei") == "呢", top("nei"))
    Learning.shared.save()
    check("learning persisted", ((try? Data(contentsOf: scratch)) ?? Data()).isEmpty == false)

    print(failures == 0 ? "ALL PASS" : "\(failures) FAILED")
    return failures == 0 ? 0 : 1
}

if CommandLine.arguments.contains("--selftest") {
    exit(runSelfTest())
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
