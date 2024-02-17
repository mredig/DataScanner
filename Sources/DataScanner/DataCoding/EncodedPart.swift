import Foundation

public struct EncodedPart<MagicNumbers: MagicNumber, Flags: PartFlags> {
	public let key: MagicNumbers
	public let flags: Flags
	/// byte count of just data
	public var dataSize: Int { value.count }
	/// byte count of key + size + data
	public var totalSize: Int {
		dataSize + MemoryLayout.size(ofValue: key.rawValue) + MemoryLayout.size(ofValue: dataSize) + MemoryLayout.size(ofValue: flags)
	}
	public let value: PartValue

	public var data: Data { value.data }
	public var childParts: [EncodedPart] { value.childParts }

	public init(key: MagicNumbers, flags: Flags, value: PartValue) {
		self.key = key
		self.flags = flags
		self.value = value
	}

	public enum Error: Swift.Error {
		case invalidMagicNumber(UInt32, MagicNumbers.Type)
		case insufficientData
		case corruptedData
	}

	public struct HeaderData {
		public let magicNumber: MagicNumbers
		public let flags: Flags
		public let size: Int
		public let dataOffset: Int

		var hasChildren: Bool {
			flags.contains(Flags.hasChildParts)
		}
	}

	public static func retrieveHeader(from data: Data, ignoreExtraData: Bool = false) throws -> HeaderData {
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
			let magicNumber = MagicNumbers(rawValue: magicBytes)
		else { throw Error.invalidMagicNumber(magicBytes, MagicNumbers.self) }

		let dataSize: Int = try scanner.scan(endianness: .big)
		if ignoreExtraData == false {
			guard
				data.count - headerSize == dataSize
			else { throw Error.corruptedData }
		}

		let rawFlag: Flags.RawValue = try scanner.scan(endianness: .big)
		let flags = Flags(rawValue: rawFlag)

		let header = HeaderData(magicNumber: magicNumber, flags: flags, size: dataSize, dataOffset: scanner.currentOffset)
		return header
	}

	public init(decoding data: Data, magicNumbersType: MagicNumbers.Type, flagsType: Flags.Type) throws {
		let header = try Self.retrieveHeader(from: data)
		try self.init(decoding: data, header: header)
	}

	private init(decoding data: Data, header: HeaderData) throws {
		let remainingData = data[header.dataOffset..<data.endIndex]

		let value: PartValue
		if header.hasChildren {
			var parts: [EncodedPart] = []
			var remainingData = remainingData
			while remainingData.isOccupied {
				let partHeader = try Self.retrieveHeader(from: remainingData, ignoreExtraData: true)
				let partEndOffset = remainingData.index(partHeader.dataOffset, offsetBy: partHeader.size)
				let partData = remainingData[partHeader.dataOffset..<partEndOffset]
				try parts.append(EncodedPart(decoding: partData, header: partHeader))
				remainingData = remainingData[partEndOffset..<data.endIndex]
			}
			value = .parts(parts)
		} else {
			value = .data(remainingData)
		}

		self.init(key: header.magicNumber, flags: header.flags, value: value)
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

		public var childParts: [EncodedPart] {
			switch self {
			case .data:
				[]
			case .parts(let array):
				array
			}
		}

		case data(Data)
		case parts([EncodedPart])
	}
}
