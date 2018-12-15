//
//  AdditionField.swift
//  passKit
//
//  Created by Danny Moesch on 30.09.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

public struct AdditionField: Hashable {

    public let title: String, content: String

    public init(title: String = "", content: String = "") {
        self.title = title
        self.content = content
    }

    var asString: String {
        return title.isEmpty ? content : title + ": " + content
    }

    var asTuple: (String, String) {
        return (title, content)
    }
}

extension AdditionField {

    static func | (left: String, right: AdditionField) -> String {
        return left | right.asString
    }

    static func | (left: AdditionField, right: String) -> String {
        return left.asString | right
    }

    static func | (left: AdditionField, right: AdditionField) -> String {
        return left.asString | right
    }
}

extension AdditionField: Equatable {

    public static func == (first: AdditionField, second: AdditionField) -> Bool {
        return first.asTuple == second.asTuple
    }
}

infix operator =>: MultiplicationPrecedence
public func => (key: String, value: String) -> AdditionField {
    return AdditionField(title: key, content: value)
}
