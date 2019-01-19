//
//  AdvancedSettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 7/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD
import passKit

class AdvancedSettingsTableViewController: UITableViewController {

    @IBOutlet weak var encryptInASCIIArmoredTableViewCell: UITableViewCell!
    @IBOutlet weak var gitSignatureTableViewCell: UITableViewCell!
    @IBOutlet weak var eraseDataTableViewCell: UITableViewCell!
    @IBOutlet weak var discardChangesTableViewCell: UITableViewCell!
    let passwordStore = PasswordStore.shared

    let encryptInASCIIArmoredSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(encryptInASCIIArmoredAction(_:)), for: UIControlEvents.valueChanged)
        return uiSwitch
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        encryptInASCIIArmoredSwitch.isOn = SharedDefaults[.encryptInArmored]
        encryptInASCIIArmoredTableViewCell.accessoryView = encryptInASCIIArmoredSwitch
        encryptInASCIIArmoredTableViewCell.selectionStyle = .none
        setGitSignatureText()
    }

    private func setGitSignatureText() {
        let gitSignatureName = passwordStore.gitSignatureForNow.name!
        let gitSignatureEmail = passwordStore.gitSignatureForNow.email!
        self.gitSignatureTableViewCell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14)
        self.gitSignatureTableViewCell.detailTextLabel?.text = "\(gitSignatureName) <\(gitSignatureEmail)>"
        if SharedDefaults[.gitSignatureName] == nil && SharedDefaults[.gitSignatureEmail] == nil {
            self.gitSignatureTableViewCell.detailTextLabel?.font = UIFont.systemFont(ofSize: 17)
            gitSignatureTableViewCell.detailTextLabel?.text = "NotSet".localize()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView.cellForRow(at: indexPath) == eraseDataTableViewCell {
            let alert = UIAlertController(title: "ErasePasswordStoreData?".localize(), message: "EraseExplanation.".localize(), preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "ErasePasswordStoreData".localize(), style: UIAlertActionStyle.destructive, handler: {[unowned self] (action) -> Void in
                SVProgressHUD.show(withStatus: "Erasing...".localize())
                self.passwordStore.erase()
                self.navigationController!.popViewController(animated: true)
                SVProgressHUD.showSuccess(withStatus: "Done".localize())
                SVProgressHUD.dismiss(withDelay: 1)
            }))
            alert.addAction(UIAlertAction(title: "Dismiss".localize(), style: UIAlertActionStyle.cancel, handler:nil))
            self.present(alert, animated: true, completion: nil)
        } else if tableView.cellForRow(at: indexPath) == discardChangesTableViewCell {
            let alert = UIAlertController(title: "DiscardAllLocalChanges?".localize(), message: "DiscardExplanation.".localize(), preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "DiscardAllLocalChanges".localize(), style: UIAlertActionStyle.destructive, handler: {[unowned self] (action) -> Void in
                SVProgressHUD.show(withStatus: "Resetting...".localize())
                do {
                    let numberDiscarded = try self.passwordStore.reset()
                    self.navigationController!.popViewController(animated: true)
                    SVProgressHUD.showSuccess(withStatus: "DiscardedCommits(%d)".localize(numberDiscarded))
                    SVProgressHUD.dismiss(withDelay: 1)
                } catch {
                    Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
                }

            }))
            alert.addAction(UIAlertAction(title: "Dismiss".localize(), style: UIAlertActionStyle.cancel, handler:nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    @objc func encryptInASCIIArmoredAction(_ sender: Any?) {
        SharedDefaults[.encryptInArmored] = encryptInASCIIArmoredSwitch.isOn
    }

    @IBAction func saveGitConfigSetting(segue: UIStoryboardSegue) {
        if let controller = segue.source as? GitConfigSettingTableViewController {
            if let gitSignatureName = controller.nameTextField.text,
                let gitSignatureEmail = controller.emailTextField.text {
                SharedDefaults[.gitSignatureName] = gitSignatureName.isEmpty ? nil : gitSignatureName
                SharedDefaults[.gitSignatureEmail] = gitSignatureEmail.isEmpty ? nil : gitSignatureEmail
            }
            setGitSignatureText()
        }
    }

}
