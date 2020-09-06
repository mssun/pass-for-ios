//
//  UIAlertActionExtension.swift
//  passKit
//
//  Created by Sun, Mingshen on 4/17/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import Foundation
import UIKit

extension UIAlertAction {
    public static func cancelAndPopView(controller: UIViewController) -> UIAlertAction {
        cancel { _ in
            controller.navigationController?.popViewController(animated: true)
        }
    }

    public static func cancel(title: String = "Cancel".localize(), handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        UIAlertAction(title: title, style: .cancel, handler: handler)
    }

    public static func dismiss(handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        cancel(title: "Dismiss".localize(), handler: handler)
    }

    public static func ok(handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        UIAlertAction(title: "Ok".localize(), style: .default, handler: handler)
    }

    public static func okAndPopView(controller: UIViewController) -> UIAlertAction {
        ok { _ in
            controller.navigationController?.popViewController(animated: true)
        }
    }

    public static func selectKey(controller: UIViewController, handler: ((UIAlertAction) -> Void)?) -> UIAlertAction {
        UIAlertAction(title: "Select Key", style: .default) { _ in
            let selectKeyAlert = UIAlertController(title: "Select from imported keys", message: nil, preferredStyle: .actionSheet)
            try? PGPAgent.shared.getShortKeyID().forEach { k in
                let action = UIAlertAction(title: k, style: .default, handler: handler)
                selectKeyAlert.addAction(action)
            }
            selectKeyAlert.addAction(UIAlertAction.cancelAndPopView(controller: controller))
            controller.present(selectKeyAlert, animated: true, completion: nil)
        }
    }
}
