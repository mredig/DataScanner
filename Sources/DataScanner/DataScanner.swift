import Foundation
import SwiftPizzaSnips

/// Scans a data source conforming to `Scannable`.
///
/// This is not thread safe and must by used synchronously.
///
/// Methods are split between `scan` methods and `peek` methods. `peek` methods are read only and
/// just inform you of the content of the next sequence of bytes, whereas `scan` methods increment
/// `currentOffset` by the amount of bytes that they consume.
///
/// It is okay to modify `currentOffset` as long as the value remains within the range of
/// `data.startIndex..<data.endIndex`, but this is not enforced. Failing to follow this rule can result in undefined behavior.
public struct DataScanner {
	private var data: Scannable

	public var currentOffset: Int

	public var isAtEnd: Bool { currentOffset == data.endIndex }

	public init(_ scannable: Scannable) {
		self.data = scannable
		self.currentOffset = scannable.startIndex
	}

	public init(data: Data) {
		self.init(data)
	}

	public init(url: URL) throws(ScannableFileHandle.Error) {
		let handle = try ScannableFileHandle(url: url)
		self.data = handle
		self.currentOffset = handle.startIndex
	}

	/// Scans the next `MemoryLayout<T>.size` bytes and loads them as type `T` with provided `Endianness`.
	/// If the remaining bytes are insufficient, throws `Error.overflowError`
	public mutating func scan<T: BinaryInteger>(endianness: Endianness = .big) throws(Error) -> T {
		let size = MemoryLayout<T>.size

		var bytes = try scanBytes(size)
		if endianness != Endianness.systemEndianness {
			bytes.reverse()
		}

		return bytes.withUnsafeBytes { pointer in
			pointer.load(as: T.self)
		}
	}

	/// Scans the next `MemoryLayout<T>.size` bytes and loads them as type `T` with provided `Endianness`.
	/// If the remaining bytes are insufficient, throws `Error.overflowError`
	public mutating func scan<T: BinaryFloatingPoint>(endianness: Endianness = .big) throws(Error) -> T {
		let size = MemoryLayout<T>.size

		var bytes = try scanBytes(size)
		if endianness != Endianness.systemEndianness {
			bytes.reverse()
		}

		return bytes.withUnsafeBytes { pointer in
			pointer.load(as: T.self)
		}
	}

	/// Instead of returning the bytes themselves, this returns the number of null bytes.
	@discardableResult
	public mutating func scanNullBytes() throws(Error) -> Int {
		var count = 0
		while try peekByte() == 0 {
			currentOffset += 1
			count += 1
		}
		return count
	}

	/// Scans bytes until a null byte is encountered and the string is returned.
	@discardableResult
	public mutating func scanStringUntilNullTerminated() throws(Error) -> String {
		let (string, byteCount) = try _peekStringUntilNullTerminated()

		currentOffset += byteCount
		return string
	}

	/// Peeks bytes until a null byte is encountered and the string is returned.
	public func peekStringUntilNullTerminated() throws(Error) -> String {
		try _peekStringUntilNullTerminated().str
	}

	private func _peekStringUntilNullTerminated() throws(Error) -> (str: String, byteCount: Int) {
		var buffer = ""
		var copy = self
		copy.data = copy.data.copyIfNeeded()
		let startOffset = currentOffset
		do {
			var character = try copy.scanUTF8Character()
			while true {
				buffer.append(character)
				character = try copy.scanUTF8Character()
			}
		} catch .nullTerminated {
			return (buffer, copy.currentOffset - startOffset + 1) // include null char
		} catch .isAtEnd {
			return (buffer, copy.currentOffset - startOffset)
		}
	}

	/// Scans and returns a `String` from the next `byteCount` bytes, using `encoding`.
	/// Throws in the event that the end of the data is reached before `byteCount` is
	/// reached (`Error.overflowError`), or the byte sequence does not comprise a
	/// valid `String` (`Error.invalidCharacter`)
	@discardableResult
	public mutating func scanString(byteCount: Int, encoding: String.Encoding = .utf8) throws(Error) -> String {
		let string = try peekString(byteCount: byteCount, encoding: encoding)

		currentOffset += byteCount
		return string
	}

	/// Peeks and returns a `String` from the next `byteCount` bytes, using `encoding`.
	/// Throws in the event that the end of the data is reached before `byteCount` is
	/// reached (`Error.overflowError`), or the byte sequence does not comprise a
	/// valid `String` (`Error.invalidCharacter`)
	public func peekString(byteCount: Int, encoding: String.Encoding = .utf8) throws(Error) -> String {
		let bytes = try peekBytes(byteCount)

		guard
			let string = String(data: bytes, encoding: encoding)
		else { throw .invalidCharacter }

		return string
	}

	/// Scans and returns the next `Character`. Throws in the event that the next byte is `null`
	/// (`Error.nullTerminated`), if the end of the data is reached before a `Character` is
	/// completed (`Error.overflowError`), or the byte sequence does not comprise a
	/// valid `Character` (`Error.invalidCharacter`)
	public mutating func scanUTF8Character() throws(Error) -> Character {
		let (char, count) = try _peekUTF8Character()

		currentOffset += count
		return char
	}

	/// Peeks and returns the next `Character`. Throws in the event that the next byte is `null`
	/// (`Error.nullTerminated`), if the end of the data is reached before a `Character` is
	/// completed (`Error.overflowError`), or the byte sequence does not comprise a
	/// valid `Character` (`Error.invalidCharacter`)
	public func peekUTF8Character() throws(Error) -> Character {
		try _peekUTF8Character().char
	}

	private func _peekUTF8Character() throws(Error) -> (char: Character, byteCount: Int) {
		let firstByte = try peekByte()
		guard firstByte != 0 else { throw .nullTerminated }

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
			else { throw .invalidCharacter }
		case .threeByte:
			bytes = try peekBytes(3)
			guard
				confirmBytesAreContinuation(bytes[1...])
			else { throw .invalidCharacter }
		case .fourByte:
			bytes = try peekBytes(4)
			guard
				confirmBytesAreContinuation(bytes[1...])
			else { throw .invalidCharacter }
		case .continuationByte, .illegalByte:
			throw .invalidCharacter
		}

		guard
			let str = String(data: bytes, encoding: .utf8),
			str.count == 1,
			let char = str.first
		else { throw .invalidCharacter }

		return (char, bytes.count)
	}

	/// Scans `Character`s until `condition` is met and returns the accumulated `Character`s. `Character`s are accumulated with each iteration,
	/// then once `condition` returns `true`, the entire accumulation (including the `Character` that was appended for the `true` condition) is returned.
	@discardableResult
	public mutating func scanString(through condition: (String) -> Bool) -> String {
		let (str, count) = _peekString(through: condition)

		currentOffset += count
		return str
	}

	/// Peeks `Character`s until `condition` is met and returns the accumulated `Character`s. `Character`s are accumulated with each iteration,
	/// then once `condition` returns `true`, the entire accumulation (including the `Character` that was appended for the `true` condition) is returned.
	public func peekString(through condition: (String) -> Bool) -> String {
		_peekString(through: condition).str
	}

	private func _peekString(through condition: (String) -> Bool) -> (str: String, byteCount: Int) {
		var accumulator = ""

		let startOffset = currentOffset

		let byteCount: Int
		var copy = self
		copy.data = data.copyIfNeeded()
		while condition(accumulator) {
			do {
				let character = try copy.scanUTF8Character()
				accumulator.append(character)
			} catch .nullTerminated {
				byteCount = copy.currentOffset - startOffset + 1
				return (accumulator, byteCount)
			} catch {
				byteCount = copy.currentOffset - startOffset
				return (accumulator, byteCount)
			}
		}
		byteCount = copy.currentOffset - startOffset

		return (accumulator, byteCount)
	}

	/// Scans bytes until `condition` is met and returns the accumulated bytes. Bytes are accumulated with each iteration,
	/// then once `condition` returns `true`, the entire accumulation (including the byte that was appended for the `true` condition) is returned.
	@discardableResult
	public mutating func scanBytes(through condition: ([UInt8]) -> Bool) -> [UInt8] {
		let bytes = peekBytes(through: condition)
		currentOffset += bytes.count

		return bytes
	}

	/// Peeks bytes until `condition` is met and returns the accumulated bytes. Bytes are accumulated with each iteration,
	/// then once `condition` returns `true`, the entire accumulation (including the byte that was appended for the `true` condition) is returned.
	public func peekBytes(through condition: ([UInt8]) -> Bool) -> [UInt8] {
		var bytes: [UInt8] = []

		var peekOffset = currentOffset
		while peekOffset < data.endIndex {
			defer { peekOffset += 1 }
			bytes.append(data[peekOffset])
			
			if condition(bytes) {
				return bytes
			}
		}
		return bytes
	}

	/// Outputs the current byte, then advances by one unless the scanner is at the end of the data.
	@discardableResult
	public mutating func scanByte() throws(Error) -> UInt8 {
		let byte = try peekByte()
		currentOffset += 1

		return byte
	}

	/// Peeks the next byte unless the scanner is at the end of the data.
	public func peekByte() throws(Error) -> UInt8 {
		guard isAtEnd == false else { throw .isAtEnd }
		let byte = data[currentOffset]

		return byte
	}

	/// Provides each byte in a Data object. If `count` is negative, bytes start at the lower index and end
	/// at `currentIndex - 1`. `count` must keep the resulting index within the range of available data,
	/// otherwise throws `Error.overflowError`
	@discardableResult
	public mutating func scanBytes(_ count: Int) throws(Error) -> Data {
		let endOffset = currentOffset + count
		let bytes = try peekBytes(count)

		currentOffset = endOffset
		return bytes
	}

	/// Provides each byte in a Data object. If `count` is negative, bytes start at the lower index and end
	/// at `currentIndex - 1`. `count` must keep the resulting index within the range of available data,
	/// otherwise throws `Error.overflowError`
	public func peekBytes(_ count: Int) throws(Error) -> Data {
		let endOffset = currentOffset + count
		let bytes: Data
		if count >= 0 {
			guard endOffset <= data.endIndex else { throw .overflowError }
			bytes = Data(data[currentOffset..<endOffset])
		} else {
			guard endOffset >= data.startIndex else { throw .overflowError }
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
