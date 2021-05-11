//
//  KeyFileManager.swift
//  passKit
//
//  Created by Danny Moesch on 29.06.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

public class KeyFileManager {
    public typealias KeyHandler = (String, String) -> Void

    public static let PublicPgp = KeyFileManager(keyType: PgpKey.PUBLIC)
    public static let PrivatePgp = KeyFileManager(keyType: PgpKey.PRIVATE)
    public static let PrivateSsh = KeyFileManager(keyType: SshKey.PRIVATE)

    private let keyType: CryptographicKey
    private let keyPath: String
    private let keyHandler: KeyHandler

    private convenience init(keyType: CryptographicKey) {
        self.init(keyType: keyType, keyPath: keyType.getFileSharingPath())
    }

    public init(keyType: CryptographicKey, keyPath: String, keyHandler: @escaping KeyHandler = AppKeychain.shared.add) {
        self.keyType = keyType
        self.keyPath = keyPath
        self.keyHandler = keyHandler
    }

    public func importKeyFromFileSharing() throws {
        let keyFileContent = try String(contentsOfFile: keyPath, encoding: .ascii)
        try importKey(from: keyFileContent)
        try FileManager.default.removeItem(atPath: keyPath)
    }

    public func importKey(from string: String) throws {
        guard string.unicodeScalars.allSatisfy(\.isASCII) else {
            throw AppError.encoding
        }
        keyHandler(string, keyType.getKeychainKey())
    }

    public func importKey(from url: URL) throws {
        try importKey(from: String(contentsOf: url, encoding: .ascii))
    }

    public func doesKeyFileExist() -> Bool {
        FileManager.default.fileExists(atPath: keyPath)
    }
}
