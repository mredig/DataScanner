import Foundation

public struct BinaryEncoder<MagicNumber: BinaryCodingKey, Flags: PartFlags> {
	public typealias Part = EncodedPart<MagicNumber, Flags>
	public var parts: [Part] = []

	public init() {}
}

public extension BinaryEncoder {
	mutating func encodePart(_ part: Part) {
		parts.append(part)
	}

	mutating func encodeData(_ data: Data, magicNumber: MagicNumber, flags: Flags = []) {
		let part = EncodedPart(key: magicNumber, flags: flags, value: .data(data))
		encodePart(part)
	}
}
