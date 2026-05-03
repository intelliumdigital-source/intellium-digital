import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appInfoChannelName = "sweldotrack/app_info"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "SweldoTrackAppInfoChannel"
    )

    let channel = FlutterMethodChannel(
      name: appInfoChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getAppVersion" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let info = Bundle.main.infoDictionary ?? [:]
      result([
        "versionName": info["CFBundleShortVersionString"] as? String ?? "",
        "buildNumber": info["CFBundleVersion"] as? String ?? "",
      ])
    }
  }
}
