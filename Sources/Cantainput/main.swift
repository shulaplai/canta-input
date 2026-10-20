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

    func sentence(_ q: String) -> String {
        Engine.shared.candidates(for: q, limit: 18).first?.text ?? ""
    }
    check("syllables indexed", Lexicon.shared.syllables.count > 600,
          "\(Lexicon.shared.syllables.count)")
    let houmaa = Engine.shared.candidates(for: "neihoumaa", limit: 18)
    check("neihoumaa offers 你好嗎", houmaa.prefix(5).contains { $0.text == "你好嗎" },
          houmaa.prefix(4).map { $0.text }.joined(separator: "/"))
    check("ngo5dei6 -> 我哋", sentence("ngodei") == "我哋", sentence("ngodei"))
    check("mgoijyutjyu -> 唔該粵語", sentence("mgoijyutjyu") == "唔該粵語", sentence("mgoijyutjyu"))
    check("zousan -> 早晨", sentence("zousan") == "早晨", sentence("zousan"))
    check("gamjattinhei -> 今日天氣", sentence("gamjattinhei").hasPrefix("今日天氣"), sentence("gamjattinhei"))
    check("neig repairs to 你", sentence("neig") == "你", sentence("neig"))
    check("neix repairs to 你", sentence("neix") == "你", sentence("neix"))
    check("lm loaded", LanguageModel.shared.isLoaded,
          "\(LanguageModel.shared.bigramCount) bigrams")
    check("lm reranks 我想食飯", sentence("ngosoengsikfaan") == "我想食飯",
          sentence("ngosoengsikfaan"))
    check("lm keeps 今日天氣", sentence("gamjattinhei") == "今日天氣",
          sentence("gamjattinhei"))
    check("candidate list fills", Engine.shared.candidates(for: "nei", limit: 18).count == 18,
          "\(Engine.shared.candidates(for: "nei", limit: 18).count)")
    let decoded = Engine.shared.candidates(for: "neihoumaa", limit: 18)
    check("decoded codes have tones", decoded.first?.code.contains("5") == true,
          decoded.first?.code ?? "")

    let toned = Engine.shared.rank(input: "ngo4", limit: 5)
    check("tone filter keeps ngo4", !toned.isEmpty && toned.allSatisfy { $0.code.replacingOccurrences(of: " ", with: "").hasPrefix("ngo4") })
    check("unknown input is empty", Engine.shared.rank(input: "zzzzzz", limit: 5).isEmpty)

    for _ in 0..<30 { Learning.shared.record(code: "nei", text: "呢") }
    check("learning promotes 呢", top("nei") == "呢", top("nei"))
    Learning.shared.save()
    check("learning persisted", ((try? Data(contentsOf: scratch)) ?? Data()).isEmpty == false)

    print(failures == 0 ? "ALL PASS" : "\(failures) FAILED")
    return failures == 0 ? 0 : 1
}

if let renderIndex = CommandLine.arguments.firstIndex(of: "--render-panel") {
    _ = NSApplication.shared
    Engine.shared.ensureLoaded()
    let out = CommandLine.arguments[renderIndex + 1]
    let query = CommandLine.arguments.count > renderIndex + 2 ? CommandLine.arguments[renderIndex + 2] : "neihoumaa"
    let items = Engine.shared.candidates(for: query, limit: 18)
    let view = CandidateView()
    view.candidates = items
    view.selected = 0
    let size = view.measure()
    view.frame = NSRect(origin: .zero, size: size)
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
    view.cacheDisplay(in: view.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
    print("wrote \(out) \(Int(size.width))x\(Int(size.height)) items=\(items.count)")
    exit(0)
}

if let weightIndex = CommandLine.arguments.firstIndex(of: "--lm-weight"),
   weightIndex + 1 < CommandLine.arguments.count,
   let w = Double(CommandLine.arguments[weightIndex + 1]) {
    Engine.lmWeight = w
}

if let probeIndex = CommandLine.arguments.firstIndex(of: "--probe") {
    Engine.shared.ensureLoaded()
    let args = Array(CommandLine.arguments[(probeIndex + 1)...])
    if let first = args.first {
        var total = 0.0
        for _ in 0..<20 {
            let t0 = DispatchTime.now().uptimeNanoseconds
            _ = Engine.shared.candidates(for: first, limit: 18)
            total += Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
        }
        print(String(format: "  %.2f ms/query (worst case: %@)", total / 20.0, first))
        fflush(stdout)
    }
    for q in args {
        print("== \(q)"); fflush(stdout)
        for c in Engine.shared.candidates(for: q, limit: 9) {
            print("  \(c.text)   [\(c.code)]  \(Int(c.score))"); fflush(stdout)
        }
    }
    exit(0)
}

if CommandLine.arguments.contains("--selftest") {
    exit(runSelfTest())
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
