//
//  CryptoFrameworkTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 22.08.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import XCTest

// swiftformat:disable:next sortedImports
@testable import passKit
@testable import Gopenpgp

class CryptoFrameworkTest: XCTestCase {
    private typealias MessageConverter = (CryptoPGPMessage, NSErrorPointer) -> CryptoPGPMessage?

    private let testText = "Hello World!"

    func testArmoredEncryptDecrypt() throws {
        let plainMessage = CryptoNewPlainMessageFromString(testText)
        let messageConverter: MessageConverter = { encryptedMessage, error in
            CryptoNewPGPMessageFromArmored(encryptedMessage.getArmored(error), error)
        }

        try testInternal(plainMessage: plainMessage, messageConverter: messageConverter)
    }

    func testDataBasedEncryptDecrypt() throws {
        let plainMessage = CryptoNewPlainMessage(testText.data(using: .utf8)!.mutable as Data)
        let messageConverter: MessageConverter = { encryptedMessage, _ in
            CryptoNewPGPMessage(encryptedMessage.getBinary()!.mutable as Data)
        }

        try testInternal(plainMessage: plainMessage, messageConverter: messageConverter)
    }

    private func testInternal(plainMessage: CryptoPlainMessage?, messageConverter: MessageConverter) throws {
        try [
            RSA2048,
            RSA2048_SUB,
            RSA3072_NO_PASSPHRASE,
            RSA4096,
            RSA4096_SUB,
            ED25519,
            ED25519_SUB,
            NISTP384,
        ].forEach { testKeyInfo in
            var error: NSError?
            guard let publicKey = CryptoNewKeyFromArmored(testKeyInfo.publicKey, &error),
                  let privateKey = CryptoNewKeyFromArmored(testKeyInfo.privateKey, &error) else {
                XCTFail("Keys cannot be initialized.")
                return
            }
            XCTAssertNil(error)
            XCTAssert(publicKey.getHexKeyID().hasSuffix(testKeyInfo.fingerprint))
            XCTAssertNil(error)

            var isLocked: ObjCBool = false
            try privateKey.isLocked(&isLocked)
            var unlockedKey: CryptoKey!
            if isLocked.boolValue {
                unlockedKey = try privateKey.unlock(testKeyInfo.passphrase.data(using: .utf8))
            } else {
                unlockedKey = privateKey
            }
            let encryptedMessage = try CryptoNewKeyRing(publicKey, &error)?.encrypt(plainMessage, privateKey: nil)
            let decryptedData = try CryptoNewKeyRing(unlockedKey, &error)?.decrypt(messageConverter(encryptedMessage!, &error), verifyKey: nil, verifyTime: 0)
            XCTAssertNil(error)
            XCTAssertEqual(testText, decryptedData!.getString())
        }
    }
}
