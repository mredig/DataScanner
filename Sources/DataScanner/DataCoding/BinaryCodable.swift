import Foundation

public protocol BinaryDecodable {
	associatedtype MagicNumbers: MagicNumber
	associatedtype Flags: PartFlags

	var rootKey: MagicNumbers { get }

	init(from binaryDecoder: BinaryDecodingContainer<MagicNumbers, Flags>) throws
}

public protocol BinaryEncodable {
	associatedtype MagicNumbers: MagicNumber
	associatedtype Flags: PartFlags

	var rootKey: MagicNumbers { get }

	func encodeToBinaryData(_ coder: inout BinaryEncodingContainer<MagicNumbers, Flags>) throws
}

public protocol BinaryCodable: BinaryEncodable & BinaryDecodable {}
