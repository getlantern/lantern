import FlutterMacOS
import Foundation
import Liblantern

final class AppStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    private func readCachedApps(dataDir: String) -> [[String: Any]] {
        let cachePath = (dataDir as NSString).appendingPathComponent("apps_cache.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cachePath)),
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }
        return arr
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = events

        Task.detached { [weak self] in
            let dataDir = FilePath.dataDirectory.path

            // 1) Emit cached immediately (fast)
            let cached = self?.readCachedApps(dataDir: dataDir) ?? []
            await MainActor.run {
                events([
                    "type": "snapshot",
                    "items": cached,
                    "removed": [],
                    "source": "cache",
                ])
            }

            // 2) Run the full Go scan (slower), then emit updated snapshot
            var error: NSError?
            let jsonString = MobileLoadInstalledApps(dataDir, &error)

            guard let self, self.eventSink != nil else { return }

            if let error {
                await MainActor.run {
                    events([
                        "type": "error",
                        "items": [],
                        "removed": [],
                        "message": error.localizedDescription,
                    ])
                }
                return
            }

            if let data = jsonString.data(using: .utf8),
                let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            {
                await MainActor.run {
                    events([
                        "type": "snapshot",
                        "items": arr,
                        "removed": [],
                        "source": "scan",
                    ])
                }
            }
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
