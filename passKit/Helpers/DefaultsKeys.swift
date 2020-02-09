//
//  DefaultKeys.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

public var Defaults = DefaultsAdapter(defaults: UserDefaults(suiteName: Globals.groupIdentifier)!, keyStore: DefaultsKeys())

public enum PGPKeySource: String, DefaultsSerializable {
    case url, armor, itunes
}

public enum GitAuthenticationMethod: String, DefaultsSerializable {
    case password, key
}

public enum GitSSHKeySource: String, DefaultsSerializable {
    case file, armor, url
}

public extension DefaultsKeys {
    var pgpKeySource: DefaultsKey<PGPKeySource?> { .init("pgpKeySource") }
    var pgpPublicKeyURL: DefaultsKey<URL?> { .init("pgpPublicKeyURL") }
    var pgpPrivateKeyURL: DefaultsKey<URL?> { .init("pgpPrivateKeyURL") }

    // Keep them for legacy reasons.
    var pgpPublicKeyArmor: DefaultsKey<String?> { .init("pgpPublicKeyArmor") }
    var pgpPrivateKeyArmor: DefaultsKey<String?> { .init("pgpPrivateKeyArmor") }
    var gitSSHPrivateKeyArmor: DefaultsKey<String?> { .init("gitSSHPrivateKeyArmor") }
    var passcodeKey: DefaultsKey<String?> { .init("passcodeKey") }

    var gitURL: DefaultsKey<URL> { .init("gitURL", defaultValue: URL(string: "https://")!) }
    var gitAuthenticationMethod: DefaultsKey<GitAuthenticationMethod> { .init("gitAuthenticationMethod", defaultValue: GitAuthenticationMethod.password) }
    var gitUsername: DefaultsKey<String> { .init("gitUsername", defaultValue: "git") }
    var gitBranchName: DefaultsKey<String> { .init("gitBranchName", defaultValue: "master") }
    var gitSSHPrivateKeyURL: DefaultsKey<URL?> { .init("gitSSHPrivateKeyURL") }
    var gitSSHKeySource: DefaultsKey<GitSSHKeySource?> { .init("gitSSHKeySource") }
    var gitSignatureName: DefaultsKey<String?> { .init("gitSignatureName") }
    var gitSignatureEmail: DefaultsKey<String?> { .init("gitSignatureEmail") }

    var lastSyncedTime: DefaultsKey<Date?> { .init("lastSyncedTime") }

    var isTouchIDOn: DefaultsKey<Bool> { .init("isTouchIDOn", defaultValue: false) }

    var isHideUnknownOn: DefaultsKey<Bool> { .init("isHideUnknownOn", defaultValue: false) }
    var isHideOTPOn: DefaultsKey<Bool> { .init("isHideOTPOn", defaultValue: false) }
    var isRememberPGPPassphraseOn: DefaultsKey<Bool> { .init("isRememberPGPPassphraseOn", defaultValue: false) }
    var isRememberGitCredentialPassphraseOn: DefaultsKey<Bool> { .init("isRememberGitCredentialPassphraseOn", defaultValue: false) }
    var isShowFolderOn: DefaultsKey<Bool> { .init("isShowFolderOn", defaultValue: true) }
    var isHidePasswordImagesOn: DefaultsKey<Bool> { .init("isHidePasswordImagesOn", defaultValue: false) }
    var searchDefault: DefaultsKey<SearchBarScope?> { .init("searchDefault", defaultValue: .all) }
    var passwordGeneratorFlavor: DefaultsKey<String> { .init("passwordGeneratorFlavor", defaultValue: "Apple") }

    var encryptInArmored: DefaultsKey<Bool> { .init("encryptInArmored", defaultValue: false) }
}
