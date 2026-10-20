#!/bin/bash
# Check whether macOS has registered the input method yet.
set -euo pipefail
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/list.swift" <<'SWIFT'
import Carbon
import Foundation

func prop(_ s: TISInputSource, _ key: String) -> String {
    guard let raw = TISGetInputSourceProperty(s, key as CFString) else { return "" }
    return Unmanaged<CFString>.fromOpaque(UnsafeRawPointer(raw)).takeUnretainedValue() as String
}

let all = (TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource]) ?? []
let hits = all.filter {
    prop($0, kTISPropertyInputSourceID as String).lowercased().contains("cantainput")
        || prop($0, kTISPropertyLocalizedName as String).contains("粵拼")
}
for s in hits {
    print("FOUND  \(prop(s, kTISPropertyInputSourceID as String))  |  \(prop(s, kTISPropertyLocalizedName as String))")
}
if hits.isEmpty {
    print("not registered yet — log out and back in, then run this again")
    exit(2)
}
SWIFT
swiftc -O "$TMP/list.swift" -o "$TMP/list" 2>/dev/null
"$TMP/list"
