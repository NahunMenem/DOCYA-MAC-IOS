import UIKit
import Flutter
import GoogleMaps   // 👈 OBLIGATORIO para iOS

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 👇 AGREGA TU API KEY ACA — YA FUNCIONA CON TU MISMA KEY
    GMSServices.provideAPIKey("AIzaSyB5sBLD81Hg3MRIggPhqL1a_57tjOo7vAk")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
