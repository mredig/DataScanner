import Foundation

public struct BinaryToMemory<MagicNumbers: MagicNumber, Flags: PartFlags> {
	public var topPart: EncodedPart<MagicNumbers, Flags>

	public init(data: Data, magicNumbersType: MagicNumbers.Type, flagsType: Flags.Type) throws {
		self.topPart = try EncodedPart(decoding: data, magicNumbersType: magicNumbersType, flagsType: flagsType)
	}
}
