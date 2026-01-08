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

    @MainActor
    private func emit(_ payload: [String: Any]) {
        guard let sink = eventSink else { return }
        sink(payload)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = events

        Task.detached { [weak self] in
            guard let self else { return }

            let dataDir = FilePath.dataDirectory.path
            let cached = self.readCachedApps(dataDir: dataDir)

            // Send cached snapshot only if stream is still active
            await MainActor.run {
                self.emit([
                    "type": "snapshot",
                    "items": cached,
                    "removed": [],
                    "source": "cache",
                ])
            }

            var error: NSError?
            let jsonString = MobileLoadInstalledApps(dataDir, &error)

            guard self.eventSink != nil else { return }

            if let error {
                await MainActor.run {
                    self.emit([
                        "type": "error",
                        "items": [],
                        "removed": [],
                        "message": error.localizedDescription,
                    ])
                }
                return
            }

            if let data = jsonString.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                await MainActor.run {
                    self.emit([
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