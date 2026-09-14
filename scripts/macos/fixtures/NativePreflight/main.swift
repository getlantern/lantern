import AppKit
import Darwin
import Foundation

let bundle = Bundle.main
let applications = URL(
  fileURLWithPath: bundle.object(forInfoDictionaryKey: "FixtureApplications") as! String)
let marker = URL(fileURLWithPath: bundle.object(forInfoDictionaryKey: "FixtureMarker") as! String)
let action = bundle.object(forInfoDictionaryKey: "FixtureAction") as! String
// Set quarantine after launch: this fixture has no notarization ticket.
if action == "quarantine" {
  let value = Array("0083;00000000;Fixture;".utf8)
  let result = value.withUnsafeBytes { bytes in
    bundle.bundleURL.withUnsafeFileSystemRepresentation { path in
      setxattr(path!, "com.apple.quarantine", bytes.baseAddress, bytes.count, 0, 0)
    }
  }
  guard result == 0 else { exit(96) }
}
let strings = InstallationStrings(bundle: bundle)
if strings.text("quit") == "quit" { exit(94) }
if action == "cancel" && strings.text("quit") != "Quitter" {
  print("locales:", bundle.localizations, "preferred:", bundle.preferredLocalizations)
  print("languages:", Locale.preferredLanguages, "quit:", strings.text("quit"))
  exit(95)
}
let installation = AppInstallation(bundleURL: bundle.bundleURL, applicationsURL: applications)

// A watchdog also covers a stuck modal loop or Launch Services request.
DispatchQueue.global().asyncAfter(deadline: .now() + 20) { exit(90) }
if !installation.isInstalled {
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    guard let window = NSApplication.shared.modalWindow else { exit(91) }
    func buttons(_ view: NSView) -> [NSButton] {
      (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
    }
    let titles = buttons(window.contentView!).map(\.title)
    guard titles.contains(strings.text("quit")),
      titles.contains(strings.text("macos_installation_show_applications"))
    else { exit(92) }
    let offersMove = titles.contains(strings.text("macos_installation_move_relaunch"))
    guard offersMove == (action == "install" || action == "cancel") else { exit(93) }
    NSApplication.shared.stopModal(
      withCode: action == "install" ? .alertFirstButtonReturn : .abort)
  }
}
if AppInstallationPreflight.run(
  installation: installation, appName: "Lantern Preflight Fixture", strings: strings)
{
  try installation.bundleURL.resolvingSymlinksInPath().path.write(
    to: marker, atomically: true, encoding: .utf8)
}
