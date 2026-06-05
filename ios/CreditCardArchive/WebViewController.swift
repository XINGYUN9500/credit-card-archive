import UIKit
import WebKit

final class WebViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let bundledUrl = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www")
            ?? Bundle.main.url(forResource: "index", withExtension: "html")

        guard let url = bundledUrl else {
            webView.loadHTMLString("<h1>Missing bundled index.html</h1>", baseURL: nil)
            return
        }

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}
