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

        guard let url = findBundledIndexHtml() else {
            webView.loadHTMLString(debugMissingPage(), baseURL: nil)
            return
        }

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func findBundledIndexHtml() -> URL? {
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www") {
            return url
        }
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            return url
        }
        guard let root = Bundle.main.resourceURL else { return nil }
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys)
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == "index.html" {
                return url
            }
        }
        return nil
    }

    private func debugMissingPage() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let files = listBundleFiles().prefix(80).map { "<li>\($0)</li>" }.joined()
        return """
        <!doctype html>
        <html><head><meta name='viewport' content='width=device-width, initial-scale=1'><style>
        body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;padding:20px;line-height:1.5;color:#14211f} code{background:#eef5f2;padding:2px 5px;border-radius:5px} li{font-size:12px;margin:3px 0;word-break:break-all}
        </style></head><body>
        <h1>Missing bundled index.html</h1>
        <p>版本 <code>\(version)</code> build <code>\(build)</code></p>
        <p>App 已经递归扫描 Bundle，但没有找到 index.html。下面是包内文件：</p>
        <ul>\(files)</ul>
        </body></html>
        """
    }

    private func listBundleFiles() -> [String] {
        guard let root = Bundle.main.resourceURL else { return ["No resourceURL"] }
        var files: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            files.append(url.path.replacingOccurrences(of: root.path, with: ""))
        }
        return files.sorted()
    }
}
