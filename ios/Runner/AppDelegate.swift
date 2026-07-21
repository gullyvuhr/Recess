import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var previewPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BellPreview") else {
      return
    }
    FlutterMethodChannel(
      name: "recess/bell_preview",
      binaryMessenger: registrar.messenger()
    ).setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      self.stopPreview()
      guard call.method == "play", let assetPath = call.arguments as? String else {
        result(nil)
        return
      }
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
        let assetKey = FlutterDartProject.lookupKey(forAsset: assetPath)
        guard let url = Bundle.main.url(forResource: assetKey, withExtension: nil) else {
          result(nil)
          return
        }
        self.previewPlayer = try AVAudioPlayer(contentsOf: url)
        self.previewPlayer?.prepareToPlay()
        self.previewPlayer?.play()
      } catch {
        self.stopPreview()
      }
      result(nil)
    }
  }

  private func stopPreview() {
    previewPlayer?.stop()
    previewPlayer = nil
  }
}
