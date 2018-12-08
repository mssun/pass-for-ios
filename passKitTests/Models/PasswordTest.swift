//
//  PasswordTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 02.05.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class PasswordTest: XCTestCase {

    func testUrl() {
        let password = getPasswordObjectWith(content: "")
        XCTAssertEqual(password.url, PASSWORD_URL)
        XCTAssertEqual(password.namePath, PASSWORD_PATH)
    }

    func testEmptyFile() {
        [
            "",
            "\n",
        ].forEach { fileContent in
            let password = getPasswordObjectWith(content: fileContent)

            XCTAssertEqual(password.password, "")
            XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

            XCTAssertEqual(password.additionsPlainText, "")
            XCTAssertTrue(password.getFilteredAdditions().isEmpty)

            XCTAssertNil(password.username)
            XCTAssertNil(password.urlString)
            XCTAssertNil(password.login)
        }
    }

    func testEmptyPassword() {
        let fileContent = "\n\(LOGIN_FIELD.asString)"
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, "")
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, LOGIN_FIELD.asString)

        XCTAssertFalse(does(password, contain: LOGIN_FIELD))

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertEqual(password.login, LOGIN_FIELD.content)
    }

    func testSimplePasswordFile() {
        let additions = SECURE_URL_FIELD | LOGIN_FIELD | USERNAME_FIELD | NOTE_FIELD
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertTrue(does(password, contain: SECURE_URL_FIELD))
        XCTAssertFalse(does(password, contain: LOGIN_FIELD))
        XCTAssertFalse(does(password, contain: USERNAME_FIELD))
        XCTAssertTrue(does(password, contain: NOTE_FIELD))

        XCTAssertEqual(password.urlString, SECURE_URL_FIELD.content)
        XCTAssertEqual(password.login, LOGIN_FIELD.content)
        XCTAssertEqual(password.username, USERNAME_FIELD.content)
    }

    func testTwoPasswords() {
        let additions = "efgh5678" | INSECURE_URL_FIELD
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertTrue(does(password, contain: INSECURE_URL_FIELD))
        XCTAssertTrue(does(password, contain: Constants.unknown(1) => "efgh5678"))

        XCTAssertNil(password.username)
        XCTAssertEqual(password.urlString, INSECURE_URL_FIELD.content)
        XCTAssertNil(password.login)
    }

    func testNoPassword() {
        let fileContent = SECURE_URL_FIELD | NOTE_FIELD
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, SECURE_URL_FIELD.asString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, NOTE_FIELD.asString)

        XCTAssertTrue(does(password, contain: NOTE_FIELD))

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertNil(password.login)
    }

    func testDuplicateKeys() {
        let additions = SECURE_URL_FIELD | INSECURE_URL_FIELD
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertTrue(does(password, contain: SECURE_URL_FIELD))
        XCTAssertTrue(does(password, contain: INSECURE_URL_FIELD))

        XCTAssertNil(password.username)
        XCTAssertEqual(password.urlString, SECURE_URL_FIELD.content)
        XCTAssertNil(password.login)
    }

    func testUnknownKeys() {
        let value1 = "value 1"
        let value2 = "value 2"
        let value3 = "value 3"
        let value4 = "value 4"
        let additions = value1 | NOTE_FIELD | value2 | value3 | SECURE_URL_FIELD | value4
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertTrue(does(password, contain: Constants.unknown(1) => value1))
        XCTAssertTrue(does(password, contain: NOTE_FIELD))
        XCTAssertTrue(does(password, contain: Constants.unknown(2) => value2))
        XCTAssertTrue(does(password, contain: Constants.unknown(3) => value3))
        XCTAssertTrue(does(password, contain: SECURE_URL_FIELD))
        XCTAssertTrue(does(password, contain: Constants.unknown(4) => value4))

        XCTAssertNil(password.username)
        XCTAssertEqual(password.urlString, SECURE_URL_FIELD.content)
        XCTAssertNil(password.login)
    }

    func testPasswordFileWithOtpToken() {
        let additions = NOTE_FIELD | TOTP_URL
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertEqual(password.otpType, .totp)
        XCTAssertNotNil(password.currentOtp)
    }

    func testFirstLineIsOtpToken() {
        let password = getPasswordObjectWith(content: TOTP_URL)

        XCTAssertEqual(password.password, TOTP_URL)
        XCTAssertEqual(password.plainData, TOTP_URL.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, "")

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertNil(password.login)

        XCTAssertEqual(password.otpType, .totp)
        XCTAssertNotNil(password.currentOtp)
    }

    func testOtpTokenAsField() {
        let additions = TOTP_URL_FIELD.asString
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertEqual(password.otpType, .totp)
        XCTAssertNotNil(password.currentOtp)
    }

    func testOtpTokenFromFields() {
        let additions =
            Constants.OTP_SECRET => "secret" |
            Constants.OTP_TYPE => "hotp" |
            Constants.OTP_COUNTER => "12" |
            Constants.OTP_DIGITS => "7"
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertEqual(password.otpType, .hotp)
        XCTAssertNotNil(password.currentOtp)
    }

    func testWrongOtpToken() {
        let fileContent = "otpauth://htop/blabla"
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, fileContent)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertTrue(password.additionsPlainText.isEmpty)

        XCTAssertEqual(password.otpType, OtpType.none)
        XCTAssertNil(password.currentOtp)
    }

    func testEmptyMultilineValues() {
        let lineBreakField1 = "with line breaks" => "| \n"
        let lineBreakField2 = "with line breaks" => "| \n   "
        let noLineBreakField = "without line breaks" => " >   "
        let additions = lineBreakField1 | lineBreakField2 | NOTE_FIELD | noLineBreakField
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertTrue(does(password, contain: lineBreakField1.title => ""))
        XCTAssertTrue(does(password, contain: lineBreakField2.title => ""))
        XCTAssertTrue(does(password, contain: NOTE_FIELD))
        XCTAssertTrue(does(password, contain: noLineBreakField.title => ""))
    }

    func testMultilineValues() {
        let lineBreakField = "with line breaks" => "|\n  This is \n   text spread over \n  multiple lines!  "
        let noLineBreakField = "without line breaks" => " > \n This is \n  text spread over\n   multiple lines!"
        let additions = lineBreakField | NOTE_FIELD | noLineBreakField
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertTrue(does(password, contain: lineBreakField.title => "This is \n text spread over \nmultiple lines!"))
        XCTAssertTrue(does(password, contain: NOTE_FIELD))
        XCTAssertTrue(does(password, contain: noLineBreakField.title => "This is   text spread over   multiple lines!"))
    }

    func testMultilineValuesMixed() {
        let lineBreakField = "with line breaks" => "|\n  This is \n  \(HINT_FIELD.asString) spread over\n multiple lines!"
        let noLineBreakField = "without line breaks" => " > \n This is \n | \n text spread over\nmultiple lines!"
        let additions = lineBreakField | noLineBreakField | NOTE_FIELD
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssertTrue(does(password, contain: lineBreakField.title => "This is \n\(HINT_FIELD.asString) spread over"))
        XCTAssertTrue(does(password, contain: Constants.unknown(1) => " multiple lines!"))
        XCTAssertTrue(does(password, contain: noLineBreakField.title => "This is  |  text spread over"))
        XCTAssertTrue(does(password, contain: Constants.unknown(2) => "multiple lines!"))
        XCTAssertTrue(does(password, contain: NOTE_FIELD))
    }

    func testUpdatePassword() {
        let password = getPasswordObjectWith(content: "")
        XCTAssertEqual(password.changed, 0)

        password.updatePassword(name: "password", url: PASSWORD_URL, plainText: "")
        XCTAssertEqual(password.changed, 0)

        password.updatePassword(name: "", url: PASSWORD_URL, plainText: "a")
        XCTAssertEqual(password.changed, 2)

        password.updatePassword(name: "", url: URL(fileURLWithPath: "/some/path/"), plainText: "a")
        XCTAssertEqual(password.changed, 3)

        password.updatePassword(name: "", url: PASSWORD_URL, plainText: "")
        XCTAssertEqual(password.changed, 3)
    }

    func testOtpStringsNoOtpToken() {
        let password = getPasswordObjectWith(content: "")
        let otpStrings = password.getOtpStrings()

        XCTAssertNil(otpStrings)
    }

    func testOtpStringsTotpToken() {
        let password = getPasswordObjectWith(content: TOTP_URL)
        let otpStrings = password.getOtpStrings()

        XCTAssertNotNil(otpStrings)
        XCTAssertTrue(otpStrings!.description.hasPrefix("time-based (expires in"))
    }

    func testOtpStringsHotpToken() {
        let password = getPasswordObjectWith(content: HOTP_URL)
        let otpStrings = password.getOtpStrings()

        XCTAssertNotNil(otpStrings)
        XCTAssertEqual(otpStrings!.description, "HMAC-based")
    }
}
