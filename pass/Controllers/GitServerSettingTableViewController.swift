//
//  GitServerSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD
import passKit

class GitServerSettingTableViewController: UITableViewController {

    @IBOutlet weak var gitURLTextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var branchNameTextField: UITextField!
    @IBOutlet weak var authSSHKeyCell: UITableViewCell!
    @IBOutlet weak var authPasswordCell: UITableViewCell!
    let passwordStore = PasswordStore.shared
    var sshLabel: UILabel? = nil

    var authenticationMethod = SharedDefaults[.gitAuthenticationMethod] ?? "Password"

    private func checkAuthenticationMethod(method: String) {
        let passwordCheckView = authPasswordCell.viewWithTag(1001)!
        let sshKeyCheckView = authSSHKeyCell.viewWithTag(1001)!

        switch method {
        case "Password":
            passwordCheckView.isHidden = false
            sshKeyCheckView.isHidden = true
        case "SSH Key":
            passwordCheckView.isHidden = true
            sshKeyCheckView.isHidden = false
        default:
            passwordCheckView.isHidden = false
            sshKeyCheckView.isHidden = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Grey out ssh option if ssh_key is not present
        if let sshLabel = sshLabel {
            sshLabel.isEnabled = passwordStore.gitSSHKeyExists()
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = SharedDefaults[.gitURL] {
            gitURLTextField.text = url.absoluteString
        }
        usernameTextField.text = SharedDefaults[.gitUsername]
        branchNameTextField.text = SharedDefaults[.gitBranchName]
        sshLabel = authSSHKeyCell.subviews[0].subviews[0] as? UILabel
        checkAuthenticationMethod(method: authenticationMethod)
        authSSHKeyCell.accessoryType = .detailButton
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authSSHKeyCell {
            showSSHKeyActionSheet()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    private func cloneAndSegueIfSuccess() {
        // try to clone
        let gitRepostiroyURL = gitURLTextField.text!.trimmed
        let username = usernameTextField.text!
        let branchName = branchNameTextField.text!
        let auth = authenticationMethod

        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "Prepare Repository")
        var gitCredential: GitCredential
        if auth == "Password" {
            gitCredential = GitCredential(credential: GitCredential.Credential.http(userName: username))
        } else {
            gitCredential = GitCredential(
                credential: GitCredential.Credential.ssh(
                    userName: username,
                    privateKeyFile: Globals.gitSSHPrivateKeyURL
                )
            )
        }
        // Remember git credential password/passphrase temporarily, ask whether users want this after a successful clone.
        SharedDefaults[.isRememberGitCredentialPassphraseOn] = true
        let dispatchQueue = DispatchQueue.global(qos: .userInitiated)
        dispatchQueue.async {
            do {
                try self.passwordStore.cloneRepository(remoteRepoURL: URL(string: gitRepostiroyURL)!,
                                                       credential: gitCredential,
                                                       branchName: branchName,
                                                       requestGitPassword: self.requestGitPassword,
                                                       transferProgressBlock: { (git_transfer_progress, stop) in
                                                        DispatchQueue.main.async {
                                                            SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects)/Float(git_transfer_progress.pointee.total_objects), status: "Clone Remote Repository")
                                                        }
                },
                                                       checkoutProgressBlock: { (path, completedSteps, totalSteps) in
                                                        DispatchQueue.main.async {
                                                            SVProgressHUD.showProgress(Float(completedSteps)/Float(totalSteps), status: "Checkout Master Branch")
                                                        }
                })
                DispatchQueue.main.async {
                    SharedDefaults[.gitURL] = URL(string: gitRepostiroyURL)
                    SharedDefaults[.gitUsername] = username
                    SharedDefaults[.gitBranchName] = branchName
                    SharedDefaults[.gitAuthenticationMethod] = auth
                    SVProgressHUD.dismiss()
                    let savePassphraseAlert = UIAlertController(title: "Done", message: "Do you want to save the Git credential password/passphrase?", preferredStyle: UIAlertControllerStyle.alert)
                    // no
                    savePassphraseAlert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.default) { _ in
                        SharedDefaults[.isRememberGitCredentialPassphraseOn] = false
                        self.passwordStore.gitPassword = nil
                        self.passwordStore.gitSSHPrivateKeyPassphrase = nil
                        self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
                    })
                    // yes
                    savePassphraseAlert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.destructive) {_ in
                        SharedDefaults[.isRememberGitCredentialPassphraseOn] = true
                        self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
                    })
                    self.present(savePassphraseAlert, animated: true, completion: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    let error = error as NSError
                    var message = error.localizedDescription
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        message = "\(message)\nUnderlying error: \(underlyingError.localizedDescription)"
                    }
                    Utils.alert(title: "Error", message: message, controller: self, completion: nil)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authPasswordCell {
            authenticationMethod = "Password"
        } else if cell == authSSHKeyCell {

            if !passwordStore.gitSSHKeyExists() {
                Utils.alert(title: "Cannot Select SSH Key", message: "Please setup SSH key first.", controller: self, completion: nil)
                authenticationMethod = "Password"
            } else {
                authenticationMethod = "SSH Key"
            }
        }
        checkAuthenticationMethod(method: authenticationMethod)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction func save(_ sender: Any) {

        // some sanity checks
        guard let gitURL = URL(string: gitURLTextField.text!) else {
            Utils.alert(title: "Cannot Save", message: "Please set the Git repository URL.", controller: self, completion: nil)
            return
        }

        switch gitURL.scheme {
        case let val where val == "https":
            break
        case let val where val == "ssh":
            guard let sshUsername = gitURL.user, sshUsername.isEmpty == false else {
                Utils.alert(title: "Cannot Save", message: "Cannot find the username in the Git repository URL. Example URL: ssh://git@server/path/to/repo.git.", controller: self, completion: nil)
                return
            }
            guard let username = usernameTextField.text, username == sshUsername else {
                Utils.alert(title: "Cannot Save", message: "Please check the entered username and the username in the Git repository URL. They should match.", controller: self, completion: nil)
                return
            }
        case let val where val == "http":
            Utils.alert(title: "Cannot Save", message: "Please use https instead of http.", controller: self, completion: nil)
            return
        default:
            Utils.alert(title: "Cannot Save", message: "Please specify the scheme of the Git repository URL (https or ssh).", controller: self, completion: nil)
            return
        }

        if passwordStore.repositoryExisted() {
            let alert = UIAlertController(title: "Overwrite?", message: "This operation will overwrite your current password store data (repository). Data on your remote server will not be affected.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Overwrite", style: UIAlertActionStyle.destructive, handler: { _ in
                // perform segue only after a successful clone
                self.cloneAndSegueIfSuccess()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            // perform segue only after a successful clone
            cloneAndSegueIfSuccess()
        }
    }

    func showSSHKeyActionSheet() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var urlActionTitle = "Download from URL"
        var armorActionTitle = "ASCII-Armor Encrypted Key"
        var fileActionTitle = "iTunes File Sharing"

        if SharedDefaults[.gitSSHKeySource] == "url" {
            urlActionTitle = "✓ \(urlActionTitle)"
        } else if SharedDefaults[.gitSSHKeySource] == "armor" {
            armorActionTitle = "✓ \(armorActionTitle)"
        } else if SharedDefaults[.gitSSHKeySource] == "file" {
            fileActionTitle = "✓ \(fileActionTitle)"
        }
        let urlAction = UIAlertAction(title: urlActionTitle, style: .default) { _ in
            self.performSegue(withIdentifier: "setGitSSHKeyByURLSegue", sender: self)
        }
        let armorAction = UIAlertAction(title: armorActionTitle, style: .default) { _ in
            self.performSegue(withIdentifier: "setGitSSHKeyByArmorSegue", sender: self)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        optionMenu.addAction(urlAction)
        optionMenu.addAction(armorAction)

        if passwordStore.gitSSHKeyExists(inFileSharing: true) {
            // might keys updated via iTunes, or downloaded/pasted inside the app
            fileActionTitle.append(" (Import)")
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                do {
                    try self.passwordStore.gitSSHKeyImportFromFileSharing()
                    SharedDefaults[.gitSSHKeySource] = "file"
                    SVProgressHUD.showSuccess(withStatus: "Imported")
                    SVProgressHUD.dismiss(withDelay: 1)
                } catch {
                    Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                }
            }
            optionMenu.addAction(fileAction)
        } else {
            fileActionTitle.append(" (Tips)")
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                let title = "Tips"
                let message = "Copy your ASCII-armored private key to Pass with the name \"ssh_key\" (without quotes) via iTunes. Then come back and click \"iTunes File Sharing\" to finish."
                Utils.alert(title: title, message: message, controller: self)
            }
            optionMenu.addAction(fileAction)
        }

        if SharedDefaults[.gitSSHKeySource] != nil {
            let deleteAction = UIAlertAction(title: "Remove Git SSH Keys", style: .destructive) { _ in
                self.passwordStore.removeGitSSHKeys()
                SharedDefaults[.gitSSHKeySource] = nil
                if let sshLabel = self.sshLabel {
                    sshLabel.isEnabled = false
                    self.checkAuthenticationMethod(method: "Password")
                }
            }
            optionMenu.addAction(deleteAction)
        }
        optionMenu.addAction(cancelAction)
        optionMenu.popoverPresentationController?.sourceView = authSSHKeyCell
        optionMenu.popoverPresentationController?.sourceRect = authSSHKeyCell.bounds
        self.present(optionMenu, animated: true, completion: nil)
    }

    private func requestGitPassword(credential: GitCredential.Credential, lastPassword: String?) -> String? {
        let sem = DispatchSemaphore(value: 0)
        var password: String?
        var message = ""
        switch credential {
        case .http:
            message = "Please fill in the password of your Git account."
        case .ssh:
            message = "Please fill in the passphrase of your SSH key."
        }

        DispatchQueue.main.async {
            SVProgressHUD.dismiss()
            let alert = UIAlertController(title: "Password", message: message, preferredStyle: UIAlertControllerStyle.alert)
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = lastPassword ?? ""
                textField.isSecureTextEntry = true
            })
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                password = alert.textFields!.first!.text
                sem.signal()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                password = nil
                sem.signal()
            })
            self.present(alert, animated: true, completion: nil)
        }

        let _ = sem.wait(timeout: .distantFuture)
        return password
    }
}
