import Cocoa
import InputMethodKit
import CantainputCore

final class CantoneseInputController: IMKInputController {
    private var composing = ""
    private var candidates: [Candidate] = []
    private var selected = 0
    private var openQuote = false
    private static let maxShown = 18

    /// Fullwidth punctuation, matched on the committed character so Shift-ed
    /// ASCII (e.g. "<") still passes through.
    private static let punctuation: [Character: String] = [
        ",": "\u{FF0C}", ".": "\u{3002}", "?": "\u{FF1F}", "!": "\u{FF01}",
        ":": "\u{FF1A}", ";": "\u{FF1B}",
        "(": "\u{FF08}", ")": "\u{FF09}",
        "[": "\u{300C}", "]": "\u{300D}",
    ]

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        Engine.shared.ensureLoaded()
        NSLog("[Cantainput] activated, %@", Engine.shared.loadStatus)
    }

    override func deactivateServer(_ sender: Any!) {
        CandidatePanel.shared.dismiss()
        composing = ""
        candidates = []
        selected = 0
        Learning.shared.save()
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = client(), !composing.isEmpty else { return }
        commitSelected(client)
    }

    private var rowSize: Int { 9 }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown,
              let client = sender as? IMKTextInput else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            return false
        }

        let chars = event.charactersIgnoringModifiers ?? ""

        switch event.keyCode {
        case 51: // delete
            guard !composing.isEmpty else { return false }
            composing.removeLast()
            updateComposition(client)
            return true
        case 53: // escape
            guard !composing.isEmpty else { return false }
            clearComposition(client)
            return true
        case 36, 76, 49: // return, keypad enter, space
            guard !composing.isEmpty else { return false }
            commitSelected(client)
            return true
        case 123: // left
            guard !composing.isEmpty else { return false }
            selected = max(0, selected - 1)
            setPreview(client)
            showPanel(client)
            return true
        case 124: // right
            guard !composing.isEmpty else { return false }
            selected = min(selected + 1, max(0, candidates.count - 1))
            setPreview(client)
            showPanel(client)
            return true
        case 126: // up
            guard !composing.isEmpty else { return false }
            selected = max(0, selected - rowSize)
            setPreview(client)
            showPanel(client)
            return true
        case 125: // down
            guard !composing.isEmpty else { return false }
            selected = min(selected + rowSize, max(0, candidates.count - 1))
            setPreview(client)
            showPanel(client)
            return true
        default:
            break
        }

        if !composing.isEmpty, let n = Int(chars), n >= 1, n <= rowSize {
            let index = flags.contains(.shift) ? n - 1 + rowSize : n - 1
            if index < candidates.count {
                selected = index
                commitSelected(client)
            }
            return true
        }

        if chars.count == 1, let raw = chars.first {
            let ch = Character(raw.lowercased())
            if ch.isASCII && ch.isLetter {
                composing.append(ch)
                updateComposition(client)
                return true
            }
            if ch == "'" {
                return true
            }
        }

        if composing.isEmpty, let typed = event.characters, typed.count == 1,
           let ch = typed.first {
            if let mapped = Self.punctuation[ch] {
                client.insertText(mapped,
                                  replacementRange: NSRange(location: NSNotFound, length: 0))
                return true
            }
            if ch == "\"" {
                let quote = openQuote ? "\u{201D}" : "\u{201C}"
                openQuote.toggle()
                client.insertText(quote,
                                  replacementRange: NSRange(location: NSNotFound, length: 0))
                return true
            }
        }

        if !composing.isEmpty {
            commitSelected(client)
        }
        return false
    }

    private func updateComposition(_ client: IMKTextInput) {
        guard !composing.isEmpty else {
            clearComposition(client)
            return
        }
        candidates = Engine.shared.candidates(for: composing, limit: Self.maxShown)
        selected = 0

        setPreview(client)
        showPanel(client)
    }

    /// The marked text always mirrors the highlighted candidate, so the inline
    /// preview and the panel can never disagree.
    private func setPreview(_ client: IMKTextInput) {
        let text = candidates.indices.contains(selected) ? candidates[selected].text : composing
        client.setMarkedText(text,
                             selectionRange: NSRange(location: text.utf16.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func showPanel(_ client: IMKTextInput) {
        guard !composing.isEmpty, !candidates.isEmpty else {
            CandidatePanel.shared.dismiss()
            return
        }
        var caret = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &caret)
        CandidatePanel.shared.present(candidates: candidates, selected: selected, at: caret) {
            [weak self] index in
            guard let self, let target = self.client() else { return }
            guard index >= 0, index < self.candidates.count else { return }
            self.selected = index
            self.commitSelected(target)
        }
    }

    private func clearComposition(_ client: IMKTextInput) {
        composing = ""
        candidates = []
        selected = 0
        CandidatePanel.shared.dismiss()
        client.setMarkedText("",
                             selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func commitSelected(_ client: IMKTextInput) {
        guard !composing.isEmpty else { return }
        let chosen = candidates.indices.contains(selected) ? candidates[selected] : nil
        let text = chosen?.text ?? composing
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))

        if let chosen, chosen.words.count == chosen.codes.count {
            for (word, code) in zip(chosen.words, chosen.codes) {
                Learning.shared.record(code: code.replacingOccurrences(of: " ", with: ""),
                                       text: word)
            }
        } else {
            Learning.shared.record(code: composing, text: text)
        }

        composing = ""
        candidates = []
        selected = 0
        CandidatePanel.shared.dismiss()
        Learning.shared.save()
    }
}
