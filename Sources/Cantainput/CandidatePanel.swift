import Cocoa
import CantainputCore

/// Two-row candidate strip: big character(s) on top, the jyutping underneath.
final class CandidateView: NSView {
    var candidates: [Candidate] = []
    var selected = 0
    var onPick: ((Int) -> Void)?

    static let perRow = 9
    static let cellHeight: CGFloat = 46
    static let outerPad: CGFloat = 6
    static let innerPad: CGFloat = 8
    static let minCellWidth: CGFloat = 38

    private let textFont = NSFont.systemFont(ofSize: 17)
    private let codeFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)

    private var cells: [NSRect] = []
    private var measured = NSSize(width: 10, height: 10)

    private func widthOf(_ s: String, _ font: NSFont) -> CGFloat {
        (s as NSString).size(withAttributes: [.font: font]).width
    }

    private func label(for index: Int) -> String {
        let n = index % CandidateView.perRow + 1
        return index < CandidateView.perRow ? "\(n)" : "\u{21E7}\(n)"
    }

    /// Recompute the natural size and cell frames.
    @discardableResult
    func measure() -> NSSize {
        let perRow = CandidateView.perRow
        var widths: [CGFloat] = []
        for c in candidates {
            let num = label(for: widths.count)
            let numW = widthOf(num, numberFont)
            let w = max(widthOf(c.text, textFont),
                        numW + 5 + widthOf(c.code, codeFont))
            widths.append(max(w + CandidateView.innerPad * 2, CandidateView.minCellWidth))
        }
        let rows = max(1, (candidates.count + perRow - 1) / perRow)
        let height = CandidateView.outerPad * 2 + CGFloat(rows) * CandidateView.cellHeight

        var rowWidths: [CGFloat] = []
        for r in 0..<rows {
            var sum: CGFloat = 0
            for i in (r * perRow)..<min((r + 1) * perRow, widths.count) { sum += widths[i] }
            rowWidths.append(sum)
        }
        let width = (rowWidths.max() ?? CandidateView.minCellWidth) + CandidateView.outerPad * 2

        cells = []
        for i in 0..<candidates.count {
            let r = i / perRow
            var x = CandidateView.outerPad
            for j in (r * perRow)..<i { x += widths[j] }
            let y = height - CandidateView.outerPad - CGFloat(r + 1) * CandidateView.cellHeight
            cells.append(NSRect(x: x, y: y, width: widths[i], height: CandidateView.cellHeight))
        }
        measured = NSSize(width: width, height: height)
        return measured
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.saveGraphicsState()

        let bg = NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9)
        NSColor.windowBackgroundColor.withAlphaComponent(0.98).setFill()
        bg.fill()

        for (i, cell) in cells.enumerated() {
            guard i < candidates.count else { break }
            let c = candidates[i]
            let isSel = i == selected

            if isSel {
                let sel = NSBezierPath(roundedRect: cell.insetBy(dx: 2, dy: 3), xRadius: 7, yRadius: 7)
                NSColor.controlAccentColor.setFill()
                sel.fill()
            }

            let textColor: NSColor = isSel ? .white : .labelColor
            let codeColor: NSColor = isSel ? NSColor.white.withAlphaComponent(0.85)
                                           : .secondaryLabelColor

            let textSize = (c.text as NSString).size(withAttributes: [.font: textFont])
            let textY = cell.maxY - 7 - textSize.height
            let textX = cell.minX + (cell.width - textSize.width) / 2
            (c.text as NSString).draw(at: NSPoint(x: textX, y: textY),
                                      withAttributes: [.font: textFont, .foregroundColor: textColor])

            let num = label(for: i)
            let numAttr: [NSAttributedString.Key: Any] = [.font: numberFont,
                                                          .foregroundColor: codeColor]
            let codeAttr: [NSAttributedString.Key: Any] = [.font: codeFont,
                                                           .foregroundColor: codeColor]
            let numW = (num as NSString).size(withAttributes: numAttr).width
            (num as NSString).draw(at: NSPoint(x: cell.minX + CandidateView.innerPad,
                                               y: cell.minY + 7),
                                   withAttributes: numAttr)
            (c.code as NSString).draw(at: NSPoint(x: cell.minX + CandidateView.innerPad + numW + 5,
                                                  y: cell.minY + 7),
                                      withAttributes: codeAttr)
        }

        ctx.restoreGraphicsState()
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let i = cells.firstIndex(where: { $0.contains(p) }), i < candidates.count {
            onPick?(i)
        }
    }
}

/// Floating, non-activating candidate window.
final class CandidatePanel: NSPanel {
    static let shared = CandidatePanel()
    private let candidateView = CandidateView()
    private var onPick: ((Int) -> Void)?

    private init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 120, height: 58),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isMovable = false
        contentView = candidateView
        candidateView.onPick = { [weak self] index in self?.onPick?(index) }
    }

    func present(candidates: [Candidate], selected: Int, at caret: NSRect,
                 onPick: @escaping (Int) -> Void) {
        self.onPick = onPick
        candidateView.candidates = candidates
        candidateView.selected = selected
        let size = candidateView.measure()
        setFrame(NSRect(origin: origin(for: size, caret: caret), size: size), display: true)
        candidateView.frame = NSRect(origin: .zero, size: size)
        candidateView.needsDisplay = true
        orderFrontRegardless()
    }

    func dismiss() {
        onPick = nil
        orderOut(nil)
    }

    private func origin(for size: NSSize, caret: NSRect) -> NSPoint {
        let probe = NSPoint(x: caret.minX, y: caret.minY)
        let screen = NSScreen.screens.first { $0.frame.contains(probe) } ?? NSScreen.main
        var x = caret.minX
        var y = caret.minY - size.height - 4
        if let visible = screen?.visibleFrame {
            if y < visible.minY { y = caret.maxY + 4 }
            if y + size.height > visible.maxY { y = caret.minY - size.height - 4 }
            x = min(max(x, visible.minX + 4), visible.maxX - size.width - 4)
            y = min(max(y, visible.minY + 4), visible.maxY - size.height - 4)
        }
        return NSPoint(x: x, y: y)
    }
}
