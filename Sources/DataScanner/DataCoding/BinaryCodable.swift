import Foundation

/// Currently, implementation is nearly entirely manual. This probably won't change, but it isn't very different from `Codable`.
/// Follow compiler prompts for protocol conformance. However, some limitations are that the the entire blob, embedded chunks
/// and all, must use the same PartFlag type. If that doesn't provide enough flags, you could have flags mean one thing on one
/// chunk, and another on different chunks. Otherwise, this just might not be the package for you.
///
/// The ordering of encoding and decoding is critical to be the same.
public protocol BinaryDecodable {
	associatedtype MagicNumbers: MagicNumber
	associatedtype Flags: PartFlags

	var rootKey: MagicNumbers { get }

	init(from binaryDecoder: BinaryDecodingContainer<MagicNumbers, Flags>) throws
}

/// Currently, implementation is nearly entirely manual. This probably won't change, but it isn't very different from `Codable`.
/// Follow compiler prompts for protocol conformance. However, some limitations are that the the entire blob, embedded chunks
/// and all, must use the same PartFlag type. If that doesn't provide enough flags, you could have flags mean one thing on one
/// chunk, and another on different chunks. Otherwise, this just might not be the package for you.
///
/// The ordering of encoding and decoding is critical to be the same.
public protocol BinaryEncodable {
	associatedtype MagicNumbers: MagicNumber
	associatedtype Flags: PartFlags

	var rootKey: MagicNumbers { get }

	func encodeToBinaryData(_ coder: inout BinaryEncodingContainer<MagicNumbers, Flags>) throws
}

public protocol BinaryCodable: BinaryEncodable & BinaryDecodable {}
