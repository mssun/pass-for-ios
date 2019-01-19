//
//  PasswordStore.swift
//  pass
//
//  Created by Mingshen Sun on 19/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import SwiftyUserDefaults
import ObjectiveGit
import ObjectivePGP
import KeychainAccess

public class PasswordStore {
    public static let shared = PasswordStore()
    public let storeURL = URL(fileURLWithPath: "\(Globals.repositoryPath)")
    public let tempStoreURL = URL(fileURLWithPath: "\(Globals.repositoryPath)-temp")

    public var storeRepository: GTRepository?
    public var pgpKeyID: String?
    public var publicKey: Key? {
        didSet {
            if publicKey != nil {
                pgpKeyID = publicKey!.keyID.shortIdentifier
            } else {
                pgpKeyID = nil
            }
        }
    }
    public var privateKey: Key?

    public var gitSignatureForNow: GTSignature {
        get {
            let gitSignatureName = SharedDefaults[.gitSignatureName] ?? Globals.gitSignatureDefaultName
            let gitSignatureEmail = SharedDefaults[.gitSignatureEmail] ?? Globals.gitSignatureDefaultEmail
            return GTSignature(name: gitSignatureName, email: gitSignatureEmail, time: Date())!
        }
    }

    public let keyring = ObjectivePGP.defaultKeyring

    public var pgpKeyPassphrase: String? {
        set {
            Utils.addPasswordToKeychain(name: "pgpKeyPassphrase", password: newValue)
        }
        get {
            return Utils.getPasswordFromKeychain(name: "pgpKeyPassphrase")
        }
    }

    public var gitPassword: String? {
        set {
            Utils.addPasswordToKeychain(name: "gitPassword", password: newValue)
        }
        get {
            return Utils.getPasswordFromKeychain(name: "gitPassword")
        }
    }

    public var gitSSHPrivateKeyPassphrase: String? {
        set {
            Utils.addPasswordToKeychain(name: "gitSSHPrivateKeyPassphrase", password: newValue)
        }
        get {
            return Utils.getPasswordFromKeychain(name: "gitSSHPrivateKeyPassphrase")
        }
    }

    private let fm = FileManager.default
    lazy private var context: NSManagedObjectContext = {
        let modelURL = Bundle(identifier: Globals.passKitBundleIdentifier)!.url(forResource: "pass", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        let container = NSPersistentContainer(name: "pass", managedObjectModel: managedObjectModel!)
        if FileManager.default.fileExists(atPath: Globals.documentPath) {
            try! FileManager.default.createDirectory(atPath: Globals.documentPath, withIntermediateDirectories: true, attributes: nil)
        }
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: URL(fileURLWithPath: Globals.dbPath))]
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("UnresolvedError".localize("\(error.localizedDescription), \(error.userInfo)"))
            }
        })
        return container.viewContext
    }()

    public var numberOfPasswords : Int {
        return self.fetchPasswordEntityCoreData(withDir: false).count
    }

    public var sizeOfRepositoryByteCount : UInt64 {
        return (try? fm.allocatedSizeOfDirectoryAtURL(directoryURL: self.storeURL)) ?? 0
    }

    public var numberOfLocalCommits: Int? {
        return (try? getLocalCommits())?.flatMap { $0.count }
    }

    public var lastSyncedTime: Date? {
        return SharedDefaults[.lastSyncedTime]
    }

    public var numberOfCommits: UInt? {
        return storeRepository?.numberOfCommits(inCurrentBranch: nil)
    }

    private init() {
        // File migration to group
        migrateIfNeeded()
        backwardCompatibility()

        do {
            if fm.fileExists(atPath: storeURL.path) {
                try storeRepository = GTRepository.init(url: storeURL)
            }
            try initPGPKeys()
        } catch {
            print(error)
        }
    }

    private func migrateIfNeeded() {
        // migrate happens only if the repository was cloned and pgp keys were set up using earlier versions
        let needMigration = !pgpKeyExists() && !gitSSHKeyExists() && !fm.fileExists(atPath: Globals.repositoryPath) && fm.fileExists(atPath: Globals.repositoryPathLegacy)
        guard needMigration == true else {
            return
        }

        do {
            // migrate Defaults
            let userDefaults = UserDefaults()
            for key in Defaults.dictionaryRepresentation().keys {
                if SharedDefaults.value(forKey: key) == nil {
                    SharedDefaults.setValue(userDefaults.value(forKey: key), forKey: key)
                }
            }

            // migrate files
            try fm.createDirectory(atPath: Globals.documentPath, withIntermediateDirectories: true, attributes: nil)
            try fm.createDirectory(atPath: Globals.libraryPath, withIntermediateDirectories: true, attributes: nil)
            if fm.fileExists(atPath: Globals.pgpPublicKeyPathLegacy) {
                try fm.moveItem(atPath: Globals.pgpPublicKeyPathLegacy, toPath: Globals.pgpPublicKeyPath)
            }
            if fm.fileExists(atPath: Globals.pgpPrivateKeyPathLegacy) {
                try fm.moveItem(atPath: Globals.pgpPrivateKeyPathLegacy, toPath: Globals.pgpPrivateKeyPath)
            }
            if fm.fileExists(atPath: Globals.gitSSHPrivateKeyPathLegacy) {
                try fm.moveItem(atPath: Globals.gitSSHPrivateKeyPathLegacy, toPath: Globals.gitSSHPrivateKeyPath)
            }
            try fm.moveItem(atPath: Globals.repositoryPathLegacy, toPath: Globals.repositoryPath)
        } catch {
            print("MigrationError".localize(error))
        }
        updatePasswordEntityCoreData()
    }

    private func backwardCompatibility() {
        // For the newly-introduced isRememberGitCredentialPassphraseOn (20171008)
        if (self.gitPassword != nil || self.gitSSHPrivateKeyPassphrase != nil) && SharedDefaults[.isRememberGitCredentialPassphraseOn] == false {
            SharedDefaults[.isRememberGitCredentialPassphraseOn] = true
        }
        // For the renamed isRememberPGPPassphraseOn (20171008)
        if self.pgpKeyPassphrase != nil && SharedDefaults[.isRememberPGPPassphraseOn] == false {
            SharedDefaults[.isRememberPGPPassphraseOn] = true
        }
    }

    enum SSHKeyType {
        case `public`, secret
    }

    public func initGitSSHKey(with armorKey: String) throws {
        let keyPath = Globals.gitSSHPrivateKeyPath
        try armorKey.write(toFile: keyPath, atomically: true, encoding: .ascii)
    }

    public func initPGPKeys() throws {
        try initPGPKey(.public)
        try initPGPKey(.secret)
    }

    public func initPGPKey(_ keyType: PGPKeyType) throws {
        switch keyType {
        case .public:
            let keyPath = Globals.pgpPublicKeyPath
            self.publicKey = importKey(from: keyPath)
            if self.publicKey == nil {
                throw AppError.KeyImportError
            }
        case .secret:
            let keyPath = Globals.pgpPrivateKeyPath
            self.privateKey = importKey(from: keyPath)
            if self.privateKey == nil  {
                throw AppError.KeyImportError
            }
        default:
            throw AppError.UnknownError
        }
    }

    public func initPGPKey(from url: URL, keyType: PGPKeyType) throws {
        var pgpKeyLocalPath = ""
        if keyType == .public {
            pgpKeyLocalPath = Globals.pgpPublicKeyPath
        } else {
            pgpKeyLocalPath = Globals.pgpPrivateKeyPath
        }
        let pgpKeyData = try Data(contentsOf: url)
        try pgpKeyData.write(to: URL(fileURLWithPath: pgpKeyLocalPath), options: .atomic)
        try initPGPKey(keyType)
    }

    public func initPGPKey(with armorKey: String, keyType: PGPKeyType) throws {
        var pgpKeyLocalPath = ""
        if keyType == .public {
            pgpKeyLocalPath = Globals.pgpPublicKeyPath
        } else {
            pgpKeyLocalPath = Globals.pgpPrivateKeyPath
        }
        try armorKey.write(toFile: pgpKeyLocalPath, atomically: true, encoding: .ascii)
        try initPGPKey(keyType)
    }


    private func importKey(from keyPath: String) -> Key? {
        if fm.fileExists(atPath: keyPath) {
            let keys = try! ObjectivePGP.readKeys(fromPath: keyPath)
            keyring.import(keys: keys)
            if !keys.isEmpty {
                return keys.first
            }
        }
        return nil
    }

    public func getPgpPrivateKey() -> Key {
        return keyring.keys.filter({$0.secretKey != nil})[0]
    }

    public func repositoryExisted() -> Bool {
        let fm = FileManager()
        return fm.fileExists(atPath: Globals.repositoryPath)
    }

    public func passwordExisted(password: Password) -> Bool {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "name = %@ and path = %@", password.name, password.url.path)
            let count = try context.count(for: passwordEntityFetchRequest)
            if count > 0 {
                return true
            } else {
                return false
            }
        } catch {
            fatalError("FailedToFetchPasswordEntities".localize(error))
        }
        return true
    }

    public func passwordEntityExisted(path: String) -> Bool {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "path = %@", path)
            let count = try context.count(for: passwordEntityFetchRequest)
            if count > 0 {
                return true
            } else {
                return false
            }
        } catch {
            fatalError("FailedToFetchPasswordEntities".localize(error))
        }
        return true
    }

    public func getPasswordEntity(by path: String, isDir: Bool) -> PasswordEntity? {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "path = %@ and isDir = %@", path, isDir as NSNumber)
            return try context.fetch(passwordEntityFetchRequest).first as? PasswordEntity
        } catch {
            fatalError("FailedToFetchPasswordEntities".localize(error))
        }
    }

    public func cloneRepository(remoteRepoURL: URL,
                         credential: GitCredential,
                         branchName: String,
                         requestGitPassword: @escaping (GitCredential.Credential, String?) -> String?,
                         transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void,
                         checkoutProgressBlock: @escaping (String?, UInt, UInt) -> Void) throws {
        try? fm.removeItem(at: storeURL)
        try? fm.removeItem(at: tempStoreURL)
        self.gitPassword = nil
        self.gitSSHPrivateKeyPassphrase = nil
        do {
            let credentialProvider = try credential.credentialProvider(requestGitPassword: requestGitPassword)
            let options = [GTRepositoryCloneOptionsCredentialProvider: credentialProvider]
            storeRepository = try GTRepository.clone(from: remoteRepoURL, toWorkingDirectory: tempStoreURL, options: options, transferProgressBlock:transferProgressBlock)
            try fm.moveItem(at: tempStoreURL, to: storeURL)
            storeRepository = try GTRepository(url: storeURL)
            try checkoutAndChangeBranch(withName: branchName)
        } catch {
            credential.delete()
            DispatchQueue.main.async {
                SharedDefaults[.lastSyncedTime] = nil
                self.deleteCoreData(entityName: "PasswordEntity")
                NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
            }
            throw(error)
        }
        DispatchQueue.main.async {
            SharedDefaults[.lastSyncedTime] = Date()
            self.updatePasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }

    private func checkoutAndChangeBranch(withName localBranchName: String) throws {
        if (localBranchName == "master") {
            return
        }
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        let remoteBranchName = "origin/\(localBranchName)"
        guard let remoteBranch = try? storeRepository.lookUpBranch(withName: remoteBranchName, type: .remote, success: nil) else {
            throw AppError.RepositoryRemoteBranchNotFoundError(remoteBranchName)
        }
        guard let remoteBranchOid = remoteBranch.oid else {
            throw AppError.RepositoryRemoteBranchNotFoundError(remoteBranchName)
        }
        let localBranch = try storeRepository.createBranchNamed(localBranchName, from: remoteBranchOid, message: nil)
        try localBranch.updateTrackingBranch(remoteBranch)
        let checkoutOptions = GTCheckoutOptions.init(strategy: .force)
        try storeRepository.checkoutReference(localBranch.reference, options: checkoutOptions)
        try storeRepository.moveHEAD(to: localBranch.reference)
    }

    public func pullRepository(credential: GitCredential, requestGitPassword: @escaping (GitCredential.Credential, String?) -> String?, transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        let credentialProvider = try credential.credentialProvider(requestGitPassword: requestGitPassword)
        let options = [GTRepositoryRemoteOptionsCredentialProvider: credentialProvider]
        let remote = try GTRemote(name: "origin", in: storeRepository)
        try storeRepository.pull(storeRepository.currentBranch(), from: remote, withOptions: options, progress: transferProgressBlock)
        DispatchQueue.main.async {
            SharedDefaults[.lastSyncedTime] = Date()
            self.setAllSynced()
            self.updatePasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }

    private func updatePasswordEntityCoreData() {
        deleteCoreData(entityName: "PasswordEntity")
        do {
            var q = try fm.contentsOfDirectory(atPath: self.storeURL.path).filter{
                !$0.hasPrefix(".")
            }.map { (filename) -> PasswordEntity in
                let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: context) as! PasswordEntity
                if filename.hasSuffix(".gpg") {
                    passwordEntity.name = String(filename.prefix(upTo: filename.index(filename.endIndex, offsetBy: -4)))
                } else {
                    passwordEntity.name = filename
                }
                passwordEntity.path = filename
                passwordEntity.parent = nil
                return passwordEntity
            }
            while q.count > 0 {
                let e = q.first!
                q.remove(at: 0)
                guard !e.name!.hasPrefix(".") else {
                    continue
                }
                var isDirectory: ObjCBool = false
                let filePath = storeURL.appendingPathComponent(e.path!).path
                if fm.fileExists(atPath: filePath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        e.isDir = true
                        let files = try fm.contentsOfDirectory(atPath: filePath).map { (filename) -> PasswordEntity in
                            let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: context) as! PasswordEntity
                            if filename.hasSuffix(".gpg") {
                                passwordEntity.name = String(filename.prefix(upTo: filename.index(filename.endIndex, offsetBy: -4)))
                            } else {
                                passwordEntity.name = filename
                            }
                            passwordEntity.path = "\(e.path!)/\(filename)"
                            passwordEntity.parent = e
                            return passwordEntity
                        }
                        q += files
                    } else {
                        e.isDir = false
                    }
                }
            }
        } catch {
            print(error)
        }
        do {
            try context.save()
        } catch {
            print("ErrorSaving".localize(error))
        }
    }

    public func getRecentCommits(count: Int) throws -> [GTCommit] {
        guard let storeRepository = storeRepository else {
            return []
        }
        var commits = [GTCommit]()
        let enumerator = try GTEnumerator(repository: storeRepository)
        if let targetOID = try storeRepository.headReference().targetOID {
            try enumerator.pushSHA(targetOID.sha)
        }
        for _ in 0 ..< count {
            if let commit = try? enumerator.nextObject(withSuccess: nil) {
                commits.append(commit)
            }
        }
        return commits
    }

    public func fetchPasswordEntityCoreData(parent: PasswordEntity?) -> [PasswordEntity] {
        let passwordEntityFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetch.predicate = NSPredicate(format: "parent = %@", parent ?? 0)
            let fetchedPasswordEntities = try context.fetch(passwordEntityFetch) as! [PasswordEntity]
            return fetchedPasswordEntities.sorted { $0.name!.caseInsensitiveCompare($1.name!) == .orderedAscending }
        } catch {
            fatalError("FailedToFetchPasswords".localize(error))
        }
    }

    public func fetchPasswordEntityCoreData(withDir: Bool) -> [PasswordEntity] {
        let passwordEntityFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            if !withDir {
                passwordEntityFetch.predicate = NSPredicate(format: "isDir = false")
            }
            let fetchedPasswordEntities = try context.fetch(passwordEntityFetch) as! [PasswordEntity]
            return fetchedPasswordEntities.sorted { $0.name!.caseInsensitiveCompare($1.name!) == .orderedAscending }
        } catch {
            fatalError("FailedToFetchPasswords".localize(error))
        }
    }


    public func fetchUnsyncedPasswords() -> [PasswordEntity] {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        passwordEntityFetchRequest.predicate = NSPredicate(format: "synced = %i", 0)
        do {
            let passwordEntities = try context.fetch(passwordEntityFetchRequest) as! [PasswordEntity]
            return passwordEntities
        } catch {
            fatalError("FailedToFetchPasswords".localize(error))
        }
    }

    public func setAllSynced() {
        let passwordEntities = fetchUnsyncedPasswords()
        for passwordEntity in passwordEntities {
            passwordEntity.synced = true
        }
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            fatalError("ErrorSaving".localize(error))
        }
    }

    public func getLatestUpdateInfo(filename: String) -> String {
        guard let storeRepository = storeRepository else {
            return "Unknown".localize()
        }
        guard let blameHunks = try? storeRepository.blame(withFile: filename, options: nil).hunks,
            let latestCommitTime = blameHunks.map({
                 $0.finalSignature?.time?.timeIntervalSince1970 ?? 0
            }).max() else {
            return "Unknown".localize()
        }
        let lastCommitDate = Date(timeIntervalSince1970: latestCommitTime)
        let currentDate = Date()
        var autoFormattedDifference: String
        if currentDate.timeIntervalSince(lastCommitDate) <= 60 {
            autoFormattedDifference = "JustNow".localize()
        } else {
            let diffDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: lastCommitDate, to: currentDate)
            let dateComponentsFormatter = DateComponentsFormatter()
            dateComponentsFormatter.unitsStyle = .full
            dateComponentsFormatter.maximumUnitCount = 2
            dateComponentsFormatter.includesApproximationPhrase = true
            autoFormattedDifference = "TimeAgo".localize(dateComponentsFormatter.string(from: diffDate)!)
        }
        return autoFormattedDifference
    }

    public func updateRemoteRepo() {
    }

    private func gitAdd(path: String) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        try storeRepository.index().addFile(path)
        try storeRepository.index().write()
    }

    private func gitRm(path: String) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        let url = storeURL.appendingPathComponent(path)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        try storeRepository.index().removeFile(path)
        try storeRepository.index().write()
    }

    private func deleteDirectoryTree(at url: URL) throws {
        var tempURL = storeURL.appendingPathComponent(url.deletingLastPathComponent().path)
        var count = try fm.contentsOfDirectory(atPath: tempURL.path).count
        while count == 0 {
            try fm.removeItem(at: tempURL)
            tempURL.deleteLastPathComponent()
            count = try fm.contentsOfDirectory(atPath: tempURL.path).count
        }
    }

    private func createDirectoryTree(at url: URL) throws {
        let tempURL = storeURL.appendingPathComponent(url.deletingLastPathComponent().path)
        try fm.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
    }

    private func gitMv(from: String, to: String) throws {
        let fromURL = storeURL.appendingPathComponent(from)
        let toURL = storeURL.appendingPathComponent(to)
        try fm.moveItem(at: fromURL, to: toURL)
        try gitAdd(path: to)
        try gitRm(path: from)
    }

    private func gitCommit(message: String) throws -> GTCommit? {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        let newTree = try storeRepository.index().writeTree()
        let headReference = try storeRepository.headReference()
        let commitEnum = try GTEnumerator(repository: storeRepository)
        try commitEnum.pushSHA(headReference.targetOID!.sha)
        let parent = commitEnum.nextObject() as! GTCommit
        let signature = gitSignatureForNow
        let commit = try storeRepository.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: [parent], updatingReferenceNamed: headReference.name)
        return commit
    }

    private func getLocalBranch(withName branchName: String) throws -> GTBranch? {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        let reference = GTBranch.localNamePrefix().appending(branchName)
        let branches = try storeRepository.branches(withPrefix: reference)
        return branches.first
    }

    public func pushRepository(credential: GitCredential, requestGitPassword: @escaping (GitCredential.Credential, String?) -> String?, transferProgressBlock: @escaping (UInt32, UInt32, Int, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        do {
            let credentialProvider = try credential.credentialProvider(requestGitPassword: requestGitPassword)
            let options = [GTRepositoryRemoteOptionsCredentialProvider: credentialProvider]
            if let branch = try getLocalBranch(withName: SharedDefaults[.gitBranchName]!) {
                let remote = try GTRemote(name: "origin", in: storeRepository)
                try storeRepository.push(branch, to: remote, withOptions: options, progress: transferProgressBlock)
            }
        } catch {
            throw(error)
        }
    }

    private func addPasswordEntities(password: Password) throws -> PasswordEntity? {
        guard !passwordExisted(password: password) else {
            throw AppError.PasswordDuplicatedError
        }

        var passwordURL = password.url
        var previousPathLength = Int.max
        var paths: [String] = []
        while passwordURL.path != "." {
            paths.append(passwordURL.path)
            passwordURL = passwordURL.deletingLastPathComponent()
            // better identify errors before saving a new password
            if passwordURL.path != "." && passwordURL.path.count >= previousPathLength {
                throw AppError.WrongPasswordFilename
            }
            previousPathLength = passwordURL.path.count
        }
        paths.reverse()
        var parentPasswordEntity: PasswordEntity? = nil
        for path in paths {
            let isDir = !path.hasSuffix(".gpg")
            if let passwordEntity = getPasswordEntity(by: path, isDir: isDir) {
                parentPasswordEntity = passwordEntity
                passwordEntity.synced = false
            } else {
                if !isDir {
                    return insertPasswordEntity(name: URL(string: path.stringByAddingPercentEncodingForRFC3986()!)!.deletingPathExtension().lastPathComponent, path: path, parent: parentPasswordEntity, synced: false, isDir: false)
                } else {
                    parentPasswordEntity = insertPasswordEntity(name: URL(string: path.stringByAddingPercentEncodingForRFC3986()!)!.lastPathComponent, path: path, parent: parentPasswordEntity, synced: false, isDir: true)
                }
            }
        }
        return nil
    }

    private func insertPasswordEntity(name: String, path: String, parent: PasswordEntity?, synced: Bool = false, isDir: Bool = false) -> PasswordEntity? {
        var ret: PasswordEntity? = nil
        if let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: self.context) as? PasswordEntity {
            passwordEntity.name = name
            passwordEntity.path = path
            passwordEntity.parent = parent
            passwordEntity.synced = synced
            passwordEntity.isDir = isDir
            do {
                try self.context.save()
                ret = passwordEntity
            } catch {
                fatalError("FailedToInsertPasswordEntity".localize(error))
            }
        }
        return ret
    }

    public func add(password: Password) throws -> PasswordEntity? {
        try createDirectoryTree(at: password.url)
        let newPasswordEntity = try addPasswordEntities(password: password)
        let saveURL = storeURL.appendingPathComponent(password.url.path)
        try self.encrypt(password: password).write(to: saveURL)
        try gitAdd(path: password.url.path)
        let _ = try gitCommit(message: "AddPassword.".localize(password.url.deletingPathExtension().path))
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        return newPasswordEntity
    }

    public func delete(passwordEntity: PasswordEntity) throws {
        let deletedFileURL = passwordEntity.getURL()!
        try gitRm(path: deletedFileURL.path)
        try deletePasswordEntities(passwordEntity: passwordEntity)
        try deleteDirectoryTree(at: deletedFileURL)
        let _ = try gitCommit(message: "RemovePassword.".localize(deletedFileURL.deletingPathExtension().path.removingPercentEncoding!))
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
    }

    public func edit(passwordEntity: PasswordEntity, password: Password) throws -> PasswordEntity? {
        var newPasswordEntity: PasswordEntity? = passwordEntity

        if password.changed&PasswordChange.content.rawValue != 0 {
            let saveURL = storeURL.appendingPathComponent(passwordEntity.getURL()!.path)
            try self.encrypt(password: password).write(to: saveURL)
            try gitAdd(path: passwordEntity.getURL()!.path)
            let _ = try gitCommit(message: "EditPassword.".localize(passwordEntity.getURL()!.deletingPathExtension().path.removingPercentEncoding!))
            newPasswordEntity = passwordEntity
            newPasswordEntity?.synced = false
        }

        if password.changed&PasswordChange.path.rawValue != 0 {
            let deletedFileURL = passwordEntity.getURL()!
            // add
            try createDirectoryTree(at: password.url)
            newPasswordEntity = try addPasswordEntities(password: password)

            // mv
            try gitMv(from: deletedFileURL.path, to: password.url.path)

            // delete
            try deleteDirectoryTree(at: deletedFileURL)
            try deletePasswordEntities(passwordEntity: passwordEntity)
            let _ = try gitCommit(message: "RenamePassword.".localize(deletedFileURL.deletingPathExtension().path.removingPercentEncoding!, password.url.deletingPathExtension().path.removingPercentEncoding!))
        }
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        return newPasswordEntity
    }

    private func deletePasswordEntities(passwordEntity: PasswordEntity) throws {
        var current: PasswordEntity? = passwordEntity
        while current != nil && (current!.children!.count == 0 || !current!.isDir) {
            let parent = current!.parent
            self.context.delete(current!)
            current = parent
            do {
                try self.context.save()
            } catch {
                fatalError("FailedToDeletePasswordEntity".localize(error))
            }
        }
    }

    public func saveUpdated(passwordEntity: PasswordEntity) {
        do {
            try context.save()
        } catch {
            fatalError("FailedToSavePasswordEntity".localize(error))
        }
    }

    public func deleteCoreData(entityName: String) {
        let deleteFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetchRequest)

        do {
            try context.execute(deleteRequest)
            try context.save()
            context.reset()
        } catch let error as NSError {
            print(error)
        }
    }

    public func updateImage(passwordEntity: PasswordEntity, image: Data?) {
        guard let image = image else {
            return
        }
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = context
        privateMOC.perform {
            passwordEntity.image = image
            do {
                try privateMOC.save()
                self.context.performAndWait {
                    do {
                        try self.context.save()
                    } catch {
                        fatalError("FailureToSaveContext".localize(error))
                    }
                }
            } catch {
                fatalError("FailureToSaveContext".localize(error))
            }
        }
    }

    public func erase() {
        publicKey = nil
        privateKey = nil
        try? fm.removeItem(at: storeURL)
        try? fm.removeItem(at: tempStoreURL)

        try? fm.removeItem(atPath: Globals.pgpPublicKeyPath)
        try? fm.removeItem(atPath: Globals.pgpPrivateKeyPath)
        try? fm.removeItem(atPath: Globals.gitSSHPrivateKeyPath)

        Utils.removeAllKeychain()

        deleteCoreData(entityName: "PasswordEntity")

        SharedDefaults.removeAll()
        storeRepository = nil

        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        NotificationCenter.default.post(name: .passwordStoreErased, object: nil)
    }

    // return the number of discarded commits
    public func reset() throws -> Int {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        // get a list of local commits
        if let localCommits = try getLocalCommits(),
            localCommits.count > 0 {
            // get the oldest local commit
            guard let firstLocalCommit = localCommits.last,
                firstLocalCommit.parents.count == 1,
                let newHead = firstLocalCommit.parents.first else {
                    throw AppError.GitResetError
            }
            try storeRepository.reset(to: newHead, resetType: .hard)
            self.setAllSynced()
            self.updatePasswordEntityCoreData()

            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
            NotificationCenter.default.post(name: .passwordStoreChangeDiscarded, object: nil)
            return localCommits.count
        } else {
            return 0  // no new commit
        }
    }


    private func getLocalCommits() throws -> [GTCommit]? {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        // get the remote branch
        let remoteBranchName = SharedDefaults[.gitBranchName]!
        guard let remoteBranch = try storeRepository.remoteBranches().first(where: { $0.shortName == remoteBranchName }) else {
            throw AppError.RepositoryRemoteBranchNotFoundError(remoteBranchName)
        }
        // check oid before calling localCommitsRelative
        guard remoteBranch.oid != nil else {
            throw AppError.RepositoryRemoteBranchNotFoundError(remoteBranchName)
        }

        // get a list of local commits
        return try storeRepository.localCommitsRelative(toRemoteBranch: remoteBranch)
    }



    public func decrypt(passwordEntity: PasswordEntity, requestPGPKeyPassphrase: () -> String) throws -> Password? {
        let encryptedDataPath = storeURL.appendingPathComponent(passwordEntity.getPath())
        let encryptedData = try Data(contentsOf: encryptedDataPath)
        var passphrase = self.pgpKeyPassphrase
        if passphrase == nil {
            passphrase = requestPGPKeyPassphrase()
        }
        let decryptedData = try ObjectivePGP.decrypt(encryptedData, andVerifySignature: false, using: keyring.keys, passphraseForKey: {(_) in passphrase})
        let plainText = String(data: decryptedData, encoding: .utf8) ?? ""
        guard let url = passwordEntity.getURL() else {
            throw AppError.DecryptionError
        }
        return Password(name: passwordEntity.getName(), url: url, plainText: plainText)
    }

    public func encrypt(password: Password) throws -> Data {
        guard keyring.keys.count > 0 else {
            throw AppError.PGPPublicKeyNotExistError
        }
        let plainData = password.plainData
        let encryptedData = try ObjectivePGP.encrypt(plainData, addSignature: false, using: keyring.keys, passphraseForKey: nil)
        if SharedDefaults[.encryptInArmored] {
            return Armor.armored(encryptedData, as: .message).data(using: .utf8)!
        } else {
            return encryptedData
        }
    }

    public func removePGPKeys() {
        try? fm.removeItem(atPath: Globals.pgpPublicKeyPath)
        try? fm.removeItem(atPath: Globals.pgpPrivateKeyPath)
        SharedDefaults.remove(.pgpKeySource)
        SharedDefaults.remove(.pgpPublicKeyArmor)
        SharedDefaults.remove(.pgpPrivateKeyArmor)
        SharedDefaults.remove(.pgpPrivateKeyURL)
        SharedDefaults.remove(.pgpPublicKeyURL)
        Utils.removeKeychain(name: ".pgpKeyPassphrase")
        keyring.deleteAll()
        publicKey = nil
        privateKey = nil
    }

    public func removeGitSSHKeys() {
        try? fm.removeItem(atPath: Globals.gitSSHPrivateKeyPath)
        Defaults.remove(.gitSSHPrivateKeyArmor)
        Defaults.remove(.gitSSHPrivateKeyURL)
        self.gitSSHPrivateKeyPassphrase = nil
    }

    public func gitSSHKeyExists(inFileSharing: Bool = false) -> Bool {
        if inFileSharing == false {
            return fm.fileExists(atPath: Globals.gitSSHPrivateKeyPath)
        } else {
            return fm.fileExists(atPath: Globals.iTunesFileSharingSSHPrivate)
        }
    }

    public func pgpKeyExists(inFileSharing: Bool = false) -> Bool {
        if inFileSharing == false {
            return fm.fileExists(atPath: Globals.pgpPublicKeyPath) && fm.fileExists(atPath: Globals.pgpPrivateKeyPath)
        } else {
            return fm.fileExists(atPath: Globals.iTunesFileSharingPGPPublic) && fm.fileExists(atPath: Globals.iTunesFileSharingPGPPrivate)
        }
    }

    public func gitSSHKeyImportFromFileSharing() throws {
        try fm.moveItem(atPath: Globals.iTunesFileSharingSSHPrivate, toPath: Globals.gitSSHPrivateKeyPath)
    }

    public func pgpKeyImportFromFileSharing() throws {
        try fm.moveItem(atPath: Globals.iTunesFileSharingPGPPublic, toPath: Globals.pgpPublicKeyPath)
        try fm.moveItem(atPath: Globals.iTunesFileSharingPGPPrivate, toPath: Globals.pgpPrivateKeyPath)
    }
}
