//
//  Utils.swift
//  pass
//
//  Created by Mingshen Sun on 8/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults
import KeychainAccess

public class Utils {

    private static let keychain = Keychain(service: Globals.bundleIdentifier, accessGroup: Globals.groupIdentifier)
        .accessibility(.whenUnlockedThisDeviceOnly)
        .synchronizable(false)

    public static func getPasswordFromKeychain(name: String) -> String? {
        return try? keychain.getString(name)
    }

    public static func addPasswordToKeychain(name: String, password: String?) {
        keychain[name] = password
    }

    public static func removeKeychain(name: String) {
        try? keychain.remove(name)
    }

    public static func removeAllKeychain() {
        try? keychain.removeAll()
    }

    public static func addDataToKeychain(key: String, data: Data) {
        keychain[data: key] = data
    }

    public static func getDataFromKeychain(for key: String) -> Data? {
        return try? keychain.getData(key)
    }

    public static func copyToPasteboard(textToCopy: String?) {
        guard textToCopy != nil else {
            return
        }
        UIPasteboard.general.string = textToCopy
    }

    public static func attributedPassword(plainPassword: String) -> NSAttributedString{
        let attributedPassword = NSMutableAttributedString.init(string: plainPassword)
        // draw all digits in the password into red
        // draw all punctuation characters in the password into blue
        for (index, element) in plainPassword.unicodeScalars.enumerated() {
            var charColor = UIColor.darkText
            if NSCharacterSet.decimalDigits.contains(element) {
                charColor = Globals.digitColor
            } else if !NSCharacterSet.letters.contains(element) {
                charColor = Globals.symbolColor
            } else {
                charColor = Globals.letterColor
            }
            attributedPassword.addAttribute(NSAttributedString.Key.foregroundColor, value: charColor, range: NSRange(location: index, length: 1))
        }
        return attributedPassword
    }

    public static func alert(title: String, message: String, controller: UIViewController, handler: ((UIAlertAction) -> Void)? = nil, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: handler))
        controller.present(alert, animated: true, completion: completion)
    }
}

