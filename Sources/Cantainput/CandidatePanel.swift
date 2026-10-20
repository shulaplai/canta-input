import Cocoa
import CantainputCore

final class CandidateView: NSView {
    var items: [Candidate] = []
    var selected: Int = 0
    var onPick: ((Int) -> Void)?
    private var itemFrames: [NSRect] = []
    private let outerPad: CGFloat = 6
    private let innerPad: CGFloat = 9
    private let lineHeight: CGFloat = 34
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
    private let textFont = NSFont.systemFont(ofSize: 17, weight: .regular)

    func layoutSize() -> NSSize {
        itemFrames.removeAll()
        var x = outerPad
        for item in items {
            let tw = (item.text as NSString).size(withAttributes: [.font: textFont]).width
            let w = innerPad * 2 + 13 + 4 + tw
            itemFrames.append(NSRect(x: x, y: 0, width: w, height: lineHeight))
            x += w
        }
        return NSSize(width: max(60, x + outerPad), height: lineHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        NSColor.windowBackgroundColor.withAlphaComponent(0.98).setFill()
        bg.fill()
        NSColor.separatorColor.setStroke()
        bg.lineWidth = 1
        bg.stroke()

        for (i, f) in itemFrames.enumerated() where i < items.count {
            if i == selected {
                let sel = NSBezierPath(roundedRect: f.insetBy(dx: 1.5, dy: 3), xRadius: 6, yRadius: 6)
                NSColor.controlAccentColor.setFill()
                sel.fill()
            }
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: numberFont,
                .foregroundColor: i == selected ? NSColor.white.withAlphaComponent(0.85) : NSColor.secondaryLabelColor,
            ]
            let numStr = "\(i + 1)" as NSString
            let numSize = numStr.size(withAttributes: numAttrs)
            numStr.draw(at: NSPoint(x: f.minX + innerPad, y: f.midY - numSize.height / 2 + 1), withAttributes: numAttrs)

            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: i == selected ? NSColor.white : NSColor.labelColor,
            ]
            let ts = (items[i].text as NSString).size(withAttributes: textAttrs)
            (items[i].text as NSString).draw(at: NSPoint(x: f.minX + innerPad + 17, y: f.midY - ts.height / 2 + 1), withAttributes: textAttrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let i = itemFrames.firstIndex(where: { $0.contains(p) }) {
            onPick?(i)
        }
    }
}

final class CandidatePanel: NSPanel {
    static let shared = CandidatePanel()
    private let candidateView = CandidateView()

    private init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 120, height: 34),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        becomesKeyOnlyIfNeeded = true
        contentView = candidateView
    }

    func present(candidates: [Candidate], selected: Int, at caret: NSRect, onPick: @escaping (Int) -> Void) {
        candidateView.items = candidates
        candidateView.selected = selected
        candidateView.onPick = onPick
        let size = candidateView.layoutSize()
        candidateView.frame = NSRect(origin: .zero, size: size)
        setFrame(NSRect(origin: Self.origin(for: size, caret: caret), size: size), display: true)
        candidateView.needsDisplay = true
        orderFrontRegardless()
    }

    private static func origin(for size: NSSize, caret: NSRect) -> NSPoint {
        let point = NSPoint(x: caret.minX, y: caret.minY)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let vis = screen?.visibleFrame else {
            return NSPoint(x: caret.minX, y: caret.minY - size.height - 6)
        }
        var x = caret.minX
        var y = caret.minY - size.height - 6
        if y < vis.minY { y = caret.maxY + 6 }
        x = min(max(x, vis.minX + 4), vis.maxX - size.width - 4)
        if y + size.height > vis.maxY { y = vis.maxY - size.height - 4 }
        return NSPoint(x: x, y: y)
    }

    func dismiss() {
        orderOut(nil)
    }
}
