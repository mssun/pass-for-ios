//
//  AddPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 10/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class AddPasswordTableViewController: PasswordEditorTableViewController {
    let passwordStore = PasswordStore.shared
    var defaultDirPrefix = ""

    override func viewDidLoad() {
        tableData = [
            [[.type: PasswordEditorCellType.nameCell, .title: "name"]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "password"]],
            [[.type: PasswordEditorCellType.additionsCell, .title: "additions"]],
            [[.type: PasswordEditorCellType.scanQRCodeCell]]
        ]
        if PasswordGeneratorFlavour.from(Defaults.passwordGeneratorFlavor) == .RANDOM {
            tableData[1].append([.type: PasswordEditorCellType.passwordLengthCell, .title: "passwordlength"])
        }
        tableData[1].append([.type: PasswordEditorCellType.memorablePasswordGeneratorCell])
        tableData[0][0][PasswordEditorCellKey.content] = defaultDirPrefix
        super.viewDidLoad()
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveAddPasswordSegue" {
            // check PGP key
            guard PGPAgent.shared.isPrepared else {
                let alertTitle = "CannotAddPassword".localize()
                let alertMessage = "PgpKeyNotSet.".localize()
                Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
                return false
            }

            // check name
            guard checkName() == true else {
                return false
            }
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "saveAddPasswordSegue" {
            let (name, url) = getNameURL()
            password = Password(name: name, url: url, plainText: plainText)
        }
    }
}
