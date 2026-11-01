import UIKit
import WebKit

/// 窗口内容统一接口
protocol DeckAppContent: AnyObject {
    var view: UIView { get }
    func activate()
    func handleTap(at point: CGPoint)
    func handleScroll(_ dy: CGFloat)
}

class BaseContentView: UIView, DeckAppContent {

    var view: UIView { self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func activate() {}
    func handleTap(at point: CGPoint) {}
    func handleScroll(_ dy: CGFloat) {}

    func makeLabel(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }
}

// MARK: - 笔记

final class NotesContentView: BaseContentView {

    private let docID: UUID
    private let header = UILabel()
    private let textView = UITextView()
    private let hint = UILabel()

    init(docID: UUID) {
        self.docID = docID
        super.init(frame: .zero)

        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.textColor = UIColor.white.withAlphaComponent(0.55)
        addSubview(header)

        textView.backgroundColor = .clear
        textView.textColor = UIColor(white: 0.93, alpha: 1)
        textView.font = .systemFont(ofSize: 19)
        textView.isEditable = false
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 18, bottom: 24, right: 18)
        addSubview(textView)

        hint.text = "用手机键盘输入"
        hint.font = .systemFont(ofSize: 10.5)
        hint.textColor = UIColor.white.withAlphaComponent(0.25)
        hint.textAlignment = .right
        addSubview(hint)

        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reload() {
        guard let doc = NotesStore.shared.doc(docID) else {
            textView.text = "（文档已被删除）"
            return
        }
        header.text = doc.title
        textView.text = doc.text
    }

    override func activate() {
        let model = DeckModel.shared
        model.insertSink = { [weak self] text in
            guard let self else { return }
            NotesStore.shared.append(self.docID, text)
            self.reload()
        }
        model.backspaceSink = { [weak self] in
            guard let self else { return }
            NotesStore.shared.backspace(self.docID)
            self.reload()
        }
        model.returnSink = { [weak self] in
            guard let self else { return }
            NotesStore.shared.append(self.docID, "\n")
            self.reload()
        }
        model.scrollSink = { [weak self] dy in self?.handleScroll(dy) }
    }

    override func handleTap(at point: CGPoint) {
        activate()
    }

    override func handleScroll(_ dy: CGFloat) {
        var offset = textView.contentOffset
        offset.y = min(max(0, offset.y + dy), max(0, textView.contentSize.height - textView.bounds.height))
        textView.contentOffset = offset
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        header.frame = CGRect(x: 18, y: 8, width: bounds.width - 36, height: 18)
        hint.frame = CGRect(x: bounds.width - 120, y: bounds.height - 18, width: 108, height: 14)
        textView.frame = CGRect(x: 0, y: 28, width: bounds.width, height: max(0, bounds.height - 28))
    }
}

// MARK: - 浏览器

final class BrowserContentView: BaseContentView, WKNavigationDelegate {

    private let toolbar = UIView()
    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let reloadButton = UIButton(type: .system)
    private let urlButton = UIButton(type: .system)
    private let zoomButton = UIButton(type: .system)
    private let uaButton = UIButton(type: .system)
    private let urlLabel = UILabel()
    private let progress = UIView()
    private let webView = WKWebView()
    private var urlString = "https://www.apple.com.cn"
    private var editingURL = false
    private var urlBuffer = ""
    private let zoomTitles = ["1.0×", "1.15×", "1.3×"]
    private let zoomValues: [CGFloat] = [1.0, 1.15, 1.3]
    private var zoomIndex = 0
    private var mobileUA = false

    init(startURL: String?) {
        super.init(frame: .zero)
        build()
        if let startURL, !startURL.isEmpty {
            load(startURL)
        } else {
            load(urlString)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        load(urlString)
    }

    private func build() {
        toolbar.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        addSubview(toolbar)

        configure(backButton, symbol: "chevron.left")
        configure(forwardButton, symbol: "chevron.right")
        configure(reloadButton, symbol: "arrow.clockwise")
        [backButton, forwardButton, reloadButton].forEach { toolbar.addSubview($0) }

        urlLabel.font = .systemFont(ofSize: 12)
        urlLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        urlLabel.lineBreakMode = .byTruncatingMiddle
        urlLabel.text = urlString
        toolbar.addSubview(urlLabel)

        urlButton.setTitle("网址", for: .normal)
        urlButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        urlButton.setTitleColor(.white, for: .normal)
        urlButton.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        urlButton.layer.cornerRadius = 6
        toolbar.addSubview(urlButton)

        zoomButton.setTitle(zoomTitles[0], for: .normal)
        zoomButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        zoomButton.setTitleColor(UIColor.white.withAlphaComponent(0.8), for: .normal)
        zoomButton.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        zoomButton.layer.cornerRadius = 6
        toolbar.addSubview(zoomButton)

        uaButton.setTitle("电脑", for: .normal)
        uaButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        uaButton.setTitleColor(UIColor.white.withAlphaComponent(0.8), for: .normal)
        uaButton.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        uaButton.layer.cornerRadius = 6
        toolbar.addSubview(uaButton)

        progress.backgroundColor = UIColor(red: 0.36, green: 0.56, blue: 1.0, alpha: 1)
        progress.isHidden = true
        addSubview(progress)

        webView.navigationDelegate = self
        webView.isUserInteractionEnabled = false
        webView.allowsBackForwardNavigationGestures = false
        addSubview(webView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure(_ button: UIButton, symbol: String) {
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.8)
    }

    private func load(_ text: String) {
        var candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.isEmpty { return }
        if !candidate.contains("://") {
            candidate = candidate.contains(".") ? "https://\(candidate)" : "https://www.bing.com/search?q=\(candidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        guard let url = URL(string: candidate) else { return }
        urlString = candidate
        urlLabel.text = candidate
        webView.load(URLRequest(url: url))
    }

    /// 切「电脑 / 手机」UA：有些站只在手机版下才给完整功能
    private func toggleUA() {
        mobileUA.toggle()
        if mobileUA {
            webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        } else {
            webView.customUserAgent = nil
        }
        uaButton.setTitle(mobileUA ? "手机" : "电脑", for: .normal)
        webView.reload()
    }

    private func cycleZoom() {
        zoomIndex = (zoomIndex + 1) % zoomValues.count
        webView.pageZoom = zoomValues[zoomIndex]
        zoomButton.setTitle(zoomTitles[zoomIndex], for: .normal)
    }

    private func beginURL() {
        editingURL = true
        urlBuffer = urlString
        urlLabel.text = urlBuffer + "▎"
        bindSinks()
    }

    private func bindSinks() {
        let model = DeckModel.shared
        model.insertSink = { [weak self] text in
            guard let self else { return }
            self.urlBuffer += text
            self.urlLabel.text = self.urlBuffer + "▎"
        }
        model.backspaceSink = { [weak self] in
            guard let self else { return }
            if !self.urlBuffer.isEmpty { self.urlBuffer.removeLast() }
            self.urlLabel.text = self.urlBuffer + "▎"
        }
        model.returnSink = { [weak self] in
            guard let self else { return }
            self.editingURL = false
            self.load(self.urlBuffer)
        }
    }

    override func activate() {
        let model = DeckModel.shared
        model.scrollSink = { [weak self] dy in self?.handleScroll(dy) }
        if editingURL {
            bindSinks()
        } else {
            bindPageInput()
        }
    }

    /// 键盘直接打迸网页里的输入框（金山文档、腾讯文档这类靠它才能用）
    private func bindPageInput() {
        let model = DeckModel.shared
        model.insertSink = { [weak self] text in self?.insertIntoPage(text) }
        model.backspaceSink = { [weak self] in self?.backspaceInPage() }
        model.returnSink = { [weak self] in self?.newlineInPage() }
    }

    private func jsString(_ text: String) -> String {
        var out = "\""
        for char in text {
            switch char {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out.append(char)
            }
        }
        out += "\""
        return out
    }

    private func insertIntoPage(_ text: String) {
        guard !text.isEmpty else { return }
        let js = """
        (function(t){
          var el = document.activeElement;
          if (!el || el === document.body) return 'none';
          if (el.isContentEditable) { document.execCommand('insertText', false, t); return 'editable'; }
          if (typeof el.value === 'string') {
            var start = el.selectionStart, end = el.selectionEnd;
            if (typeof start === 'number') {
              el.value = el.value.slice(0, start) + t + el.value.slice(end);
              el.selectionStart = el.selectionEnd = start + t.length;
            } else {
              el.value += t;
            }
            el.dispatchEvent(new Event('input', {bubbles:true}));
            return 'value';
          }
          return 'none';
        })(\(jsString(text)));
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func backspaceInPage() {
        let js = """
        (function(){
          var el = document.activeElement;
          if (!el || el === document.body) return;
          if (el.isContentEditable) { document.execCommand('delete'); return; }
          if (typeof el.value !== 'string') return;
          var start = el.selectionStart, end = el.selectionEnd;
          if (typeof start !== 'number') { el.value = el.value.slice(0, -1); }
          else if (start === end && start > 0) {
            el.value = el.value.slice(0, start - 1) + el.value.slice(end);
            el.selectionStart = el.selectionEnd = start - 1;
          } else if (start !== end) {
            el.value = el.value.slice(0, start) + el.value.slice(end);
            el.selectionStart = el.selectionEnd = start;
          }
          el.dispatchEvent(new Event('input', {bubbles:true}));
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func newlineInPage() {
        let js = """
        (function(){
          var el = document.activeElement;
          if (!el || el === document.body) return;
          if (el.isContentEditable) { document.execCommand('insertLineBreak'); return; }
          el.dispatchEvent(new KeyboardEvent('keydown', {key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true}));
          el.dispatchEvent(new KeyboardEvent('keyup', {key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true}));
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// 真实触屏 / 手机光标点击转发
    override func handleTap(at point: CGPoint) {
        let barHeight: CGFloat = 40
        if point.y <= barHeight {
            if backButton.frame.contains(point) { webView.goBack(); return }
            if forwardButton.frame.contains(point) { webView.goForward(); return }
            if reloadButton.frame.contains(point) { webView.reload(); return }
            if urlButton.frame.contains(point) { beginURL(); return }
            if zoomButton.frame.contains(point) { cycleZoom(); return }
            if uaButton.frame.contains(point) { toggleUA(); return }
            return
        }
        clickInPage(x: point.x, y: point.y - barHeight)
    }

    private func clickInPage(x: CGFloat, y: CGFloat) {
        let js = """
        (function(){
          var el = document.elementFromPoint(\(Double(x)), \(Double(y)));
          if (!el) return 'none';
          var node = el;
          while (node) {
            if (node.tagName === 'A' && node.href) { window.location.href = node.href; return 'link'; }
            node = node.parentElement;
          }
          try { el.click(); } catch (e) {}
          if (el.focus) { try { el.focus(); } catch (e) {} }
          return el.tagName || 'none';
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    override func handleScroll(_ dy: CGFloat) {
        let js = "window.scrollBy(0, \(Int(dy)));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !editingURL { bindPageInput() }
        urlLabel.text = webView.url?.absoluteString ?? urlString
        urlString = webView.url?.absoluteString ?? urlString
        progress.isHidden = true
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progress.isHidden = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let barHeight: CGFloat = 40
        toolbar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: barHeight)
        backButton.frame = CGRect(x: 6, y: 6, width: 28, height: 28)
        forwardButton.frame = CGRect(x: 38, y: 6, width: 28, height: 28)
        reloadButton.frame = CGRect(x: 70, y: 6, width: 28, height: 28)
        urlButton.frame = CGRect(x: bounds.width - 58, y: 6, width: 50, height: 28)
        zoomButton.frame = CGRect(x: bounds.width - 104, y: 6, width: 42, height: 28)
        uaButton.frame = CGRect(x: bounds.width - 152, y: 6, width: 44, height: 28)
        urlLabel.frame = CGRect(x: 106, y: 6, width: max(0, bounds.width - 106 - 160), height: 28)
        progress.frame = CGRect(x: 0, y: barHeight - 2, width: bounds.width, height: 2)
        webView.frame = CGRect(x: 0, y: barHeight, width: bounds.width,
                               height: max(0, bounds.height - barHeight))
    }
}

// MARK: - 时钟

final class ClockContentView: BaseContentView {

    private let clock = UILabel()
    private let date = UILabel()
    private var timer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clock.font = .monospacedDigitSystemFont(ofSize: 72, weight: .thin)
        clock.textColor = .white
        clock.textAlignment = .center
        addSubview(clock)

        date.font = .systemFont(ofSize: 16)
        date.textColor = UIColor.white.withAlphaComponent(0.55)
        date.textAlignment = .center
        addSubview(date)

        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { timer?.invalidate() }

    private func tick() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        clock.text = formatter.string(from: Date())

        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "M月d日 EEEE"
        date.text = df.string(from: Date())
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        clock.frame = CGRect(x: 0, y: bounds.height * 0.26, width: bounds.width, height: 86)
        date.frame = CGRect(x: 0, y: bounds.height * 0.26 + 92, width: bounds.width, height: 24)
    }
}

// MARK: - 计算器

final class CalculatorContentView: BaseContentView {

    private let display = UILabel()
    private let historyLabel = UILabel()
    private let keys = ["AC", "⌫", "%", "÷", "7", "8", "9", "×",
                        "4", "5", "6", "−", "1", "2", "3", "+",
                        "±", "0", ".", "="]
    private var expression = ""
    private var evaluated = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.06, alpha: 1)

        historyLabel.font = .systemFont(ofSize: 12)
        historyLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        historyLabel.textAlignment = .right
        addSubview(historyLabel)

        display.font = .monospacedDigitSystemFont(ofSize: 40, weight: .light)
        display.textColor = .white
        display.textAlignment = .right
        display.adjustsFontSizeToFitWidth = true
        display.minimumScaleFactor = 0.4
        display.text = "0"
        addSubview(display)

        for key in keys {
            let button = UIButton(type: .custom)
            button.setTitle(key, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
            button.tag = keys.firstIndex(of: key) ?? 0
            button.backgroundColor = keyColor(key)
            button.layer.cornerRadius = 6
            button.isUserInteractionEnabled = false
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func keyColor(_ key: String) -> UIColor {
        if key == "=" { return UIColor(red: 0.36, green: 0.56, blue: 1.0, alpha: 1) }
        if "÷×−+".contains(key) { return UIColor(red: 0.20, green: 0.24, blue: 0.34, alpha: 1) }
        if ["AC", "⌫", "%", "±"].contains(key) { return UIColor(white: 0.28, alpha: 1) }
        return UIColor(white: 0.15, alpha: 1)
    }

    override func handleTap(at point: CGPoint) {
        for view in subviews {
            guard let button = view as? UIButton, button.frame.contains(point) else { continue }
            press(keys[button.tag])
            return
        }
    }

    private func press(_ key: String) {
        switch key {
        case "AC":
            expression = ""
            historyLabel.text = ""
            evaluated = false
        case "⌫":
            if !expression.isEmpty { expression.removeLast() }
            evaluated = false
        case "=":
            guard !expression.isEmpty else { return }
            do {
                let value = try Expr.evaluate(expression)
                historyLabel.text = expression + " ="
                expression = Expr.format(value)
                evaluated = true
            } catch let error as ExprError {
                historyLabel.text = error.message
                expression = ""
                evaluated = false
            } catch {
                historyLabel.text = "语法错误"
                expression = ""
                evaluated = false
            }
        case "±":
            if expression.hasPrefix("-") {
                expression.removeFirst()
            } else {
                expression = "-" + expression
            }
        case "÷", "×", "−", "+":
            if evaluated { evaluated = false }
            if expression.isEmpty { return }
            if "÷×−+".contains(String(expression.suffix(1))) { expression.removeLast() }
            expression += key
        case "%":
            expression += "%"
        default:
            if evaluated {
                expression = ""
                evaluated = false
            }
            expression += key
        }
        display.text = expression.isEmpty ? "0" : expression
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        historyLabel.frame = CGRect(x: 16, y: 8, width: bounds.width - 32, height: 16)
        display.frame = CGRect(x: 16, y: 26, width: bounds.width - 32, height: 56)

        let gridTop: CGFloat = 96
        let gridHeight = max(0, bounds.height - gridTop - 10)
        let cellWidth = (bounds.width - 20 - 3 * 6) / 4
        let cellHeight = (gridHeight - 4 * 6) / 5
        for view in subviews {
            guard let button = view as? UIButton else { continue }
            let index = button.tag
            let col = index % 4
            let row = index / 4
            button.frame = CGRect(x: 10 + CGFloat(col) * (cellWidth + 6),
                                  y: gridTop + CGFloat(row) * (cellHeight + 6),
                                  width: cellWidth, height: cellHeight)
        }
    }
}

// MARK: - 文件

final class FilesContentView: BaseContentView {

    private let header = UILabel()
    private let newButton = UIButton(type: .system)
    private let scroll = UIScrollView()
    private var rows: [UIView] = []
    private var docIDs: [UUID] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.textColor = UIColor.white.withAlphaComponent(0.55)
        header.text = "文档"
        addSubview(header)

        newButton.setTitle("+ 新建", for: .normal)
        newButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        newButton.setTitleColor(.white, for: .normal)
        newButton.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        newButton.layer.cornerRadius = 6
        addSubview(newButton)

        addSubview(scroll)
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reload() {
        rows.forEach { $0.removeFromSuperview() }
        rows = []
        docIDs = []

        let docs = NotesStore.shared.sorted()
        for (index, doc) in docs.enumerated() {
            let row = UIView()
            row.backgroundColor = index % 2 == 0 ? UIColor.white.withAlphaComponent(0.03) : .clear

            let title = makeLabel(doc.title, size: 14, weight: .medium, color: .white)
            row.addSubview(title)

            let preview = makeLabel(String(doc.text.replacingOccurrences(of: "\n", with: " ").prefix(46)),
                                    size: 11, weight: .regular,
                                    color: UIColor.white.withAlphaComponent(0.4))
            row.addSubview(preview)

            let time = makeLabel(timeText(doc.updated), size: 10, weight: .regular,
                                 color: UIColor.white.withAlphaComponent(0.3))
            time.textAlignment = .right
            row.addSubview(time)

            row.tag = 900 + index
            scroll.addSubview(row)
            rows.append(row)
            docIDs.append(doc.id)
        }

        scroll.contentSize = CGSize(width: bounds.width, height: CGFloat(rows.count) * 58)
        setNeedsLayout()
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    override func activate() {
        DeckModel.shared.scrollSink = { [weak self] dy in self?.handleScroll(dy) }
    }

    override func handleTap(at point: CGPoint) {
        if newButton.frame.contains(point) {
            let doc = NotesStore.shared.create(title: "未命名")
            DeckModel.shared.open(.notes, docID: doc.id)
            reload()
            return
        }
        let local = CGPoint(x: point.x, y: point.y - 44 + scroll.contentOffset.y)
        let index = Int(local.y / 58)
        guard index >= 0, index < docIDs.count else { return }
        DeckModel.shared.open(.notes, docID: docIDs[index])
    }

    override func handleScroll(_ dy: CGFloat) {
        var offset = scroll.contentOffset
        offset.y = min(max(0, offset.y + dy), max(0, scroll.contentSize.height - scroll.bounds.height))
        scroll.contentOffset = offset
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        header.frame = CGRect(x: 16, y: 12, width: 200, height: 18)
        newButton.frame = CGRect(x: bounds.width - 74, y: 8, width: 58, height: 26)
        scroll.frame = CGRect(x: 0, y: 44, width: bounds.width, height: max(0, bounds.height - 44))

        for (index, row) in rows.enumerated() {
            row.frame = CGRect(x: 0, y: CGFloat(index) * 58, width: bounds.width, height: 58)
            let title = row.subviews.first
            let preview = row.subviews.dropFirst().first
            let time = row.subviews.last
            title?.frame = CGRect(x: 16, y: 9, width: bounds.width - 120, height: 18)
            preview?.frame = CGRect(x: 16, y: 30, width: bounds.width - 32, height: 16)
            time?.frame = CGRect(x: bounds.width - 100, y: 10, width: 84, height: 14)
        }
    }
}

// MARK: - 终端

final class TerminalContentView: BaseContentView {

    private let output = UITextView()
    private let inputLine = UILabel()
    private let prompt = UILabel()
    private var buffer = ""
    private var lines: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1)

        output.backgroundColor = .clear
        output.isEditable = false
        output.textColor = UIColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 1)
        output.font = .monospacedSystemFont(ofSize: 12.5, weight: .regular)
        output.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        addSubview(output)

        prompt.text = "pocketdeck ~ %"
        prompt.font = .monospacedSystemFont(ofSize: 12.5, weight: .semibold)
        prompt.textColor = UIColor(red: 0.39, green: 0.90, blue: 0.65, alpha: 1)
        addSubview(prompt)

        inputLine.font = .monospacedSystemFont(ofSize: 12.5, weight: .regular)
        inputLine.textColor = .white
        addSubview(inputLine)

        appendLines(["口袋电脑 PocketDesk 1.0 · 本地终端",
                     "输入 help 看命令。用手机键盘打字，回车执行。", ""])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func appendLines(_ new: [String]) {
        lines.append(contentsOf: new)
        output.text = lines.joined(separator: "\n")
        let bottom = max(0, output.contentSize.height - output.bounds.height)
        output.contentOffset = CGPoint(x: 0, y: bottom)
        // 重绘一次，确保内容高度已更新
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let y = max(0, self.output.contentSize.height - self.output.bounds.height)
            self.output.contentOffset = CGPoint(x: 0, y: y)
        }
    }

    override func activate() {
        let model = DeckModel.shared
        model.insertSink = { [weak self] text in
            guard let self else { return }
            self.buffer += text
            self.inputLine.text = self.buffer + "▎"
        }
        model.backspaceSink = { [weak self] in
            guard let self else { return }
            if !self.buffer.isEmpty { self.buffer.removeLast() }
            self.inputLine.text = self.buffer + "▎"
        }
        model.returnSink = { [weak self] in
            guard let self else { return }
            self.run(self.buffer)
            self.buffer = ""
            self.inputLine.text = ""
        }
        model.scrollSink = { [weak self] dy in self?.handleScroll(dy) }
    }

    private func run(_ raw: String) {
        let command = raw.trimmingCharacters(in: .whitespaces)
        appendLines(["pocketdeck ~ % " + command])
        guard !command.isEmpty else { return }

        let parts = command.split(separator: " ").map(String.init)
        let name = parts[0]
        let args = Array(parts.dropFirst())

        switch name {
        case "help":
            appendLines([
                "ls              列出文档",
                "cat <序号>       看文档内容",
                "new <标题>       新建文档",
                "rm <序号>        删除文档",
                "open <应用>      打开 notes/browser/files/calculator/clock",
                "date            当前时间",
                "whoami          当前用户",
                "df              存储情况",
                "clear           清屏",
                "exit            关闭终端"
            ])
        case "ls":
            let docs = NotesStore.shared.sorted()
            if docs.isEmpty { appendLines(["（没有文档）"]) }
            for (index, doc) in docs.enumerated() {
                appendLines(["\(index + 1)  \(doc.title)  (\(doc.text.count) 字)"])
            }
        case "cat":
            guard let first = args.first, let number = Int(first),
                  number >= 1, number <= NotesStore.shared.sorted().count else {
                appendLines(["用法：cat <序号>"])
                return
            }
            let doc = NotesStore.shared.sorted()[number - 1]
            appendLines([doc.title + ":"] + doc.text.components(separatedBy: "\n"))
        case "new":
            let title = args.joined(separator: " ")
            let doc = NotesStore.shared.create(title: title.isEmpty ? "未命名" : title)
            appendLines(["已创建 \(doc.title)"])
            DeckModel.shared.open(.notes, docID: doc.id)
        case "rm":
            guard let first = args.first, let number = Int(first),
                  number >= 1, number <= NotesStore.shared.sorted().count else {
                appendLines(["用法：rm <序号>"])
                return
            }
            let doc = NotesStore.shared.sorted()[number - 1]
            NotesStore.shared.remove(doc.id)
            appendLines(["已删除 \(doc.title)"])
        case "open":
            let map: [String: DeckApp] = ["notes": .notes, "browser": .browser, "files": .files,
                                          "calculator": .calculator, "clock": .clock, "terminal": .terminal]
            guard let first = args.first, let app = map[first] else {
                appendLines(["用法：open notes|browser|files|calculator|clock"])
                return
            }
            DeckModel.shared.open(app)
            appendLines(["已打开 \(app.title)"])
        case "date":
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            appendLines([formatter.string(from: Date())])
        case "whoami":
            appendLines(["pocketdesk"])
        case "df":
            appendLines(["文档 \(NotesStore.shared.docs.count) 篇",
                         "存储 UserDefaults"])
        case "clear":
            lines = []
            output.text = ""
        case "exit":
            if let id = DeckModel.shared.focusID { DeckModel.shared.close(id) }
        default:
            appendLines(["command not found: \(name)  （试试 help）"])
        }
    }

    override func handleTap(at point: CGPoint) {
        activate()
    }

    override func handleScroll(_ dy: CGFloat) {
        var offset = output.contentOffset
        offset.y = min(max(0, offset.y + dy), max(0, output.contentSize.height - output.bounds.height))
        output.contentOffset = offset
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        prompt.frame = CGRect(x: 12, y: bounds.height - 26, width: 108, height: 18)
        inputLine.frame = CGRect(x: 122, y: bounds.height - 26, width: max(0, bounds.width - 134), height: 18)
        output.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - 32))
    }
}

// MARK: - 工厂

enum DeckAppFactory {
    static func make(for window: DeckWindow) -> DeckAppContent {
        switch window.app {
        case .notes:      return NotesContentView(docID: window.docID ?? UUID())
        case .browser:    return BrowserContentView(startURL: window.url)
        case .files:      return FilesContentView()
        case .calculator: return CalculatorContentView()
        case .terminal:   return TerminalContentView()
        case .clock:      return ClockContentView()
        }
    }
}
