import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DownloadNotificationPlugin") else {
      return
    }
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(name: "com.mkx.google_music/download_notification", binaryMessenger: messenger)
    methodChannel = channel

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any]

      switch call.method {
      case "showProgress":
        let id = args?["id"] as? String ?? "default"
        let title = args?["title"] as? String ?? "Downloading audio"
        let percent = args?["percent"] as? Int ?? 0

        let content = UNMutableNotificationContent()
        content.title = "Downloading: \(title)"
        content.body = "\(percent)% downloaded"

        let request = UNNotificationRequest(identifier: "download_\(id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
        result(true)

      case "showComplete":
        let id = args?["id"] as? String ?? "default"
        let title = args?["title"] as? String ?? "Download Complete"

        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["download_\(id)"])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["download_\(id)"])

        let content = UNMutableNotificationContent()
        content.title = "Downloaded: \(title)"
        content.body = "Saved for offline playback in Library"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "download_complete_\(id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
        result(true)

      case "cancel":
        let id = args?["id"] as? String ?? ""
        if !id.isEmpty {
          UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["download_\(id)", "download_complete_\(id)"])
          UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["download_\(id)", "download_complete_\(id)"])
        }
        result(true)

      case "cancelAll":
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        result(true)

      case "openUrl":
        if let urlStr = args?["url"] as? String, let url = URL(string: urlStr) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
          result(true)
        } else {
          result(false)
        }

      case "getPendingRoute":
        result(nil)

      case "getAppVersion":
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.5"
        result(version)

      case "stopAllAudio":
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // Allow notification banners to display even when the app is in the foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    methodChannel?.invokeMethod("openNowPlaying", arguments: nil)
    completionHandler()
  }
}
