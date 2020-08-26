//
//  QRKeyScannerTest.swift
//  passTests
//
//  Created by Danny Moesch on 21.08.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import XCTest

@testable import Pass

class QRKeyScannerTest: XCTestCase {
    let header = "-----BEGIN PGP PUBLIC KEY BLOCK-----"
    let body = "key body"
    let footer = "-----END PGP PUBLIC KEY BLOCK-----"
    let privateHeader = "-----BEGIN PGP PRIVATE KEY BLOCK-----"

    var scanner = QRKeyScanner(keyType: .pgpPublic)

    func testAddHeaderTwice() {
        XCTAssertEqual(scanner.add(segment: header), .scanned(1))
        XCTAssertEqual(scanner.add(segment: header), .scanned(1))
        XCTAssertEqual(scanner.scannedKey, header)
    }

    func testAddBodyTwice() {
        XCTAssertEqual(scanner.add(segment: header), .scanned(1))
        XCTAssertEqual(scanner.add(segment: body), .scanned(2))
        XCTAssertEqual(scanner.add(segment: body), .scanned(2))
        XCTAssertEqual(scanner.scannedKey, header + body)
    }

    func testAddCompleteBlock() {
        XCTAssertEqual(scanner.add(segment: header), .scanned(1))
        XCTAssertEqual(scanner.add(segment: footer), .completed)
        XCTAssertEqual(scanner.scannedKey, header + footer)
    }

    func testCounterKeyType() {
        XCTAssertEqual(scanner.add(segment: privateHeader), .wrongKeyType(.pgpPrivate))
        XCTAssertEqual(scanner.add(segment: privateHeader), .wrongKeyType(.pgpPrivate))
        XCTAssertTrue(scanner.scannedKey.isEmpty)
    }

    func testUnknownKeyType() {
        XCTAssertEqual(scanner.add(segment: body), .lookingForStart)
        XCTAssertEqual(scanner.add(segment: body), .lookingForStart)
        XCTAssertTrue(scanner.scannedKey.isEmpty)
    }
}
