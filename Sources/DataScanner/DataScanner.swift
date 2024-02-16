import Foundation
import SwiftPizzaSnips

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

	/// Instead of returning the bytes themselves, this returns the number of null bytes.
	@discardableResult
	public mutating func scanNullBytes() throws -> Int {
		var count = 0
		while try peekByte() == 0 {
			currentOffset += 1
			count += 1
		}
		return count
	}

	@discardableResult
	public mutating func scanStringUntilNullTerminated() throws -> String {
		let (string, byteCount) = try _peekStringUntilNullTerminated()

		currentOffset += byteCount
		return string
	}

	public func peekStringUntilNullTerminated() throws -> String {
		try _peekStringUntilNullTerminated().str
	}

	private func _peekStringUntilNullTerminated() throws -> (str: String, byteCount: Int) {
		var buffer = ""
		var copy = self
		let startOffset = currentOffset
		do {
			var character = try copy.scanUTF8Character()
			while true {
				buffer.append(character)
				character = try copy.scanUTF8Character()
			}
		} catch Error.nullTerminated {
			return (buffer, copy.currentOffset - startOffset + 1) // include null char
		} catch Error.isAtEnd {
			return (buffer, copy.currentOffset - startOffset)
		}
	}

	@discardableResult
	public mutating func scanString(byteCount: Int, encoding: String.Encoding = .utf8) throws -> String {
		let string = try peekString(byteCount: byteCount, encoding: encoding)

		currentOffset += byteCount
		return string
	}

	public func peekString(byteCount: Int, encoding: String.Encoding = .utf8) throws -> String {
		let bytes = try peekBytes(byteCount)

		guard
			let string = String(data: bytes, encoding: encoding)
		else { throw Error.invalidCharacter }

		return string
	}

	public mutating func scanUTF8Character() throws -> Character {
		let (char, count) = try _peekUTF8Character()

		currentOffset += count
		return char
	}

	public func peekUTF8Character() throws -> Character {
		try _peekUTF8Character().char
	}

	private func _peekUTF8Character() throws -> (char: Character, byteCount: Int) {
		let firstByte = try peekByte()
		guard firstByte != 0 else { throw Error.nullTerminated }

		let bytes: Data
		let analysis = CharacterAnalyst.analyzeByte(firstByte)
		func confirmBytesAreContinuation(_ bytes: Data) -> Bool {
			bytes.allSatisfy { CharacterAnalyst.analyzeByte($0) == .continuationByte }
		}
		switch analysis {
		case .oneByte:
			bytes = Data([firstByte])
		case .twoByte:
			bytes = try peekBytes(2)
			guard
				confirmBytesAreContinuation(bytes[1...])
			else { throw Error.invalidCharacter}
		case .threeByte:
			bytes = try peekBytes(3)
			guard
				confirmBytesAreContinuation(bytes[1...])
			else { throw Error.invalidCharacter}
		case .fourByte:
			bytes = try peekBytes(4)
			guard
				confirmBytesAreContinuation(bytes[1...])
			else { throw Error.invalidCharacter}
		case .continuationByte, .illegalByte:
			throw Error.invalidCharacter
		}

		guard
			let str = String(data: bytes, encoding: .utf8),
			str.count == 1,
			let char = str.first
		else { throw Error.invalidCharacter }

		return (char, bytes.count)
	}

	/// Outputs the current byte, then advances by one.
	@discardableResult
	public mutating func advanceByte() throws -> UInt8 {
		let byte = try peekByte()

		currentOffset += 1
		return byte
	}

	public func peekByte() throws -> UInt8 {
		guard isAtEnd == false else { throw Error.isAtEnd }
		let byte = data[currentOffset]

		return byte
	}

	/// Provides each byte in a Data object. If `count` is negative, bytes start at the lower index and end
	/// at `currentIndex - 1`. `count` must keep the resulting index within the range of available data.
	@discardableResult
	public mutating func advanceBytes(_ count: Int) throws -> Data {
		let endOffset = currentOffset + count
		let bytes = try peekBytes(count)

		currentOffset = endOffset
		return bytes
	}

	public func peekBytes(_ count: Int) throws -> Data {
		let endOffset = currentOffset + count
		let bytes: Data
		if count >= 0 {
			guard endOffset <= data.endIndex else { throw Error.overflowError }
			bytes = Data(data[currentOffset..<endOffset])
		} else {
			guard endOffset >= data.startIndex else { throw Error.overflowError }
			bytes = Data(data[endOffset..<currentOffset].reversed())
		}

		return bytes
	}

	public enum Error: Swift.Error {
		case isAtEnd
		case overflowError
		case invalidCharacter
		case nullTerminated
	}

	package enum CharacterAnalyst {
		case oneByte
		case twoByte
		case threeByte
		case fourByte
		case continuationByte
		case illegalByte

		static let oneByteValue: UInt8 = 0
		static let oneByteMask: UInt8 = 0b10000000

		static let twoByteValue: UInt8 = 0b11000000
		static let twoByteMask: UInt8 = 0b11100000

		static let threeByteValue: UInt8 = 0b11100000
		static let threeByteMask: UInt8 = 0b11110000

		static let fourByteValue: UInt8 = 0b11110000
		static let fourByteMask: UInt8 = 0b11111000

		static let continuationByteValue: UInt8 = 0b10000000
		static let continuationByteMask: UInt8 = 0b11000000


		static package func analyzeByte(_ byte: UInt8) -> CharacterAnalyst {
			guard (byte & oneByteMask) != oneByteValue else {
				return .oneByte
			}
			guard (byte & continuationByteMask) != continuationByteValue else {
				return .continuationByte
			}
			guard (byte & twoByteMask) != twoByteValue else {
				return .twoByte
			}
			guard (byte & threeByteMask) != threeByteValue else {
				return .threeByte
			}
			guard (byte & fourByteMask) != fourByteValue else {
				return .fourByte
			}
			return .illegalByte
		}
	}
}
