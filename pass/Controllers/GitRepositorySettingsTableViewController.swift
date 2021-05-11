//
//  GitRepositorySettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD
import UIKit

class GitRepositorySettingsTableViewController: UITableViewController, PasswordAlertPresenter {
    // MARK: - View Outlet

    @IBOutlet var gitURLTextField: UITextField!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var branchNameTextField: UITextField!
    @IBOutlet var authSSHKeyCell: UITableViewCell!
    @IBOutlet var authPasswordCell: UITableViewCell!
    @IBOutlet var gitURLCell: UITableViewCell!

    // MARK: - Properties

    private var sshLabel: UILabel?
    private let passwordStore = PasswordStore.shared
    private let keychain = AppKeychain.shared
    private var gitCredential: GitCredential {
        GitCredential.from(
            authenticationMethod: Defaults.gitAuthenticationMethod,
            userName: Defaults.gitUsername,
            keyStore: keychain
        )
    }

    private var gitAuthenticationMethod: GitAuthenticationMethod {
        get { Defaults.gitAuthenticationMethod }
        set {
            Defaults.gitAuthenticationMethod = newValue
            updateAuthenticationMethodCheckView(for: newValue)
        }
    }

    private var gitUrl: URL {
        get { Defaults.gitURL }
        set { Defaults.gitURL = newValue }
    }

    private var gitBranchName: String {
        get { Defaults.gitBranchName }
        set { Defaults.gitBranchName = newValue }
    }

    private var gitUsername: String {
        get { Defaults.gitUsername }
        set { Defaults.gitUsername = newValue }
    }

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        gitURLTextField.text = gitUrl.absoluteString
        usernameTextField.text = gitUsername
        branchNameTextField.text = gitBranchName
        sshLabel = authSSHKeyCell.subviews[0].subviews[0] as? UILabel
        authSSHKeyCell.accessoryType = .detailButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Grey out ssh option if ssh_key is not present.
        sshLabel?.isEnabled = keychain.contains(key: SshKey.PRIVATE.getKeychainKey())
        updateAuthenticationMethodCheckView(for: gitAuthenticationMethod)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    // MARK: - UITableViewController Override

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authSSHKeyCell {
            showSSHKeyActionSheet()
        } else if cell == gitURLCell {
            showGitURLFormatHelp()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authPasswordCell {
            gitAuthenticationMethod = .password
        } else if cell == authSSHKeyCell {
            if !keychain.contains(key: SshKey.PRIVATE.getKeychainKey()) {
                Utils.alert(title: "CannotSelectSshKey".localize(), message: "PleaseSetupSshKeyFirst.".localize(), controller: self)
                gitAuthenticationMethod = .password
            } else {
                gitAuthenticationMethod = .key
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    // MARK: - Segue Handlers

    @IBAction
    private func save(_: Any) {
        guard let gitURLTextFieldText = gitURLTextField.text, let gitURL = URL(string: gitURLTextFieldText.trimmed) else {
            Utils.alert(title: "CannotSave".localize(), message: "SetGitRepositoryUrl".localize(), controller: self)
            return
        }

        guard let branchName = branchNameTextField.text, !branchName.trimmed.isEmpty else {
            Utils.alert(title: "CannotSave".localize(), message: "SpecifyBranchName.".localize(), controller: self)
            return
        }

        if let scheme = gitURL.scheme {
            switch scheme {
            case "http", "https", "ssh":
                if gitURL.user == nil, usernameTextField.text == nil {
                    Utils.alert(title: "CannotSave".localize(), message: "CannotFindUsername.".localize(), controller: self)
                    return
                }
                if let urlUsername = gitURL.user, let textFieldUsername = usernameTextField.text, urlUsername != textFieldUsername.trimmed {
                    Utils.alert(title: "CannotSave".localize(), message: "CheckEnteredUsername.".localize(), controller: self)
                    return
                }
            case "file":
                break
            default:
                Utils.alert(title: "CannotSave".localize(), message: "Protocol is not supported", controller: self)
                return
            }
        }

        gitUrl = gitURL
        gitBranchName = branchName.trimmed
        gitUsername = (gitURL.user ?? usernameTextField.text ?? "git").trimmed

        if passwordStore.repositoryExists() {
            let overwriteAlert: UIAlertController = {
                let alert = UIAlertController(title: "Overwrite?".localize(), message: "OperationWillOverwriteData.".localize(), preferredStyle: .alert)
                alert.addAction(
                    UIAlertAction(title: "Overwrite".localize(), style: .destructive) { _ in
                        self.cloneAndSegueIfSuccess()
                    }
                )
                alert.addAction(UIAlertAction.cancel())
                return alert
            }()
            present(overwriteAlert, animated: true)
        } else {
            cloneAndSegueIfSuccess()
        }
    }

    private func cloneAndSegueIfSuccess() {
        // Remember git credential password/passphrase temporarily, ask whether users want this after a successful clone.
        Defaults.isRememberGitCredentialPassphraseOn = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let transferProgressBlock: (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void = { git_transfer_progress, _ in
                    let gitTransferProgress = git_transfer_progress.pointee
                    let progress = Float(gitTransferProgress.received_objects) / Float(gitTransferProgress.total_objects)
                    SVProgressHUD.showProgress(progress, status: "Cloning Remote Repository")
                }

                let checkoutProgressBlock: (String, UInt, UInt) -> Void = { _, completedSteps, totalSteps in
                    let progress = Float(completedSteps) / Float(totalSteps)
                    SVProgressHUD.showProgress(progress, status: "CheckingOutBranch".localize(self.gitBranchName))
                }

                let options = self.gitCredential.getCredentialOptions(passwordProvider: self.present)

                try self.passwordStore.cloneRepository(
                    remoteRepoURL: self.gitUrl,
                    branchName: self.gitBranchName,
                    options: options,
                    transferProgressBlock: transferProgressBlock,
                    checkoutProgressBlock: checkoutProgressBlock
                )

                SVProgressHUD.dismiss {
                    let savePassphraseAlert: UIAlertController = {
                        let alert = UIAlertController(title: "Done".localize(), message: "WantToSaveGitCredential?".localize(), preferredStyle: .alert)
                        alert.addAction(
                            UIAlertAction(title: "No".localize(), style: .default) { _ in
                                Defaults.isRememberGitCredentialPassphraseOn = false
                                self.passwordStore.gitPassword = nil
                                self.passwordStore.gitSSHPrivateKeyPassphrase = nil
                                self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
                            }
                        )
                        alert.addAction(
                            UIAlertAction(title: "Yes".localize(), style: .destructive) { _ in
                                Defaults.isRememberGitCredentialPassphraseOn = true
                                self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
                            }
                        )
                        return alert
                    }()
                    DispatchQueue.main.async {
                        self.present(savePassphraseAlert, animated: true)
                    }
                }
            } catch {
                SVProgressHUD.dismiss {
                    let error = error as NSError
                    var message = error.localizedDescription
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        message = "\(message)\n\("UnderlyingError".localize(underlyingError.localizedDescription))"
                    }
                    DispatchQueue.main.async {
                        Utils.alert(title: "Error".localize(), message: message, controller: self)
                    }
                }
            }
        }
    }

    @IBAction
    private func importSSHKey(segue: UIStoryboardSegue) {
        guard let sourceController = segue.source as? KeyImporter, sourceController.isReadyToUse() else {
            return
        }
        importSSHKey(using: sourceController)
    }

    private func importSSHKey(using keyImporter: KeyImporter) {
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                try keyImporter.importKeys()
                DispatchQueue.main.async {
                    SVProgressHUD.showSuccess(withStatus: "Imported".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                    Defaults.gitSSHKeySource = type(of: keyImporter).keySource
                    self.gitAuthenticationMethod = .key
                    self.sshLabel?.isEnabled = true
                }
            } catch {
                Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self)
            }
        }
    }

    // MARK: - Helper Functions

    private func showSSHKeyActionSheet() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        optionMenu.addAction(
            UIAlertAction(title: SSHKeyUrlImportTableViewController.menuLabel, style: .default) { _ in
                self.performSegue(withIdentifier: "setGitSSHKeyByURLSegue", sender: self)
            }
        )
        optionMenu.addAction(
            UIAlertAction(title: SSHKeyArmorImportTableViewController.menuLabel, style: .default) { _ in
                self.performSegue(withIdentifier: "setGitSSHKeyByArmorSegue", sender: self)
            }
        )
        optionMenu.addAction(
            UIAlertAction(title: SSHKeyFileImportTableViewController.menuLabel, style: .default) { _ in
                self.performSegue(withIdentifier: "setGitSSHKeyByFileSegue", sender: self)
            }
        )

        if isReadyToUse() {
            optionMenu.addAction(
                UIAlertAction(title: "\(Self.menuLabel) (\("Import".localize()))", style: .default) { _ in
                    self.importSSHKey(using: self)
                }
            )
        } else {
            optionMenu.addAction(
                UIAlertAction(title: "\(Self.menuLabel) (\("Tips".localize()))", style: .default) { _ in
                    let title = "Tips".localize()
                    let message = "SshCopyPrivateKeyToPass.".localize()
                    Utils.alert(title: title, message: message, controller: self)
                }
            )
        }

        if Defaults.gitSSHKeySource != nil {
            optionMenu.addAction(
                UIAlertAction(title: "RemoveSShKeys".localize(), style: .destructive) { _ in
                    self.passwordStore.removeGitSSHKeys()
                    Defaults.gitSSHKeySource = nil
                    self.sshLabel?.isEnabled = false
                    self.gitAuthenticationMethod = .password
                }
            )
        }
        optionMenu.addAction(UIAlertAction.cancel())
        optionMenu.popoverPresentationController?.sourceView = authSSHKeyCell
        optionMenu.popoverPresentationController?.sourceRect = authSSHKeyCell.bounds
        present(optionMenu, animated: true)
    }

    private func updateAuthenticationMethodCheckView(for method: GitAuthenticationMethod) {
        let passwordCheckView = authPasswordCell.viewWithTag(1001)
        let sshKeyCheckView = authSSHKeyCell.viewWithTag(1001)

        switch method {
        case .password:
            passwordCheckView?.isHidden = false
            sshKeyCheckView?.isHidden = true
        case .key:
            passwordCheckView?.isHidden = true
            sshKeyCheckView?.isHidden = false
        }
    }

    private func showGitURLFormatHelp() {
        let message = """
        https://example.com[:port]/project.git
        ssh://[user@]server[:port]/project.git
        [user@]server:project.git (no scheme)
        """
        Utils.alert(title: "Git URL Format", message: message, controller: self)
    }
}

extension GitRepositorySettingsTableViewController: KeyImporter {
    static let keySource = KeySource.itunes
    static let label = "ITunesFileSharing".localize()

    func isReadyToUse() -> Bool {
        KeyFileManager.PrivateSsh.doesKeyFileExist()
    }

    func importKeys() throws {
        try KeyFileManager.PrivateSsh.importKeyFromFileSharing()
    }
}
