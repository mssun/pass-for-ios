//
//  OtpTypeTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 01.12.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import OneTimePassword
import XCTest

@testable import passKit

class OtpTypeTest: XCTestCase {

    func testInitFromToken() {
        let secret = "secret".data(using: .utf8)!

        let totpGenerator = Generator(factor: .timer(period: 30.0), secret: secret, algorithm: .sha1, digits: 6)!
        let totpToken = Token(name: "", issuer: "", generator: totpGenerator)
        XCTAssertEqual(OtpType(token: totpToken), .totp)

        let hotpGenerator = Generator(factor: .counter(4), secret: secret, algorithm: .sha1, digits: 6)!
        let hotpToken = Token(name: "", issuer: "", generator: hotpGenerator)
        XCTAssertEqual(OtpType(token: hotpToken), .hotp)

        XCTAssertEqual(OtpType(token: nil), .none)
    }

    func testInitFromString() {
        XCTAssertEqual(OtpType(name: "totp"), .totp)
        XCTAssertEqual(OtpType(name: "tOtP"), .totp)
        XCTAssertEqual(OtpType(name: "hotp"), .hotp)
        XCTAssertEqual(OtpType(name: "HoTp"), .hotp)
        XCTAssertEqual(OtpType(name: nil), .none)
        XCTAssertEqual(OtpType(name: ""), .none)
        XCTAssertEqual(OtpType(name: "something"), .none)
    }

    func testDescription() {
        XCTAssertEqual(OtpType(name: "totp").description, "time-based")
        XCTAssertEqual(OtpType(name: "hotp").description, "HMAC-based")
        XCTAssertEqual(OtpType(name: nil).description, "none")
    }
}
