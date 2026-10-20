import Cocoa
import InputMethodKit
import CantainputCore

final class CantoneseInputController: IMKInputController {
    private var composing = ""
    private var candidates: [Candidate] = []
    private var selected = 0
    private static let maxShown = 9

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

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) { return false }

        let chars = event.charactersIgnoringModifiers ?? ""

        switch event.keyCode {
        case 51:
            guard !composing.isEmpty else { return false }
            composing.removeLast()
            updateComposition(client)
            return true
        case 53:
            guard !composing.isEmpty else { return false }
            clearComposition(client)
            return true
        case 36, 76, 49:
            guard !composing.isEmpty else { return false }
            commitSelected(client)
            return true
        case 123:
            guard !composing.isEmpty else { return false }
            selected = max(0, selected - 1)
            showPanel(client)
            return true
        case 124:
            guard !composing.isEmpty else { return false }
            selected = min(selected + 1, max(0, candidates.count - 1))
            showPanel(client)
            return true
        case 125:
            guard !composing.isEmpty else { return false }
            selected = min(selected + 1, max(0, candidates.count - 1))
            showPanel(client)
            return true
        case 126:
            guard !composing.isEmpty else { return false }
            selected = max(0, selected - 1)
            showPanel(client)
            return true
        default:
            break
        }

        if let n = Int(chars), n >= 1, n <= 9, !composing.isEmpty {
            if n <= candidates.count {
                selected = n - 1
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
        client.setMarkedText(composing,
                             selectionRange: NSRange(location: composing.utf16.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        candidates = Engine.shared.candidates(for: composing, limit: Self.maxShown)
        selected = 0
        showPanel(client)
    }

    private func showPanel(_ client: IMKTextInput) {
        guard !composing.isEmpty, !candidates.isEmpty else {
            CandidatePanel.shared.dismiss()
            return
        }
        var caret = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &caret)
        CandidatePanel.shared.present(candidates: candidates, selected: selected, at: caret) { [weak self] index in
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
        let code = composing
        let text: String
        if candidates.indices.contains(selected) {
            text = candidates[selected].text
        } else {
            text = code
        }
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        Learning.shared.record(code: code, text: text)
        composing = ""
        candidates = []
        selected = 0
        CandidatePanel.shared.dismiss()
        Learning.shared.save()
    }
}
