// Basis of this code comes from https://github.com/lubritto/flutter_share

import Flutter
import UIKit
    
public class Share {
    public static func share(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any?]

        let title = args!["title"] as? String
        let text = args!["text"] as? String
        let filename = args!["filename"] as? String
        let tmpDirURL = FileManager.default.temporaryDirectory
        
        if (filename == nil || filename!.isEmpty) {
            return result(false)
        }

        let tmpFile = tmpDirURL.appendingPathComponent(filename!)
        do {
            try text?.write(to: tmpFile, atomically: true, encoding: .utf8)
        } catch {
            //TODO: return error
            return result(false)
        }
        
        pop(title: title, file: tmpFile) { pass in
            let fm = FileManager()
            do {
                try fm.removeItem(at: tmpFile)
            } catch {}
            
            return result(pass)
        }
    }

    public static func shareFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any?]

        let title = args!["title"] as? String
        let filePath = args!["filePath"] as? String
        let filename = args!["filename"] as? String

        if (filePath == nil || filePath!.isEmpty) {
            return result(false)
        }
        
        var tmpFile: URL?
        let fm = FileManager()
        var realPath = URL(fileURLWithPath: filePath!)
        
        if (filename != nil && !filename!.isEmpty) {
            tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename!)
            
            do {
                try fm.linkItem(at: URL(fileURLWithPath: filePath!), to: tmpFile!)
            } catch {
                //TODO: return error
                return result(false)
            }
            
            realPath = tmpFile!
        }

        pop(title: title, file: realPath) { pass in
            if (tmpFile != nil) {
                do {
                    try fm.removeItem(at: tmpFile!)
                } catch {}
            }
            result(pass)
        }
    }
    
    private static func pop(title: String?, file: URL, completion: @escaping ((Bool) -> Void)) {
        if (title == nil || title!.isEmpty) {
            return completion(false)
        }
        
        let activityViewController = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        
        activityViewController.completionWithItemsHandler = {(activityType: UIActivity.ActivityType?, completed: Bool, returnedItems: [Any]?, error: Error?) in
            completion(true)
        }
                
        // Subject
        activityViewController.setValue(title, forKeyPath: "subject")

        // For iPads, fix issue where Exception is thrown by using a popup instead
        if UIDevice.current.userInterfaceIdiom == .pad {
          activityViewController.popoverPresentationController?.sourceView = UIApplication.topViewController()?.view
          if let view = UIApplication.topViewController()?.view {
              activityViewController.popoverPresentationController?.permittedArrowDirections = []
              activityViewController.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
          }
        }

        DispatchQueue.main.async {
          UIApplication.topViewController()?.present(activityViewController, animated: true)
        }
    }
}

extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}
