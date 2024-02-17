import Foundation

public struct BinaryToMemory<MagicNumbers: MagicNumber, Flags: PartFlags> {
	public var topPart: EncodedPart<MagicNumbers, Flags>
	public let topKey: MagicNumbers

	public init(data: Data, topKey: MagicNumbers, flagsType: Flags.Type) throws {
		self.topKey = topKey
		let header = try EncodedPart<MagicNumbers, Flags>.retrieveHeader(from: data)
		guard header.magicNumber == topKey else { throw Error.rootKeyMismatch }
		self.topPart = try EncodedPart(decoding: data, header: header)
	}

	public enum Error: Swift.Error {
		case rootKeyMismatch
	}
}
