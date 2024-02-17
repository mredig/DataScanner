import Foundation

public struct BinaryFromMemory<MagicNumbers: MagicNumber, Flags: PartFlags> {
	public typealias Part = EncodedPart<MagicNumbers, Flags>
	public var parts: [Part] = []

	public init() {}
}

public extension BinaryFromMemory {
	mutating func encodePart(_ part: Part) {
		parts.append(part)
	}

	mutating func encodeData(_ data: Data, magicNumber: MagicNumbers, flags: Flags = []) {
		let part = EncodedPart(key: magicNumber, flags: flags, value: .data(data))
		encodePart(part)
	}
}
