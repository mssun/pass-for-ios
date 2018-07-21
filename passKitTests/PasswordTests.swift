//
//  PasswordTests.swift
//  passKitTests
//
//  Created by Danny Mösch on 02.05.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import XCTest
@testable import passKit

class PasswordTest: XCTestCase {
    static let EMPTY_STRING = ""
    static let PASSWORD_NAME = "password"
    static let PASSWORD_PATH = "/path/to/\(PASSWORD_NAME)"
    static let PASSWORD_URL = URL(fileURLWithPath: PASSWORD_PATH)
    static let PASSWORD_STRING = "abcd1234"
    static let OTP_TOKEN = "otpauth://totp/email@email.com?secret=abcd1234"

    static let SECURE_URL_FIELD = AdditionField(title: "url", content: "https://secure.com")
    static let INSECURE_URL_FIELD = AdditionField(title: "url", content: "http://insecure.com")
    static let LOGIN_FIELD = AdditionField(title: "login", content: "login name")
    static let USERNAME_FIELD = AdditionField(title: "username", content: "some username")
    static let NOTE_FIELD = AdditionField(title: "note", content: "A NOTE")
    static let HINT_FIELD = AdditionField(title: "some hints", content: "äöüß // €³ %% −° && @²` | [{\\}],.<>")

    func testUrl() {
        let password1 = getPasswordObjectWith(content: PasswordTest.EMPTY_STRING)
        XCTAssertEqual(password1.namePath, PasswordTest.PASSWORD_PATH)

        let password2 = getPasswordObjectWith(content: PasswordTest.EMPTY_STRING, url: nil)
        XCTAssertEqual(password2.namePath, PasswordTest.EMPTY_STRING)
    }

    func testLooksLikeOTP() {
        XCTAssertTrue(Password.LooksLikeOTP(line: PasswordTest.OTP_TOKEN))
        XCTAssertFalse(Password.LooksLikeOTP(line: "no_auth://totp/blabla"))
    }

    func testEmptyFile() {
        let fileContent = PasswordTest.EMPTY_STRING
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PasswordTest.EMPTY_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), PasswordTest.EMPTY_STRING)
        XCTAssertTrue(password.getFilteredAdditions().isEmpty)

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertNil(password.login)
    }

    func testOneEmptyLine() {
        let fileContent = """

            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PasswordTest.EMPTY_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), PasswordTest.EMPTY_STRING)
        XCTAssertTrue(password.getFilteredAdditions().isEmpty)

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertNil(password.login)
    }

    func testSimplePasswordFile() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let urlField = PasswordTest.SECURE_URL_FIELD
        let loginField = PasswordTest.LOGIN_FIELD
        let usernameField = PasswordTest.USERNAME_FIELD
        let noteField = PasswordTest.NOTE_FIELD
        let fileContent = """
            \(passwordString)
            \(urlField.asString)
            \(loginField.asString)
            \(usernameField.asString)
            \(noteField.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(urlField, loginField, usernameField, noteField))
        XCTAssertTrue(does(password, contain: urlField))
        XCTAssertFalse(does(password, contain: loginField))
        XCTAssertFalse(does(password, contain: usernameField))
        XCTAssertTrue(does(password, contain: noteField))

        XCTAssertEqual(password.urlString, urlField.content)
        XCTAssertEqual(password.login, loginField.content)
        XCTAssertEqual(password.username, usernameField.content)
    }

    func testTwoPasswords() {
        let firstPasswordString = PasswordTest.PASSWORD_STRING
        let secondPasswordString = "efgh5678"
        let urlField = PasswordTest.INSECURE_URL_FIELD
        let fileContent = """
            \(firstPasswordString)
            \(secondPasswordString)
            \(urlField.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, firstPasswordString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(secondPasswordString, urlField.asString))

        XCTAssertTrue(does(password, contain: urlField))
        XCTAssertTrue(does(password, contain: AdditionField(title: "unknown 1", content: secondPasswordString)))

        XCTAssertNil(password.username)
        XCTAssertEqual(password.urlString, urlField.content)
        XCTAssertNil(password.login)
    }

    func testNoPassword() {
        let urlField = PasswordTest.SECURE_URL_FIELD
        let noteField = PasswordTest.NOTE_FIELD
        let fileContent = """
            \(urlField.asString)
            \(noteField.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, urlField.asString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(noteField))
        XCTAssertTrue(does(password, contain: noteField))

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertNil(password.login)
    }

    func testDuplicateKeys() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let urlField1 = PasswordTest.SECURE_URL_FIELD
        let urlField2 = PasswordTest.INSECURE_URL_FIELD
        let fileContent = """
            \(passwordString)
            \(urlField1.asString)
            \(urlField2.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(urlField1, urlField2))
        XCTAssertTrue(does(password, contain: urlField1))
        XCTAssertTrue(does(password, contain: urlField2))

        XCTAssertNil(password.username)
        XCTAssertEqual(password.urlString, urlField1.content)
        XCTAssertNil(password.login)
    }

    func testUnknownKeys() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let value1 = "value 1"
        let value2 = "value 2"
        let value3 = "value 3"
        let value4 = "value 4"
        let noteField = PasswordTest.NOTE_FIELD
        let urlField = PasswordTest.SECURE_URL_FIELD
        let fileContent = """
            \(passwordString)
            \(value1)
            \(noteField.asString)
            \(value2)
            \(value3)
            \(urlField.asString)
            \(value4)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(value1, noteField.asString, value2, value3, urlField.asString, value4))
        XCTAssertTrue(does(password, contain: AdditionField(title: "unknown 1", content: value1)))
        XCTAssertTrue(does(password, contain: noteField))
        XCTAssertTrue(does(password, contain: AdditionField(title: "unknown 2", content: value2)))
        XCTAssertTrue(does(password, contain: AdditionField(title: "unknown 3", content: value3)))
        XCTAssertTrue(does(password, contain: urlField))
        XCTAssertTrue(does(password, contain: AdditionField(title: "unknown 4", content: value4)))

        XCTAssertNil(password.username)
        XCTAssertEqual(password.urlString, urlField.content)
        XCTAssertNil(password.login)
    }

    func testPasswordFileWithOtpToken() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let noteField = PasswordTest.NOTE_FIELD
        let otpToken = PasswordTest.OTP_TOKEN
        let fileContent = """
            \(passwordString)
            \(noteField.asString)
            \(otpToken)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(noteField.asString, otpToken))

        XCTAssertEqual(password.otpType, OtpType.totp)
        XCTAssertNotNil(password.getOtp())
    }

    func testFirstLineIsOtpToken() {
        let otpToken = PasswordTest.OTP_TOKEN
        let fileContent = """
            \(otpToken)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, otpToken)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), PasswordTest.EMPTY_STRING)

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertNil(password.login)

        XCTAssertEqual(password.otpType, OtpType.totp)
        XCTAssertNotNil(password.getOtp())
    }

    func testWrongOtpToken() {
        let otpToken = "otpauth://htop/blabla"
        let fileContent = """
            \(otpToken)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, otpToken)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.otpType, OtpType.none)
        XCTAssertNil(password.getOtp())
    }

    func testEmptyMultilineValues() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let lineBreakField1 = AdditionField(title: "with line breaks", content: "| \n")
        let lineBreakField2 = AdditionField(title: "with line breaks", content: "| \n   ")
        let noteField = PasswordTest.NOTE_FIELD
        let noLineBreakField = AdditionField(title: "without line breaks", content: " >   ")
        let fileContent = """
            \(passwordString)
            \(lineBreakField1.asString)
            \(lineBreakField2.asString)
            \(noteField.asString)
            \(noLineBreakField.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(lineBreakField1, lineBreakField2, noteField, noLineBreakField))
        XCTAssertTrue(does(password, contain: AdditionField(title: lineBreakField1.title, content: "")))
        XCTAssertTrue(does(password, contain: AdditionField(title: lineBreakField2.title, content: "")))
        XCTAssertTrue(does(password, contain: noteField))
        XCTAssertTrue(does(password, contain: AdditionField(title: noLineBreakField.title, content: "")))
    }

    func testMultilineValues() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let noteField = PasswordTest.NOTE_FIELD
        let lineBreakField = AdditionField(title: "with line breaks", content: "|\n  This is \n   text spread over \n  multiple lines!  ")
        let noLineBreakField = AdditionField(title: "without line breaks", content: " > \n This is \n  text spread over\n   multiple lines!")
        let fileContent = """
            \(passwordString)
            \(lineBreakField.asString)
            \(noteField.asString)
            \(noLineBreakField.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(lineBreakField, noteField, noLineBreakField))
        XCTAssertTrue(does(password, contain: AdditionField(title: lineBreakField.title, content: "This is \n text spread over \nmultiple lines!")))
        XCTAssertTrue(does(password, contain: noteField))
        XCTAssertTrue(does(password, contain: AdditionField(title: noLineBreakField.title, content: "This is   text spread over   multiple lines!")))
    }
    
    func testMultilineValuesMixed() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let hintField = PasswordTest.HINT_FIELD
        let noteField = PasswordTest.NOTE_FIELD
        let lineBreakField = AdditionField(title: "with line breaks", content: "|\n  This is \n  \(hintField.asString) spread over\n multiple lines!")
        let noLineBreakField = AdditionField(title: "without line breaks", content: " > \n This is \n | \n text spread over\nmultiple lines!")
        let fileContent = """
            \(passwordString)
            \(lineBreakField.asString)
            \(noLineBreakField.asString)
            \(noteField.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)
        
        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        
        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(lineBreakField, noLineBreakField, noteField))
        XCTAssertTrue(does(password, contain: AdditionField(title: lineBreakField.title, content: "This is \n\(hintField.asString) spread over")))
        XCTAssertTrue(does(password, contain: AdditionField(title: "unknown 1", content: " multiple lines!")))
        XCTAssertTrue(does(password, contain: AdditionField(title: noLineBreakField.title, content: "This is  |  text spread over")))
        XCTAssertTrue(does(password, contain: AdditionField(title: "unknown 2", content: "multiple lines!")))
        XCTAssertTrue(does(password, contain: noteField))
    }

    private func getPasswordObjectWith(content: String, url: URL? = PasswordTest.PASSWORD_URL) -> Password {
        return Password(name: PasswordTest.PASSWORD_NAME, url: url, plainText: content)
    }

    private func does(_ password: Password, contain field: AdditionField) -> Bool {
        return password.getFilteredAdditions().contains(field)
    }

    private func asPlainText(_ strings: String...) -> String {
        return strings.joined(separator: "\n")
    }
    private func asPlainText(_ fields: AdditionField...) -> String {
        return fields.map { $0.asString }.joined(separator: "\n")
    }
}
