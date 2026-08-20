import Cocoa
import Carbon.HIToolbox

// config lives in ~/.mangahop.json

struct SiteRule: Codable {
    var host: String
    var nthFromEnd: Int
}

struct Config: Codable {
    var next = "ctrl+cmd+right"
    var prev = "ctrl+cmd+left"
    var zapAds = true
    var rules: [SiteRule] = []

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        next = (try? c.decode(String.self, forKey: .next)) ?? next
        prev = (try? c.decode(String.self, forKey: .prev)) ?? prev
        zapAds = (try? c.decode(Bool.self, forKey: .zapAds)) ?? zapAds
        rules = (try? c.decode([SiteRule].self, forKey: .rules)) ?? []
    }
}

let configPath = NSHomeDirectory() + "/.mangahop.json"

func loadConfig() -> Config {
    guard let data = FileManager.default.contents(atPath: configPath),
          let cfg = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
    return cfg
}

func saveConfig(_ cfg: Config) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    try? enc.encode(cfg).write(to: URL(fileURLWithPath: configPath))
}

// hotkeys

let keyCodes: [String: UInt32] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
    "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
    "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
    "return": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
    ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50,
    "delete": 51, "esc": 53,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98,
    "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    "left": 123, "right": 124, "down": 125, "up": 126,
    "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
]

let keyNames: [UInt16: String] = {
    var m: [UInt16: String] = [:]
    for (name, code) in keyCodes { m[UInt16(code)] = name }
    return m
}()

func parseHotkey(_ spec: String) -> (code: UInt32, mods: UInt32)? {
    var mods: UInt32 = 0
    var key: String?
    for part in spec.lowercased().split(separator: "+") {
        switch part.trimmingCharacters(in: .whitespaces) {
        case "cmd", "command": mods |= UInt32(cmdKey)
        case "ctrl", "control": mods |= UInt32(controlKey)
        case "alt", "opt", "option": mods |= UInt32(optionKey)
        case "shift": mods |= UInt32(shiftKey)
        case let k: key = k
        }
    }
    guard let k = key, let code = keyCodes[k] else { return nil }
    return (code, mods)
}

func prettyHotkey(_ spec: String) -> String {
    let symbols = ["ctrl": "⌃", "control": "⌃", "alt": "⌥", "opt": "⌥", "option": "⌥",
                   "shift": "⇧", "cmd": "⌘", "command": "⌘",
                   "left": "←", "right": "→", "up": "↑", "down": "↓",
                   "return": "↩", "space": "␣", "tab": "⇥", "esc": "⎋", "delete": "⌫"]
    return spec.lowercased().split(separator: "+")
        .map { symbols[String($0)] ?? $0.uppercased() }
        .joined()
}

// finding the chapter number in a url
//
// most aggregators are the madara wordpress theme (/manga/slug/chapter-104/,
// decimals written as chapter-104-5), mangakakalot-likes use chapter_104.5,
// mangapark does /c104, webtoons does ?episode_no=104. plus french/spanish
// keywords and "episode"/"ep" for manhwa.

func numbersAfterHost(_ url: String) -> [NSRange] {
    guard let host = URLComponents(string: url)?.host else { return [] }
    let ns = url as NSString
    let hostRange = ns.range(of: host)
    guard hostRange.location != NSNotFound else { return [] }
    let start = hostRange.location + hostRange.length
    let re = try! NSRegularExpression(pattern: "\\d+(?:\\.\\d+)?")
    return re.matches(in: url, range: NSRange(location: start, length: ns.length - start))
        .map { $0.range }
}

func chapterToken(in url: String, config: Config) -> NSRange? {
    let ns = url as NSString
    let host = URLComponents(string: url)?.host

    if let host = host, let rule = config.rules.first(where: { $0.host == host }) {
        let nums = numbersAfterHost(url)
        let i = nums.count - 1 - rule.nthFromEnd
        if i >= 0 && i < nums.count { return nums[i] }
    }

    // only look past the hostname so digits in the domain never match
    var search = NSRange(location: 0, length: ns.length)
    if let host = host {
        let hr = ns.range(of: host)
        if hr.location != NSNotFound {
            search.location = hr.location + hr.length
            search.length = ns.length - search.location
        }
    }

    let keyword = try! NSRegularExpression(pattern:
        "(?i)\\b(episode_no|episode|chapitre|chapter|capitulo|chap|cap|ch|ep)[-_/= ]?(\\d+(?:\\.\\d+)?)(-\\d+(?=[/?#.]|$))?")
    if let m = keyword.matches(in: url, range: search).last {
        var r = m.range(at: 2)
        if m.range(at: 3).location != NSNotFound { r = NSUnionRange(r, m.range(at: 3)) }
        return r
    }

    let cStyle = try! NSRegularExpression(pattern: "(?<=/)c(\\d+(?:\\.\\d+)?)(?=[/?#.]|$)")
    if let m = cStyle.matches(in: url, range: search).last {
        return m.range(at: 1)
    }

    return numbersAfterHost(url).last
}

func shiftNumber(_ s: String, by delta: Int) -> String? {
    // "104-5" is how madara sites write 104.5
    guard let v = Double(s.replacingOccurrences(of: "-", with: ".")) else { return nil }
    let whole = Int(v.rounded(.down))
    let out = delta > 0 ? whole + 1 : (v > Double(whole) ? whole : whole - 1)
    guard out >= 0 else { return nil }
    if s.allSatisfy(\.isNumber) && s.hasPrefix("0") && s.count > 1 {
        return String(format: "%0\(s.count)d", out)  // keep zero padding
    }
    return String(out)
}

func shiftedChapterURL(_ url: String, delta: Int, config: Config) -> String? {
    guard let r = chapterToken(in: url, config: config) else { return nil }
    let ns = url as NSString
    guard let n = shiftNumber(ns.substring(with: r), by: delta) else { return nil }
    return ns.replacingCharacters(in: r, with: n)
}

// talking to the browser

struct BrowserApp {
    let bundleID: String
    let appName: String
    let isSafari: Bool
}

let browsers = [
    BrowserApp(bundleID: "com.google.Chrome", appName: "Google Chrome", isSafari: false),
    BrowserApp(bundleID: "com.brave.Browser", appName: "Brave Browser", isSafari: false),
    BrowserApp(bundleID: "com.microsoft.edgemac", appName: "Microsoft Edge", isSafari: false),
    BrowserApp(bundleID: "company.thebrowser.Browser", appName: "Arc", isSafari: false),
    BrowserApp(bundleID: "com.vivaldi.Vivaldi", appName: "Vivaldi", isSafari: false),
    BrowserApp(bundleID: "com.apple.Safari", appName: "Safari", isSafari: true),
]

func activeBrowser() -> BrowserApp? {
    if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
       let b = browsers.first(where: { $0.bundleID == front }) {
        return b
    }
    let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
    return browsers.first { running.contains($0.bundleID) }
}

func applescript(_ src: String) -> String? {
    var err: NSDictionary?
    let result = NSAppleScript(source: src)?.executeAndReturnError(&err)
    if err != nil { return nil }
    return result?.stringValue ?? ""
}

func tabURL(_ b: BrowserApp) -> String? {
    let src = b.isSafari
        ? "tell application \"Safari\" to return URL of front document"
        : "tell application \"\(b.appName)\" to return URL of active tab of front window"
    guard let url = applescript(src), !url.isEmpty, url != "missing value" else { return nil }
    return url
}

func setTabURL(_ b: BrowserApp, _ url: String) -> Bool {
    let esc = url.replacingOccurrences(of: "\\", with: "\\\\")
                 .replacingOccurrences(of: "\"", with: "\\\"")
    let src = b.isSafari
        ? "tell application \"Safari\" to set URL of front document to \"\(esc)\""
        : "tell application \"\(b.appName)\" to set URL of active tab of front window to \"\(esc)\""
    return applescript(src) != nil
}

// runs in the page after each hop: kills popunders, cross-origin ad iframes
// and full-screen overlays. cosmetic cleanup, not a network-level blocker.
let zapJS = "(function(){if(window.__mangahop)return;window.__mangahop=1;"
    + "try{window.open=function(){return null}}catch(e){}"
    + "var kill=function(){"
    + "document.querySelectorAll('ins.adsbygoogle,[id^=google_ads],[class*=adsbox]').forEach(function(n){n.remove()});"
    + "document.querySelectorAll('iframe').forEach(function(f){try{var u=new URL(f.src,location.href);"
    + "if(u.host&&u.host!==location.host&&!/youtube|vimeo|disqus|recaptcha/.test(u.host))f.remove()}catch(e){}});"
    + "var area=innerWidth*innerHeight;"
    + "document.querySelectorAll('body > *, body > * > *').forEach(function(n){"
    + "if(n.tagName==='IMG'||n.tagName==='CANVAS')return;"
    + "var s=getComputedStyle(n);if(s.position!=='fixed'||(parseInt(s.zIndex)||0)<1000)return;"
    + "var r=n.getBoundingClientRect();if(r.width*r.height>area*0.3)n.remove()});"
    + "};kill();var t=0,iv=setInterval(function(){kill();if(++t>15)clearInterval(iv)},1000)})()"

func injectZap(_ b: BrowserApp) -> Bool {
    let esc = zapJS.replacingOccurrences(of: "\\", with: "\\\\")
                   .replacingOccurrences(of: "\"", with: "\\\"")
    let src = b.isSafari
        ? "tell application \"Safari\" to do JavaScript \"\(esc)\" in front document"
        : "tell application \"\(b.appName)\" to execute active tab of front window javascript \"\(esc)\""
    return applescript(src) != nil
}

// app

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    static var shared: AppDelegate?

    var statusItem: NSStatusItem!
    var config = loadConfig()
    var hotkeys: [EventHotKeyRef] = []

    var settings: NSWindow?
    var nextBtn: NSButton!
    var prevBtn: NSButton!
    var urlField: NSTextField!
    var numberPopup: NSPopUpButton!
    var previewLabel: NSTextField!
    var rulesPopup: NSPopUpButton!
    var candidates: [NSRange] = []
    var recording: Int?  // 1 = prev, 2 = next
    var keyMonitor: Any?

    func applicationDidFinishLaunching(_ note: Notification) {
        AppDelegate.shared = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📖"

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            DispatchQueue.main.async {
                AppDelegate.shared?.navigate(id.id == 2 ? 1 : -1)
            }
            return noErr
        }, 1, &spec, nil, nil)

        registerHotkeys()
    }

    func registerHotkeys() {
        for hk in hotkeys { UnregisterEventHotKey(hk) }
        hotkeys.removeAll()
        for (id, spec) in [(UInt32(1), config.prev), (UInt32(2), config.next)] {
            guard let hk = parseHotkey(spec) else { continue }
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: OSType(0x4D48_4F50), id: id)
            if RegisterEventHotKey(hk.code, hk.mods, hkID, GetApplicationEventTarget(), 0, &ref) == noErr,
               let ref = ref {
                hotkeys.append(ref)
            }
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        for (title, action) in [("Next chapter \(prettyHotkey(config.next))", #selector(nextChapter)),
                                ("Previous chapter \(prettyHotkey(config.prev))", #selector(prevChapter))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let zap = NSMenuItem(title: "Zap ads after hopping", action: #selector(toggleZap), keyEquivalent: "")
        zap.target = self
        zap.state = config.zapAds ? .on : .off
        menu.addItem(zap)
        let prefs = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func navigate(_ delta: Int) {
        guard let b = activeBrowser(),
              let url = tabURL(b),
              let newURL = shiftedChapterURL(url, delta: delta, config: config),
              setTabURL(b, newURL)
        else { NSSound.beep(); return }
        if config.zapAds { scheduleZap(b) }
    }

    @objc func nextChapter() { navigate(1) }
    @objc func prevChapter() { navigate(-1) }

    @objc func toggleZap() {
        config.zapAds.toggle()
        saveConfig(config)
        rebuildMenu()
    }

    var hintShown = false

    // inject a few times while the page loads; the js loops for 15s on its own
    func scheduleZap(_ b: BrowserApp) {
        var fails = 0
        for (i, delay) in [1.5, 4.0, 8.0].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.config.zapAds else { return }
                if !injectZap(b) { fails += 1 }
                if i == 2 && fails == 3 { self.showZapHint(b) }
            }
        }
    }

    func showZapHint(_ b: BrowserApp) {
        guard !hintShown else { return }
        hintShown = true
        let alert = NSAlert()
        alert.messageText = "Ad zapping needs one browser setting"
        alert.informativeText = b.isSafari
            ? "In Safari: Settings → Advanced → Show Develop menu, then Develop → Allow JavaScript from Apple Events.\n\nOr turn off \"Zap ads after hopping\" in the MangaHop menu."
            : "In \(b.appName): View → Developer → Allow JavaScript from Apple Events.\n\nOr turn off \"Zap ads after hopping\" in the MangaHop menu."
        alert.runModal()
    }

    // settings window

    @objc func openSettings() {
        if settings == nil { buildSettings() }
        refreshRulesList()
        settings?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func buildSettings() {
        func label(_ s: String, dim: Bool = false) -> NSTextField {
            let l = NSTextField(wrappingLabelWithString: s)
            if dim {
                l.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
                l.textColor = .secondaryLabelColor
            }
            return l
        }
        func row(_ views: [NSView]) -> NSStackView {
            let r = NSStackView(views: views)
            r.orientation = .horizontal
            r.spacing = 8
            return r
        }

        nextBtn = NSButton(title: prettyHotkey(config.next), target: self, action: #selector(recordNext))
        prevBtn = NSButton(title: prettyHotkey(config.prev), target: self, action: #selector(recordPrev))

        urlField = NSTextField(string: "")
        urlField.placeholderString = "paste a chapter URL from the site"
        urlField.delegate = self

        numberPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        numberPopup.target = self
        numberPopup.action = #selector(candidatePicked)

        previewLabel = label("", dim: true)

        rulesPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        let removeBtn = NSButton(title: "Remove", target: self, action: #selector(removeRule))

        let stack = NSStackView(views: [
            label("Hotkeys — click a button, then press the new combo (esc cancels)."),
            row([label("Next chapter"), nextBtn, label("Previous"), prevBtn]),
            NSBox(),
            label("Site fixes — if a site isn't detected right, paste any chapter URL and pick which number is the chapter. MangaHop remembers it for that site."),
            urlField,
            row([label("Chapter number:"), numberPopup]),
            previewLabel,
            NSButton(title: "Save rule for this site", target: self, action: #selector(saveRule)),
            NSBox(),
            row([label("Saved sites:"), rulesPopup, removeBtn]),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 360),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "MangaHop Settings"
        win.isReleasedWhenClosed = false
        win.center()
        win.contentView?.addSubview(stack)
        let cv = win.contentView!
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cv.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),
            urlField.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        settings = win
    }

    @objc func recordNext() { beginRecording(2) }
    @objc func recordPrev() { beginRecording(1) }

    func beginRecording(_ which: Int) {
        endRecording()
        recording = which
        (which == 2 ? nextBtn : prevBtn)?.title = "press keys…"
        for hk in hotkeys { UnregisterEventHotKey(hk) }
        hotkeys.removeAll()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            self?.captured(ev)
            return nil
        }
    }

    func captured(_ ev: NSEvent) {
        defer { endRecording() }
        guard ev.keyCode != 53 else { return }
        var parts: [String] = []
        if ev.modifierFlags.contains(.control) { parts.append("ctrl") }
        if ev.modifierFlags.contains(.option) { parts.append("alt") }
        if ev.modifierFlags.contains(.shift) { parts.append("shift") }
        if ev.modifierFlags.contains(.command) { parts.append("cmd") }
        guard !parts.isEmpty, let name = keyNames[ev.keyCode] else { NSSound.beep(); return }
        parts.append(name)
        let spec = parts.joined(separator: "+")
        if recording == 2 { config.next = spec } else { config.prev = spec }
        saveConfig(config)
    }

    func endRecording() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        recording = nil
        registerHotkeys()
        nextBtn?.title = prettyHotkey(config.next)
        prevBtn?.title = prettyHotkey(config.prev)
    }

    func controlTextDidChange(_ note: Notification) {
        refreshCandidates()
    }

    func refreshCandidates() {
        numberPopup.removeAllItems()
        previewLabel.stringValue = ""
        let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        candidates = numbersAfterHost(url)
        let ns = url as NSString
        for r in candidates {
            let start = max(0, r.location - 16)
            let end = min(ns.length, r.location + r.length + 8)
            var ctx = ns.substring(with: NSRange(location: start, length: end - start))
            if start > 0 { ctx = "…" + ctx }
            if end < ns.length { ctx += "…" }
            numberPopup.addItem(withTitle: "\(ns.substring(with: r))    \(ctx)")
        }
        // preselect whatever the auto-detection would pick
        if let auto = chapterToken(in: url, config: config),
           let i = candidates.firstIndex(where: { NSIntersectionRange($0, auto).length > 0 }) {
            numberPopup.selectItem(at: i)
        }
        candidatePicked()
    }

    @objc func candidatePicked() {
        let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        let i = numberPopup.indexOfSelectedItem
        guard i >= 0, i < candidates.count else { previewLabel.stringValue = ""; return }
        let ns = url as NSString
        if let n = shiftNumber(ns.substring(with: candidates[i]), by: 1) {
            previewLabel.stringValue = "next chapter would be:  " + ns.replacingCharacters(in: candidates[i], with: n)
        }
    }

    @objc func saveRule() {
        let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        let i = numberPopup.indexOfSelectedItem
        guard let host = URLComponents(string: url)?.host, i >= 0, i < candidates.count else {
            NSSound.beep(); return
        }
        config.rules.removeAll { $0.host == host }
        config.rules.append(SiteRule(host: host, nthFromEnd: candidates.count - 1 - i))
        saveConfig(config)
        refreshRulesList()
    }

    @objc func removeRule() {
        let i = rulesPopup.indexOfSelectedItem
        guard i >= 0, i < config.rules.count else { return }
        config.rules.remove(at: i)
        saveConfig(config)
        refreshRulesList()
    }

    func refreshRulesList() {
        rulesPopup.removeAllItems()
        for rule in config.rules {
            let pos = rule.nthFromEnd == 0 ? "last number"
                    : "\(rule.nthFromEnd + 1)th number from the end"
            rulesPopup.addItem(withTitle: "\(rule.host) — \(pos)")
        }
    }
}

// `MangaHop --shift <url> next|prev` prints the shifted url, for testing
let args = CommandLine.arguments
if args.count == 4 && args[1] == "--shift" {
    if let out = shiftedChapterURL(args[2], delta: args[3] == "prev" ? -1 : 1, config: loadConfig()) {
        print(out)
        exit(0)
    }
    FileHandle.standardError.write(Data("no chapter number found\n".utf8))
    exit(1)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
