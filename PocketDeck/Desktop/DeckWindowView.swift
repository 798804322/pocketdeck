import UIKit
import WebKit

/// 外接屏上的一个窗口
final class DeckWindowView: UIView {

    let windowID: UUID
    let app: DeckApp

    private let card = UIView()
    private let titleBar = UIView()
    private let titleLabel = UILabel()
    private let contentHolder = UIView()
    private var notesView: UITextView?
    private var webView: WKWebView?
    private var clockLabel: UILabel?
    private var dateLabel: UILabel?

    init(deckWindow: DeckWindow, model: DeckModel) {
        windowID = deckWindow.id
        app = deckWindow.app
        super.init(frame: deckWindow.frame)

        card.frame = bounds
        card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.backgroundColor = UIColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 0.94)
        card.layer.borderWidth = 0.8
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        addSubview(card)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowRadius = 26
        layer.shadowOffset = CGSize(width: 0, height: 12)

        titleBar.backgroundColor = UIColor.white.withAlphaComponent(0.045)
        card.addSubview(titleBar)

        let colors: [UIColor] = [
            UIColor(red: 1.00, green: 0.37, blue: 0.34, alpha: 1),
            UIColor(red: 1.00, green: 0.74, blue: 0.18, alpha: 1),
            UIColor(red: 0.16, green: 0.78, blue: 0.25, alpha: 1)
        ]
        for (i, color) in colors.enumerated() {
            let dot = UIView(frame: CGRect(x: 14 + CGFloat(i) * 18, y: 16, width: 11, height: 11))
            dot.backgroundColor = color
            dot.layer.cornerRadius = 5.5
            dot.tag = 100 + i
            titleBar.addSubview(dot)
        }

        titleLabel.text = app.title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        titleBar.addSubview(titleLabel)

        card.addSubview(contentHolder)
        buildContent(model: model)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildContent(model: DeckModel) {
        switch app {
        case .notes:
            let tv = UITextView()
            tv.backgroundColor = .clear
            tv.textColor = UIColor(white: 0.93, alpha: 1)
            tv.font = .systemFont(ofSize: 21)
            tv.isEditable = false
            tv.textContainerInset = UIEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
            tv.text = model.notesText
            contentHolder.addSubview(tv)
            notesView = tv

        case .web:
            let config = WKWebViewConfiguration()
            let web = WKWebView(frame: .zero, configuration: config)
            web.backgroundColor = .clear
            web.isOpaque = false
            if let url = URL(string: model.webURL) {
                web.load(URLRequest(url: url))
            }
            contentHolder.addSubview(web)
            webView = web

        case .clock:
            let clock = UILabel()
            clock.font = .monospacedDigitSystemFont(ofSize: 76, weight: .thin)
            clock.textColor = .white
            clock.textAlignment = .center
            contentHolder.addSubview(clock)
            clockLabel = clock

            let date = UILabel()
            date.font = .systemFont(ofSize: 17, weight: .regular)
            date.textColor = UIColor.white.withAlphaComponent(0.55)
            date.textAlignment = .center
            contentHolder.addSubview(date)
            dateLabel = date
        }
    }

    func refresh() {
        notesView?.text = DeckModel.shared.notesText
        updateClock()
    }

    func updateClock() {
        guard app == .clock else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        clockLabel?.text = formatter.string(from: Date())

        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "M月d日 EEEE"
        dateLabel?.text = df.string(from: Date())
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        card.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 14).cgPath
        titleBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 44)
        titleLabel.frame = CGRect(x: 70, y: 0, width: bounds.width - 100, height: 44)
        contentHolder.frame = CGRect(x: 0, y: 44, width: bounds.width, height: max(0, bounds.height - 44))
        notesView?.frame = contentHolder.bounds
        webView?.frame = contentHolder.bounds

        if app == .clock {
            let h = contentHolder.bounds.height
            clockLabel?.frame = CGRect(x: 0, y: h * 0.22, width: contentHolder.bounds.width, height: 90)
            dateLabel?.frame = CGRect(x: 0, y: h * 0.22 + 100, width: contentHolder.bounds.width, height: 26)
        }
    }
}
