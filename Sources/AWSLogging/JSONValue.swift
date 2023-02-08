// Adapted from https://github.com/swift-extras/swift-extras-json/blob/main/Sources/ExtrasJSON/JSONValue.swift

internal enum JSONValue {
    case string(String)
    case number(String)
    
    case object([(String, JSONValue)])
}

extension JSONValue {
    // minimal JSON serialization required for log entries
    public func appendBytes(identBy: Int = 1, to bytes: inout [UInt8]) {
        switch self {
        case .string(let string):
            self.encodeString(string, to: &bytes)
        case .number(let string):
            bytes.append(contentsOf: string.utf8)
        case .object(let array):
            var iterator = array.makeIterator()
            bytes.append(UInt8(ascii: "{"))
            bytes.append(UInt8(ascii: "\n"))
            if let (key, value) = iterator.next() {
                self.indent(by: identBy, to: &bytes)
                self.encodeString(key, to: &bytes)
                bytes.append(UInt8(ascii: ":"))
                bytes.append(UInt8(ascii: " "))
                value.appendBytes(identBy: identBy + 1, to: &bytes)
            }
            while let (key, value) = iterator.next() {
                bytes.append(UInt8(ascii: ","))
                bytes.append(UInt8(ascii: "\n"))
                self.indent(by: identBy, to: &bytes)
                self.encodeString(key, to: &bytes)
                bytes.append(UInt8(ascii: ":"))
                bytes.append(UInt8(ascii: " "))
                value.appendBytes(identBy: identBy + 1, to: &bytes)
            }
            bytes.append(UInt8(ascii: "\n"))
            bytes.append(UInt8(ascii: "}"))
        }
    }
    
    private func indent(by: Int, to bytes: inout [UInt8]) {
        let indentCount = 4 * by
        (0..<indentCount).forEach { _ in
            bytes.append(UInt8(ascii: " "))
        }
    }

    private func encodeString(_ string: String, to bytes: inout [UInt8]) {
        bytes.append(UInt8(ascii: "\""))
        let stringBytes = string.utf8
        var startCopyIndex = stringBytes.startIndex
        var nextIndex = startCopyIndex

        while nextIndex != stringBytes.endIndex {
            switch stringBytes[nextIndex] {
            case 0 ..< 32, UInt8(ascii: "\""), UInt8(ascii: "\\"):
                // All Unicode characters may be placed within the
                // quotation marks, except for the characters that MUST be escaped:
                // quotation mark, reverse solidus, and the control characters (U+0000
                // through U+001F).
                // https://tools.ietf.org/html/rfc8259#section-7
                // copy the current range over
                bytes.append(contentsOf: stringBytes[startCopyIndex ..< nextIndex])
                switch stringBytes[nextIndex] {
                case UInt8(ascii: "\""): // quotation mark
                    bytes.append(UInt8(ascii: "\\"))
                    bytes.append(UInt8(ascii: "\""))
                case UInt8(ascii: "\\"): // reverse solidus
                    bytes.append(UInt8(ascii: "\\"))
                    bytes.append(UInt8(ascii: "\\"))
                case 0x08: // backspace
                    bytes.append(UInt8(ascii: "\\"))
                    bytes.append(UInt8(ascii: "b"))
                case 0x0C: // form feed
                    bytes.append(UInt8(ascii: "\\"))
                    bytes.append(UInt8(ascii: "f"))
                case 0x0A: // line feed
                    bytes.append(UInt8(ascii: "\\"))
                    bytes.append(UInt8(ascii: "n"))
                case 0x0D: // carriage return
                    bytes.append(UInt8(ascii: "\\"))
                    bytes.append(UInt8(ascii: "r"))
                case 0x09: // tab
                    bytes.append(UInt8(ascii: "\\"))
                    bytes.append(UInt8(ascii: "t"))
                default:
                    func valueToAscii(_ value: UInt8) -> UInt8 {
                        switch value {
                        case 0 ... 9:
                            return value + UInt8(ascii: "0")
                        case 10 ... 15:
                            return value - 10 + UInt8(ascii: "A")
                        default:
                            preconditionFailure()
                        }
                    }
                    bytes.append(UInt8(ascii: "\\"))
                    bytes.append(UInt8(ascii: "u"))
                    bytes.append(UInt8(ascii: "0"))
                    bytes.append(UInt8(ascii: "0"))
                    let first = stringBytes[nextIndex] / 16
                    let remaining = stringBytes[nextIndex] % 16
                    bytes.append(valueToAscii(first))
                    bytes.append(valueToAscii(remaining))
                }

                nextIndex = stringBytes.index(after: nextIndex)
                startCopyIndex = nextIndex
            default:
                nextIndex = stringBytes.index(after: nextIndex)
            }
        }

        // copy everything, that hasn't been copied yet
        bytes.append(contentsOf: stringBytes[startCopyIndex ..< nextIndex])
        bytes.append(UInt8(ascii: "\""))
    }
}
