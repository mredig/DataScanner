import Foundation

public class BinaryDecoder {
	public init() {}

	public func decode<T: BinaryDecodable>(type: T.Type = T.self, from data: Data, topKey: T.MagicNumbers) throws -> T {
		let binaryStupidName = try BinaryToMemory(data: data, topKey: topKey, flagsType: T.Flags.self)
		let new = try T(from: binaryStupidName)
		return new
	}
}

public class BinaryEncoder {
	public init() {}

	public func encode<T: BinaryEncodable>(_ encodable: T, topKey: T.MagicNumbers) throws -> Data {
		var binaryStupidNameThing = BinaryFromMemory<T.MagicNumbers, T.Flags>(topKey: topKey)
		try encodable.encodeToBinaryData(&binaryStupidNameThing)
		return binaryStupidNameThing.renderData()
	}
}
