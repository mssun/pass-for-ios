//
//  KeyFileManagerTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 01.07.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class KeyFileManagerTest: XCTestCase {
    private static let filePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.txt").path
    private static let keyFileManager = KeyFileManager(keyType: .PUBLIC, keyPath: filePath) { _, _ in }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: KeyFileManagerTest.filePath)
        super.tearDown()
    }

    func testImportKeyAndDeleteFile() throws {
        let fileContent = "content".data(using: .ascii)
        var storage: [String: Data] = [:]
        let keyFileManager = KeyFileManager(keyType: .PRIVATE, keyPath: KeyFileManagerTest.filePath) { storage[$1] = $0 }

        FileManager.default.createFile(atPath: KeyFileManagerTest.filePath, contents: fileContent, attributes: nil)
        try keyFileManager.importKeyAndDeleteFile()

        XCTAssertFalse(FileManager.default.fileExists(atPath: KeyFileManagerTest.filePath))
        XCTAssertTrue(storage[PgpKeyType.PRIVATE.getKeychainKey()] == fileContent)
    }

    func testErrorReadingFile() throws {
        XCTAssertThrowsError(try KeyFileManagerTest.keyFileManager.importKeyAndDeleteFile()) {
            XCTAssertEqual($0 as! AppError, AppError.ReadingFile("test.txt"))
        }
    }

    func testFileExists() {
        FileManager.default.createFile(atPath: KeyFileManagerTest.filePath, contents: nil, attributes: nil)

        XCTAssertTrue(KeyFileManagerTest.keyFileManager.doesKeyFileExist())
    }

    func testFileDoesNotExist() {
        XCTAssertFalse(KeyFileManagerTest.keyFileManager.doesKeyFileExist())
    }
}
