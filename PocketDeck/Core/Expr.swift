import Foundation

enum ExprError: Error {
    case syntax
    case divideByZero

    var message: String {
        switch self {
        case .syntax: return "语法错误"
        case .divideByZero: return "不能除以 0"
        }
    }
}

/// 计算器内核：递归下降，不用 NSExpression
enum Expr {

    static func evaluate(_ input: String) throws -> Double {
        let chars = Array(input
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ""))
        var index = 0

        func peek() -> Character? {
            index < chars.count ? chars[index] : nil
        }

        func parseExpr() throws -> Double {
            var value = try parseTerm()
            while let c = peek(), c == "+" || c == "-" {
                index += 1
                let rhs = try parseTerm()
                value = c == "+" ? value + rhs : value - rhs
            }
            return value
        }

        func parseTerm() throws -> Double {
            var value = try parseFactor()
            while let c = peek(), c == "*" || c == "/" {
                index += 1
                let rhs = try parseFactor()
                if c == "/" && rhs == 0 { throw ExprError.divideByZero }
                value = c == "*" ? value * rhs : value / rhs
            }
            return value
        }

        func parseFactor() throws -> Double {
            if let c = peek(), c == "-" {
                index += 1
                return -(try parseFactor())
            }
            if let c = peek(), c == "+" {
                index += 1
                return try parseFactor()
            }
            if let c = peek(), c == "(" {
                index += 1
                let value = try parseExpr()
                guard let close = peek(), close == ")" else { throw ExprError.syntax }
                index += 1
                return value
            }
            let start = index
            while let c = peek(), c.isNumber || c == "." {
                index += 1
            }
            guard start != index else { throw ExprError.syntax }
            let chunk = String(chars[start..<index])
            guard let value = Double(chunk) else { throw ExprError.syntax }
            return value
        }

        guard !chars.isEmpty else { throw ExprError.syntax }
        let result = try parseExpr()
        guard index == chars.count else { throw ExprError.syntax }
        return result
    }

    static func format(_ value: Double) -> String {
        if !value.isFinite { return "错误" }
        if abs(value) >= 1e15 { return String(format: "%.6e", value) }
        let rounded = (value * 1e10).rounded() / 1e10
        if rounded == rounded.rounded() && abs(rounded) < 1e15 {
            return String(format: "%.0f", rounded)
        }
        return String(rounded)
    }
}
