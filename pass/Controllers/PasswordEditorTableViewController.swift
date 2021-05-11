//
//  PasswordEditorTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import OneTimePassword
import passKit
import SafariServices
import UIKit

enum PasswordEditorCellType: Equatable {
    case nameCell
    case fillPasswordCell
    case passwordLengthCell
    case passwordUseDigitsCell
    case passwordVaryCasesCell
    case passwordUseSpecialSymbols
    case passwordGroupsCell
    case additionsCell
    case deletePasswordCell
    case scanQRCodeCell
    case passwordFlavorCell
}

enum PasswordEditorCellKey {
    case type, title, content, placeholders
}

protocol PasswordSettingSliderTableViewCellDelegate: AnyObject {
    func generateAndCopyPassword()
}

class PasswordEditorTableViewController: UITableViewController {
    var tableData = [[[PasswordEditorCellKey: Any]]]()
    var password: Password?

    private var navigationItemTitle: String?

    private var sectionHeaderTitles = ["Name".localize(), "Password".localize(), "Additions".localize(), ""].map { $0.uppercased() }
    private var sectionFooterTitles = ["", "", "UseKeyValueFormat.".localize(), ""]
    private let nameSection = 0
    private let passwordSection = 1
    private let additionsSection = 2
    private var hidePasswordSettings = true

    private var passwordGenerator: PasswordGenerator = Defaults.passwordGenerator

    var nameCell: TextFieldTableViewCell?
    var fillPasswordCell: FillPasswordTableViewCell?
    var additionsCell: TextViewTableViewCell?
    private var deletePasswordCell: UITableViewCell?
    private var scanQRCodeCell: UITableViewCell?
    private var passwordFlavorCell: UITableViewCell?

    var plainText: String {
        var plainText = (fillPasswordCell?.getContent())!
        if let additionsString = additionsCell?.getContent(), !additionsString.isEmpty {
            plainText.append("\n")
            plainText.append(additionsString)
        }
        if !plainText.trimmingCharacters(in: .whitespaces).hasSuffix("\n") {
            plainText.append("\n")
        }
        return plainText
    }

    override func loadView() {
        super.loadView()

        deletePasswordCell = UITableViewCell(style: .default, reuseIdentifier: "default")
        deletePasswordCell!.textLabel?.text = "DeletePassword".localize()
        deletePasswordCell!.textLabel?.textColor = Colors.systemRed
        deletePasswordCell?.selectionStyle = .default

        scanQRCodeCell = UITableViewCell(style: .default, reuseIdentifier: "default")
        scanQRCodeCell?.textLabel?.text = "AddOneTimePassword".localize()
        scanQRCodeCell?.selectionStyle = .default
        scanQRCodeCell?.accessoryType = .disclosureIndicator

        passwordFlavorCell = UITableViewCell(style: .default, reuseIdentifier: "default")
        passwordFlavorCell?.textLabel?.text = "PasswordGeneratorFlavor".localize()
        passwordFlavorCell?.selectionStyle = .none

        let passwordFlavorSelector = UISegmentedControl(items: PasswordGeneratorFlavor.allCases.map(\.localized))
        passwordFlavorSelector.selectedSegmentIndex = PasswordGeneratorFlavor.allCases.firstIndex(of: passwordGenerator.flavor)!
        passwordFlavorSelector.addTarget(self, action: #selector(flavorChanged), for: .valueChanged)
        passwordFlavorCell?.accessoryView = passwordFlavorSelector
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if navigationItemTitle != nil {
            navigationItem.title = navigationItemTitle
        }

        tableView.register(UINib(nibName: "TextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "textFieldCell")
        tableView.register(UINib(nibName: "TextViewTableViewCell", bundle: nil), forCellReuseIdentifier: "textViewCell")
        tableView.register(UINib(nibName: "FillPasswordTableViewCell", bundle: nil), forCellReuseIdentifier: "fillPasswordCell")
        tableView.register(UINib(nibName: "SliderTableViewCell", bundle: nil), forCellReuseIdentifier: "sliderCell")
        tableView.register(UINib(nibName: "SwitchTableViewCell", bundle: nil), forCellReuseIdentifier: "switchCell")

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 48
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 0

        tableData = [
            [
                [.type: PasswordEditorCellType.nameCell, .title: "Name".localize(), .content: password?.namePath ?? ""],
            ],
            [
                [.type: PasswordEditorCellType.fillPasswordCell, .title: "Password".localize(), .content: password?.password ?? ""],
                [.type: PasswordEditorCellType.passwordFlavorCell],
                [.type: PasswordEditorCellType.passwordLengthCell],
                [.type: PasswordEditorCellType.passwordUseDigitsCell],
                [.type: PasswordEditorCellType.passwordVaryCasesCell],
                [.type: PasswordEditorCellType.passwordUseSpecialSymbols],
            ],
            [
                [.type: PasswordEditorCellType.additionsCell, .title: "Additions".localize(), .content: password?.additionsPlainText ?? ""],
            ],
            [
                [.type: PasswordEditorCellType.scanQRCodeCell],
            ],
        ]

        if password != nil {
            tableData[additionsSection + 1].append([.type: PasswordEditorCellType.deletePasswordCell])
        }
        updateTableData(withRespectTo: passwordGenerator.flavor)
    }

    override func viewDidLayoutSubviews() {
        additionsCell?.contentTextView.setContentOffset(.zero, animated: false)
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellData = tableData[indexPath.section][indexPath.row]

        switch cellData[PasswordEditorCellKey.type] as! PasswordEditorCellType {
        case .nameCell:
            nameCell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath) as? TextFieldTableViewCell
            nameCell?.contentTextField.delegate = self
            nameCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            return nameCell!
        case .fillPasswordCell:
            fillPasswordCell = tableView.dequeueReusableCell(withIdentifier: "fillPasswordCell", for: indexPath) as? FillPasswordTableViewCell
            fillPasswordCell?.delegate = self
            fillPasswordCell?.contentTextField.delegate = self
            fillPasswordCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            if tableData[passwordSection].count == 1 {
                fillPasswordCell?.settingButton.isHidden = true
            }
            return fillPasswordCell!
        case .passwordLengthCell:
            return (tableView.dequeueReusableCell(withIdentifier: "sliderCell", for: indexPath) as! SliderTableViewCell)
                .set(title: "Length".localize())
                .configureSlider(with: passwordGenerator.flavor.lengthLimits)
                .set(initialValue: passwordGenerator.limitedLength)
                .checkNewValue { $0 != self.passwordGenerator.length }
                .updateNewValue { self.passwordGenerator.length = $0 }
                .delegate(to: self)
        case .passwordUseDigitsCell:
            return (tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as! SwitchTableViewCell)
                .set(title: "Digits".localize())
                .set(initialValue: passwordGenerator.useDigits)
                .updateNewValue { self.passwordGenerator.useDigits = $0 }
                .delegate(to: self)
        case .passwordVaryCasesCell:
            return (tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as! SwitchTableViewCell)
                .set(title: "VaryCases".localize())
                .set(initialValue: passwordGenerator.varyCases)
                .updateNewValue { self.passwordGenerator.varyCases = $0 }
                .delegate(to: self)
        case .passwordUseSpecialSymbols:
            return (tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as! SwitchTableViewCell)
                .set(title: "SpecialSymbols".localize())
                .set(initialValue: passwordGenerator.useSpecialSymbols)
                .updateNewValue { self.passwordGenerator.useSpecialSymbols = $0 }
                .delegate(to: self)
        case .passwordGroupsCell:
            return (tableView.dequeueReusableCell(withIdentifier: "sliderCell", for: indexPath) as! SliderTableViewCell)
                .set(title: "Groups".localize())
                .configureSlider(with: (min: 0, max: 6))
                .set(initialValue: passwordGenerator.groups)
                .checkNewValue { $0 != self.passwordGenerator.groups && self.passwordGenerator.isAcceptable(groups: $0) }
                .updateNewValue { self.passwordGenerator.groups = $0 }
                .delegate(to: self)
        case .passwordFlavorCell:
            return passwordFlavorCell!
        case .additionsCell:
            additionsCell = tableView.dequeueReusableCell(withIdentifier: "textViewCell", for: indexPath) as? TextViewTableViewCell
            additionsCell?.contentTextView.delegate = self
            additionsCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            additionsCell?.contentTextView.textColor = Colors.label
            return additionsCell!
        case .deletePasswordCell:
            return deletePasswordCell!
        case .scanQRCodeCell:
            return scanQRCodeCell!
        }
    }

    override func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        44
    }

    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch tableData[indexPath.section][indexPath.row][PasswordEditorCellKey.type] as! PasswordEditorCellType {
        case .passwordGroupsCell, .passwordLengthCell:
            return 42
        case .passwordFlavorCell, .passwordUseDigitsCell, .passwordUseSpecialSymbols, .passwordVaryCasesCell:
            return 42
        default:
            return UITableView.automaticDimension
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        tableData.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == passwordSection, hidePasswordSettings {
            // hide the password section, only the password should be shown
            return 1
        }
        return tableData[section].count
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        sectionHeaderTitles[section]
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        sectionFooterTitles[section]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedCell = tableView.cellForRow(at: indexPath)
        tableView.deselectRow(at: indexPath, animated: true)

        if selectedCell == deletePasswordCell {
            let alert = UIAlertController(title: "DeletePassword?".localize(), message: nil, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(
                UIAlertAction(title: "Delete".localize(), style: UIAlertAction.Style.destructive) { [unowned self] _ -> Void in
                    self.performSegue(withIdentifier: "deletePasswordSegue", sender: self)
                }
            )
            alert.addAction(UIAlertAction.cancel())
            present(alert, animated: true, completion: nil)
        } else if selectedCell == scanQRCodeCell {
            performSegue(withIdentifier: "showQRScannerSegue", sender: self)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Defaults.passwordGenerator = passwordGenerator
    }

    private func updateTableData(withRespectTo flavor: PasswordGeneratorFlavor) {
        // Remove delimiter configuration for XKCD style passwords. Re-add it for random ones.
        switch flavor {
        case .random:
            if tableData[1].contains(where: isPasswordDelimiterCellData) {
                return
            }
            tableData[1].insert([.type: PasswordEditorCellType.passwordGroupsCell], at: tableData[1].endIndex)
        case .xkcd:
            tableData[1].removeAll(where: isPasswordDelimiterCellData)
        }
    }

    private func isPasswordDelimiterCellData(data: [PasswordEditorCellKey: Any]) -> Bool {
        (data[.type] as? PasswordEditorCellType) == .some(.passwordGroupsCell)
    }

    @objc
    func flavorChanged(_ sender: UISegmentedControl) {
        let flavor = PasswordGeneratorFlavor.allCases[sender.selectedSegmentIndex]
        guard passwordGenerator.flavor != flavor else {
            return
        }
        passwordGenerator.flavor = flavor
        updateTableData(withRespectTo: flavor)
        tableView.reloadSections([passwordSection], with: .none)
        generateAndCopyPassword()
    }

    // generate the password, don't care whether the original line is otp
    private func generateAndCopyPasswordNoOtpCheck() {
        // show password settings (e.g., the length slider)
        showPasswordSettings()

        let plainPassword = passwordGenerator.generate()

        // update tableData so to make sure reloadData() works correctly
        tableData[passwordSection][0][PasswordEditorCellKey.content] = plainPassword

        // update cell manually, no need to call reloadData()
        fillPasswordCell?.setContent(content: plainPassword)
    }

    // show password settings (e.g., the length slider)
    private func showPasswordSettings() {
        if hidePasswordSettings == true {
            hidePasswordSettings = false
            tableView.reloadSections([passwordSection], with: .fade)
        }
    }

    private func insertScannedOTPFields(_ otpauth: String) {
        // update tableData
        var additionsString = ""
        if let additionsPlainText = (tableData[additionsSection][0][PasswordEditorCellKey.content] as? String)?.trimmed, !additionsPlainText.isEmpty {
            additionsString = additionsPlainText + "\n" + otpauth
        } else {
            additionsString = otpauth
        }
        tableData[additionsSection][0][PasswordEditorCellKey.content] = additionsString

        // reload the additions cell
        additionsCell?.setContent(content: additionsString)
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "showQRScannerSegue" {
            if let navController = segue.destination as? UINavigationController {
                if let viewController = navController.topViewController as? QRScannerController {
                    viewController.delegate = self
                }
            } else if let viewController = segue.destination as? QRScannerController {
                viewController.delegate = self
            }
        }
    }

    func getNameURL() -> (String, URL) {
        let encodedName = (nameCell?.getContent()?.stringByAddingPercentEncodingForRFC3986())!
        let name = URL(string: encodedName)!.lastPathComponent
        let url = URL(string: encodedName)!.appendingPathExtension("gpg")
        return (name, url)
    }

    func checkName() -> Bool {
        // the name field should not be empty
        guard let name = nameCell?.getContent(), name.isEmpty == false else {
            Utils.alert(title: "CannotSave".localize(), message: "FillInName.".localize(), controller: self, completion: nil)
            return false
        }

        // the name should not start with /
        guard name.hasPrefix("/") == false else {
            Utils.alert(title: "CannotSave".localize(), message: "RemovePrefix.".localize(), controller: self, completion: nil)
            return false
        }

        // the name field should be a valid url
        guard let path = name.stringByAddingPercentEncodingForRFC3986(),
              var passwordURL = URL(string: path) else {
            Utils.alert(title: "CannotSave".localize(), message: "PasswordNameInvalid.".localize(), controller: self, completion: nil)
            return false
        }

        // check whether we can parse the filename (be consistent with PasswordStore::addPasswordEntities)
        var previousPathLength = Int.max
        while passwordURL.path != "." {
            passwordURL = passwordURL.deletingLastPathComponent()
            if passwordURL.path != ".", passwordURL.path.count >= previousPathLength {
                Utils.alert(title: "CannotSave".localize(), message: "CannotParseFilename.".localize(), controller: self, completion: nil)
                return false
            }
            previousPathLength = passwordURL.path.count
        }

        return true
    }
}

// MARK: - FillPasswordTableViewCellDelegate

extension PasswordEditorTableViewController: FillPasswordTableViewCellDelegate {
    // generate password, copy to pasteboard, and set the cell
    // check whether the current password looks like an OTP field
    func generateAndCopyPassword() {
        if let currentPassword = fillPasswordCell?.getContent(), Constants.isOtpRelated(line: currentPassword) {
            let alert = UIAlertController(title: "Overwrite?".localize(), message: "OverwriteOtpConfiguration?".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(
                UIAlertAction(title: "Yes".localize(), style: UIAlertAction.Style.destructive) { _ in
                    self.generateAndCopyPasswordNoOtpCheck()
                }
            )
            alert.addAction(UIAlertAction.cancel())
            present(alert, animated: true, completion: nil)
        } else {
            generateAndCopyPasswordNoOtpCheck()
        }
    }

    // show/hide password settings (e.g., the length slider)
    func showHidePasswordSettings() {
        hidePasswordSettings.toggle()
        tableView.reloadSections([passwordSection], with: .fade)
    }
}

// MARK: - PasswordSettingSliderTableViewCellDelegate

extension PasswordEditorTableViewController: PasswordSettingSliderTableViewCellDelegate {}

// MARK: - QRScannerControllerDelegate

extension PasswordEditorTableViewController: QRScannerControllerDelegate {
    func checkScannedOutput(line: String) -> (accepted: Bool, message: String) {
        if let url = URL(string: line), Token(url: url) != nil {
            return (true, "ValidTokenUrl".localize())
        }
        return (false, "InvalidTokenUrl".localize())
    }

    func handleScannedOutput(line: String) {
        insertScannedOTPFields(line)
    }
}

// MARK: - SFSafariViewControllerDelegate

extension PasswordEditorTableViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_: SFSafariViewController) {
        let copiedLinesSplit = UIPasteboard.general.string?.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
        if copiedLinesSplit?.count ?? 0 > 0 {
            let generatedPassword = copiedLinesSplit![0]
            let alert = UIAlertController(title: "WannaUseIt?".localize(), message: "", preferredStyle: UIAlertController.Style.alert)
            let message = NSMutableAttributedString(string: "\("SeemsLikeYouHaveCopiedSomething.".localize()) \("FirstStringIs:".localize())\n")
            message.append(Utils.attributedPassword(plainPassword: generatedPassword))
            alert.setValue(message, forKey: "attributedMessage")
            alert.addAction(
                UIAlertAction(title: "Yes", style: UIAlertAction.Style.default) { [unowned self] _ -> Void in
                    // update tableData so to make sure reloadData() works correctly
                    self.tableData[self.passwordSection][0][PasswordEditorCellKey.content] = generatedPassword
                    // update cell manually, no need to call reloadData()
                    self.fillPasswordCell?.setContent(content: generatedPassword)
                }
            )
            alert.addAction(UIAlertAction.cancel())
            present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: - UITextFieldDelegate

extension PasswordEditorTableViewController: UITextFieldDelegate {
    // update tableData so to make sure reloadData() works correctly
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == nameCell?.contentTextField {
            tableData[nameSection][0][PasswordEditorCellKey.content] = nameCell?.getContent()
        } else if textField == fillPasswordCell?.contentTextField {
            if let plainPassword = fillPasswordCell?.getContent() {
                tableData[passwordSection][0][PasswordEditorCellKey.content] = plainPassword
            }
        }
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == fillPasswordCell?.contentTextField {
            // show password generation settings automatically
            showPasswordSettings()
        }
    }
}

// MARK: - UITextViewDelegate

extension PasswordEditorTableViewController: UITextViewDelegate {
    // update tableData so to make sure reloadData() works correctly
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == additionsCell?.contentTextView {
            tableData[additionsSection][0][PasswordEditorCellKey.content] = additionsCell?.getContent()
        }
    }
}
