import Foundation

public struct EncodedPart<MagicNumber: BinaryCodingKey, Flags: PartFlags> {
	public let key: MagicNumber
	public let flags: Flags
	/// byte count of just data
	public var dataSize: Int { value.count }
	/// byte count of key + size + data
	public var totalSize: Int {
		dataSize + MemoryLayout.size(ofValue: key.rawValue) + MemoryLayout.size(ofValue: dataSize) + MemoryLayout.size(ofValue: flags)
	}
	public let value: PartValue

	public init(key: MagicNumber, flags: Flags, value: PartValue) {
		self.key = key
		self.flags = flags
		self.value = value
	}

	public enum Error: Swift.Error {
		case invalidMagicNumber(UInt32, MagicNumber.Type)
		case insufficientData
		case corruptedData
	}

	public struct HeaderData {
		public let magicNumber: MagicNumber
		public let flags: Flags
		public let size: Int
		public let dataOffset: Int

		var hasChildren: Bool {
			flags.contains(Flags.hasChildParts)
		}
	}

	public static func retrieveHeader(from data: Data) throws -> HeaderData {
		let magicNumSize = 4
		let sizeSize = MemoryLayout.size(ofValue: data.count)
		let flagSize = MemoryLayout<Flags>.size
		let headerSize = magicNumSize + sizeSize + flagSize

		guard
			data.count > headerSize
		else { throw Error.insufficientData }

		var scanner = DataScanner(data: data)

		let magicBytes: UInt32 = try scanner.scan(endianness: .big)
		guard
			let magicNumber = MagicNumber(rawValue: magicBytes)
		else { throw Error.invalidMagicNumber(magicBytes, MagicNumber.self) }

		let dataSize: Int = try scanner.scan(endianness: .big)
		guard
			data.count - headerSize == dataSize
		else { throw Error.corruptedData }

		let rawFlag: Flags.RawValue = try scanner.scan(endianness: .big)
		let flags = Flags(rawValue: rawFlag)

		let header = HeaderData(magicNumber: magicNumber, flags: flags, size: dataSize, dataOffset: scanner.currentOffset)
		return header
	}

	public init(decoding data: Data, magicNumber: MagicNumber.Type, flag: Flags.Type) throws {
		let header = try Self.retrieveHeader(from: data)
		let remainingData = data[header.dataOffset..<data.endIndex]


		self.init(key: header.magicNumber, flags: header.flags, value: .data(remainingData))
	}

	public func renderData() -> Data {
		var new = Data(capacity: totalSize)
		new.append(contentsOf: key.rawValue.toBytes(endianness: .big))
		new.append(contentsOf: dataSize.toBytes(endianness: .big))
		var flags = self.flags
		if case .parts = value {
			flags.insert(Flags.hasChildParts)
		} else {
			flags.remove(Flags.hasChildParts)
		}
		new.append(flags.rawValue.toBytes(endianness: .big))
		new.append(contentsOf: value.data)
		return new
	}

	public enum PartValue {
		public var count: Int {
			switch self {
			case .data(let data):
				data.count
			case .parts(let parts):
				parts.reduce(0, { $0 + $1.totalSize })
			}
		}

		public var data: Data {
			switch self {
			case .data(let data):
				data
			case .parts(let array):
				array.reduce(into: Data(capacity: count), { $0.append(contentsOf: $1.renderData()) })
			}
		}

		case data(Data)
		case parts([EncodedPart])
	}
}
