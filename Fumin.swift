import Cocoa
import ServiceManagement
import IOKit

// Fumin — メニューバー常駐のトグルアプリ。
// クリックするたびに「フタを閉じてもスリープしないモード」⇄「通常モード」を切り替える。
// 仕組み: ON で `sudo -n pmset -a disablesleep 1`（フタ閉じスリープ無効）＋ caffeinate（アイドル抑止）。
// OFF / 終了 / 起動時 で必ず disablesleep 0 に戻すので「永久にスリープできない」事故を防ぐ。

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var caffeinate: Process?
    var isOn = false

    // ON中にフタが閉じたら画面だけ消す（クラムシェルで外部モニタを暗くする用）
    var autoBlank: Bool {
        get { UserDefaults.standard.bool(forKey: "autoBlankOnLidClose") }
        set { UserDefaults.standard.set(newValue, forKey: "autoBlankOnLidClose") }
    }

    // pmset を許可するための sudoers 1行（未設定時に案内で使う）
    var installCmd: String {
        "echo '\(NSUserName()) ALL=(root) NOPASSWD: /usr/bin/pmset' | sudo tee /etc/sudoers.d/fumin >/dev/null && sudo chmod 440 /etc/sudoers.d/fumin"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Dock に出さない

        // 起動時は必ず「通常モード」から始める（前回がクラッシュでも安全側に倒す）
        _ = runPmset(disable: false)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateUI()

        // フタ閉じ検出はイベント通知が無いのでポーリング（2秒間隔・guardのみなので実質ゼロ負荷）
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.lidTick() }
    }

    // MARK: - 画面だけオフ

    // フタ閉じ検出: IOPMrootDomain の AppleClamshellState（true = 閉）
    func lidClosed() -> Bool {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        let p = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
        return (p?.takeRetainedValue() as? Bool) ?? false
    }

    func lidTick() {
        guard isOn, autoBlank, lidClosed(),
              CGDisplayIsAsleep(CGMainDisplayID()) == 0 else { return } // 既に消えていれば何もしない
        blankDisplays()
    }

    // 画面だけスリープ（root不要）。disablesleep 中なら本体は動き続ける。
    // キーボード・マウスに触れると画面は復帰する（macOSの仕様）。
    @objc func blankDisplays() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["displaysleepnow"]
        try? p.run()
    }

    @objc func toggleAutoBlank() { autoBlank.toggle() }

    // 左クリック = トグル / 右クリック = メニュー
    @objc func handleClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { toggle(); return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            toggle()
        }
    }

    func toggle() { isOn ? turnOff() : turnOn() }

    func turnOn() {
        guard runPmset(disable: true) else { showSudoersAlert(); return } // 権限が無ければ案内して中止
        let c = Process()
        c.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        // -w 自PID: Fumin がクラッシュ等どんな死に方をしても caffeinate が道連れで終了し、孤児化してスリープ禁止が残らない
        c.arguments = ["-imsu", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        try? c.run()
        caffeinate = c
        isOn = true
        updateUI()
    }

    func turnOff() {
        caffeinate?.terminate()
        caffeinate = nil
        _ = runPmset(disable: false)
        isOn = false
        updateUI()
    }

    // sudo -n（パスワードを聞かない）。sudoers 未設定なら失敗するので false を返す
    @discardableResult
    func runPmset(disable: Bool) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", disable ? "1" : "0"]
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    func updateUI() {
        guard let button = statusItem.button else { return }
        let symbol = isOn ? "cup.and.saucer.fill" : "moon.zzz"
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: isOn ? "スリープ無効中" : "通常")
        img?.isTemplate = true
        button.image = img
        button.contentTintColor = isOn ? .systemOrange : nil // ON はオレンジで一目瞭然
        button.toolTip = isOn ? "フタ閉じスリープ: 無効中（クリックで解除）"
                              : "通常モード（クリックで無効化）"
    }

    func showMenu() {
        let menu = NSMenu()
        let status = NSMenuItem(
            title: isOn ? "🟠 スリープ無効：ON（フタ閉じOK）" : "🌙 通常モード：OFF",
            action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let blank = NSMenuItem(title: "画面をすぐ消す", action: #selector(blankDisplays), keyEquivalent: "")
        blank.target = self
        menu.addItem(blank)

        let auto = NSMenuItem(title: "フタを閉じたら画面も消す（ON中のみ）", action: #selector(toggleAutoBlank), keyEquivalent: "")
        auto.target = self
        auto.state = autoBlank ? .on : .off
        menu.addItem(auto)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "ログイン時に自動起動", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Fumin を終了", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // 戻して次の左クリックをトグルに復帰
    }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Fumin login toggle error: \(error)")
        }
    }

    func showSudoersAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "あと1ステップで使えます"
        a.informativeText = """
        スリープ設定を変更する許可がまだありません。
        ターミナルを開いて、次の1行を一度だけ実行してください（「コピー」を押すとコピーされます）。

        \(installCmd)
        """
        a.addButton(withTitle: "コマンドをコピー")
        a.addButton(withTitle: "閉じる")
        if a.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(installCmd, forType: .string)
        }
    }

    @objc func quit() {
        if isOn { turnOff() } // 終了前に必ず通常へ戻す
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isOn {
            caffeinate?.terminate()
            _ = runPmset(disable: false) // 念のための二重安全
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
