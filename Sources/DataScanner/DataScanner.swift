import Foundation

public struct DataScanner {
	public let data: Data

	public var currentOffset = 0

	public var isAtEnd: Bool { currentOffset == data.count }

	public let systemEndianness: Endianness

	public init(data: Data) {
		self.data = data
		let system = CFByteOrderGetCurrent()
		self.systemEndianness = Endianness(system) ?? .little
	}

	public enum Endianness {
		case little
		case big

		init?(_ system: __CFByteOrder) {
			switch system {
			case CFByteOrderBigEndian:
				self = .big
			case CFByteOrderLittleEndian:
				self = .little
			default: return nil
			}
		}

		init?(_ byteOrder: CFByteOrder) {
			let systemType = __CFByteOrder(UInt32(byteOrder))
			self.init(systemType)
		}
	}

	public mutating func scan<T: BinaryInteger>(endianness: Endianness = .big) throws -> T {
		let size = MemoryLayout<T>.size

		var bytes = try advanceBytes(size)
		if endianness != systemEndianness {
			bytes.reverse()
		}

		return bytes.withUnsafeBytes { pointer in
			pointer.load(as: T.self)
		}
	}

	public mutating func scan<T: BinaryFloatingPoint>(endianness: Endianness = .big) throws -> T {
		let size = MemoryLayout<T>.size

		var bytes = try advanceBytes(size)
		if endianness != systemEndianness {
			bytes.reverse()
		}

		return bytes.withUnsafeBytes { pointer in
			pointer.load(as: T.self)
		}
	}

	/// Outputs the current byte, then advances by one.
	public mutating func advanceByte() throws -> UInt8 {
		guard isAtEnd == false else { throw Error.isAtEnd }
		let byte = data[currentOffset]

		currentOffset += 1
		return byte
	}

	/// Provides each byte in a Data object. If `count` is negative, bytes start at the lower index and end
	/// at `currentIndex - 1`. `count` must keep the resulting index within the range of available data.
	public mutating func advanceBytes(_ count: Int) throws -> Data {
		let endOffset = currentOffset + count
		let bytes: Data
		if count >= 0 {
			guard endOffset <= data.endIndex else { throw Error.overflowError }
			bytes = data[currentOffset..<endOffset]
		} else {
			guard endOffset >= data.startIndex else { throw Error.overflowError }
			bytes = Data(data[endOffset..<currentOffset].reversed())
		}

		currentOffset = endOffset
		return bytes
	}

	public enum Error: Swift.Error {
		case isAtEnd
		case overflowError
	}
}
