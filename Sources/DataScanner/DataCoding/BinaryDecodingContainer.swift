import Foundation

public struct BinaryDecodingContainer<MagicNumbers: MagicNumber, Flags: PartFlags> {
	public var rootPart: EncodedPart<MagicNumbers, Flags>
	public let rootKey: MagicNumbers

	public init(data: Data, topKey: MagicNumbers, flagsType: Flags.Type) throws {
		self.rootKey = topKey
		let header = try EncodedPart<MagicNumbers, Flags>.retrieveHeader(from: data)
		guard header.magicNumber == topKey else { throw Error.rootKeyMismatch }
		self.rootPart = try EncodedPart(decoding: data, header: header)
	}

	public enum Error: Swift.Error {
		case rootKeyMismatch
	}
}
