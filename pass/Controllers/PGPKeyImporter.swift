//
//  PGPKeyImporter.swift
//  pass
//
//  Created by Danny Moesch on 07.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit

protocol PGPKeyImporter {

    static var keySource: PGPKeySource { get }

    static var label: String { get }

    static var menuLabel: String { get }

    func isReadyToUse() -> Bool

    func importKeys() throws

    func doAfterImport()

    func saveImportedKeys()
}

extension PGPKeyImporter {
    
    static var menuLabel: String {
        if Defaults.pgpKeySource == Self.keySource {
            return "✓ \(Self.label)"
        }
        return Self.label
    }
}

extension PGPKeyImporter where Self: UIViewController {

    func savePassphraseDialog() {
        let savePassphraseAlert = UIAlertController(title: "Passphrase".localize(), message: "WantToSavePassphrase?".localize(), preferredStyle: UIAlertController.Style.alert)
        // Do not save the key's passphrase.
        savePassphraseAlert.addAction(UIAlertAction(title: "No".localize(), style: UIAlertAction.Style.default) { _ in
            AppKeychain.shared.removeContent(for: Globals.pgpKeyPassphrase)
            Defaults.isRememberPGPPassphraseOn = false
            self.saveImportedKeys()
        })
        // Save the key's passphrase.
        savePassphraseAlert.addAction(UIAlertAction(title: "Yes".localize(), style: UIAlertAction.Style.destructive) {_ in
            // Ask for the passphrase.
            let alert = UIAlertController(title: "Passphrase".localize(), message: "FillInPgpPassphrase.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: {_ in
                AppKeychain.shared.add(string: alert.textFields?.first?.text, for: Globals.pgpKeyPassphrase)
                Defaults.isRememberPGPPassphraseOn = true
                self.saveImportedKeys()
            }))
            alert.addTextField { textField in
                textField.text = AppKeychain.shared.get(for: Globals.pgpKeyPassphrase)
                textField.isSecureTextEntry = true
            }
            self.present(alert, animated: true, completion: nil)
        })
        self.present(savePassphraseAlert, animated: true, completion: nil)
    }
}
