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
/// `data.startIndex..<data.endIndex`, but this is not enforced. Failing to follow this rule can
/// result in undefined behavior.
///
/// Error handling with is considered a bit experimental. Typed throws is definitely desired, but the
/// compositional strategy used may change upon new features or epiphanies.
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
	public mutating func scan<T: BinaryInteger>(endianness: Endianness = .big) throws(OverflowError) -> T {
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
	public mutating func scan<T: BinaryFloatingPoint>(endianness: Endianness = .big) throws(OverflowError) -> T {
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
	public mutating func scanNullBytes() throws(ScanError) -> Int {
		var count = 0
		while try peekByte() == 0 {
			currentOffset += 1
			count += 1
		}
		return count
	}

	/// Scans bytes until a null byte is encountered and the string is returned.
	@discardableResult
	public mutating func scanStringUntilNullTerminated() throws(CharError) -> String {
		let (string, byteCount) = try _peekStringUntilNullTerminated()

		currentOffset += byteCount
		return string
	}

	/// Peeks bytes until a null byte is encountered and the string is returned.
	public func peekStringUntilNullTerminated() throws(CharError) -> String {
		try _peekStringUntilNullTerminated().str
	}

	private func _peekStringUntilNullTerminated() throws(CharError) -> (str: String, byteCount: Int) {
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
	public mutating func scanString(byteCount: Int, encoding: String.Encoding = .utf8) throws(CharError) -> String {
		let string = try peekString(byteCount: byteCount, encoding: encoding)

		currentOffset += byteCount
		return string
	}

	/// Peeks and returns a `String` from the next `byteCount` bytes, using `encoding`.
	/// Throws in the event that the end of the data is reached before `byteCount` is
	/// reached (`Error.overflowError`), or the byte sequence does not comprise a
	/// valid `String` (`Error.invalidCharacter`)
	public func peekString(byteCount: Int, encoding: String.Encoding = .utf8) throws(CharError) -> String {
		let bytes = try CharError.Result(overflow: peekBytes(byteCount)).get()

		guard
			let string = String(data: bytes, encoding: encoding)
		else { throw .invalidCharacter }

		return string
	}

	/// Scans and returns the next `Character`. Throws in the event that the next byte is `null`
	/// (`Error.nullTerminated`), if the end of the data is reached before a `Character` is
	/// completed (`Error.overflowError`), or the byte sequence does not comprise a
	/// valid `Character` (`Error.invalidCharacter`)
	public mutating func scanUTF8Character() throws(CharError) -> Character {
		let (char, count) = try _peekUTF8Character()

		currentOffset += count
		return char
	}

	/// Peeks and returns the next `Character`. Throws in the event that the next byte is `null`
	/// (`Error.nullTerminated`), if the end of the data is reached before a `Character` is
	/// completed (`Error.overflowError`), or the byte sequence does not comprise a
	/// valid `Character` (`Error.invalidCharacter`)
	public func peekUTF8Character() throws(CharError) -> Character {
		try _peekUTF8Character().char
	}

	private func _peekUTF8Character() throws(CharError) -> (char: Character, byteCount: Int) {
		let firstByte = try CharError.Result(scan: peekByte()).get()
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
			bytes = try CharError.Result(overflow: peekBytes(2)).get()
			guard
				confirmBytesAreContinuation(bytes[1...])
			else { throw .invalidCharacter }
		case .threeByte:
			bytes = try CharError.Result(overflow: peekBytes(3)).get()
			guard
				confirmBytesAreContinuation(bytes[1...])
			else { throw .invalidCharacter }
		case .fourByte:
			bytes = try CharError.Result(overflow: peekBytes(4)).get()
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
	/// then once `condition` returns `false`, the entire accumulation (including the `Character` that was appended for the `false` condition) is returned.
	@discardableResult
	public mutating func scanString(while condition: (String) -> Bool) -> String {
		let (str, count) = _peekString(while: condition)

		currentOffset += count
		return str
	}

	/// Peeks `Character`s until `condition` is met and returns the accumulated `Character`s. `Character`s are accumulated with each iteration,
	/// then once `condition` returns `false`, the entire accumulation (including the `Character` that was appended for the `false` condition) is returned.
	public func peekString(while condition: (String) -> Bool) -> String {
		_peekString(while: condition).str
	}

	private func _peekString(while condition: (String) -> Bool) -> (str: String, byteCount: Int) {
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
	/// then once `condition` returns `false`, the entire accumulation (including the byte that was appended for the `false` condition) is returned.
	@discardableResult
	public mutating func scanBytes(while condition: ([UInt8]) -> Bool) -> [UInt8] {
		let bytes = peekBytes(while: condition)
		currentOffset += bytes.count

		return bytes
	}

	/// Peeks bytes until `condition` is met and returns the accumulated bytes. Bytes are accumulated with each iteration,
	/// then once `condition` returns `false`, the entire accumulation (including the byte that was appended for the `false` condition) is returned.
	public func peekBytes(while condition: ([UInt8]) -> Bool) -> [UInt8] {
		var bytes: [UInt8] = []

		var peekOffset = currentOffset
		while peekOffset < data.endIndex, condition(bytes) {
			defer { peekOffset += 1 }
			bytes.append(data[peekOffset])
		}
		return bytes
	}

	/// Outputs the current byte, then advances by one unless the scanner is at the end of the data.
	@discardableResult
	public mutating func scanByte() throws(ScanError) -> UInt8 {
		let byte = try peekByte()
		currentOffset += 1

		return byte
	}

	/// Peeks the next byte unless the scanner is at the end of the data.
	public func peekByte() throws(ScanError) -> UInt8 {
		guard isAtEnd == false else { throw .isAtEnd }
		let byte = data[currentOffset]

		return byte
	}

	/// Provides each byte in a Data object. If `count` is negative, bytes start at the lower index and end
	/// at `currentIndex - 1`. `count` must keep the resulting index within the range of available data,
	/// otherwise throws `Error.overflowError`
	@discardableResult
	public mutating func scanBytes(_ count: Int) throws(OverflowError) -> Data {
		let endOffset = currentOffset + count
		let bytes = try peekBytes(count)

		currentOffset = endOffset
		return bytes
	}

	/// Provides each byte in a Data object. If `count` is negative, bytes start at the lower index and end
	/// at `currentIndex - 1`. `count` must keep the resulting index within the range of available data,
	/// otherwise throws `Error.overflowError`
	public func peekBytes(_ count: Int) throws(OverflowError) -> Data {
		let endOffset = currentOffset + count
		let bytes: Data
		if count >= 0 {
			guard endOffset <= data.endIndex else { throw .overflow }
			bytes = Data(data[currentOffset..<endOffset])
		} else {
			guard endOffset >= data.startIndex else { throw .overflow }
			bytes = Data(data[endOffset..<currentOffset].reversed())
		}

		return bytes
	}

	public enum CharError: Error {
		case isAtEnd
		case overflowError
		case invalidCharacter
		case nullTerminated

		enum Result<T> {
			case success(T)
			case failure(CharError)

			init(overflow block: @autoclosure () throws(OverflowError) -> T) {
				do {
					let result = try block()
					self = .success(result)
				} catch {
					self = .failure(.overflowError)
				}
			}

			init(scan block: @autoclosure () throws(ScanError) -> T) {
				do {
					let result = try block()
					self = .success(result)
				} catch {
					switch error {
					case .isAtEnd:
						self = .failure(.isAtEnd)
					case .overflowError:
						self = .failure(.overflowError)
					}
				}
			}

			func get() throws(CharError) -> T {
				switch self {
				case .success(let t):
					return t
				case .failure(let error):
					throw error
				}
			}
		}
	}

	public enum ScanError: Error {
		case isAtEnd
		case overflowError

		enum Result<T> {
			case success(T)
			case failure(ScanError)

			init(_ block: @autoclosure () throws(OverflowError) -> T) {
				do {
					let result = try block()
					self = .success(result)
				} catch {
					self = .failure(.overflowError)
				}
			}

			func get() throws(ScanError) -> T {
				switch self {
				case .success(let t):
					return t
				case .failure(let error):
					throw error
				}
			}
		}
	}

	public enum OverflowError: Error {
		case overflow
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
