import XCTest
import DataScanner
import SwiftPizzaSnips
import PizzaMacros

final class EncodedPartTests: XCTestCase {
	enum MagicNumbers: UInt32, BinaryCodingKey {
		case key1 = 1801812273
		case key2 = 1801812274
		case key3 = 1801812275
	}

	func testEncodingData() throws {
		let value = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 0])

		let part = EncodedPart(key: MagicNumbers.key1, flags: BasicFlags(), value: .data(value))

		let rendered = part.renderData()
		print(rendered.toHexString())

		XCTAssertEqual(
			Data([
				107, 101, 121, 49, // magic number
				0, 0, 0, 0, 0, 0, 0, 10, // size
				0, //flags
				1, 2, 3, 4, 5, 6, 7, 8, 9, 0, // data
			]),
			rendered)
	}

	func testDecodingData() throws {
		let inData = try Data(hexString: "6b657932000000000000000a0001020304050607080900")

		let part = try EncodedPart(decoding: inData, magicNumber: MagicNumbers.self, flag: BasicFlags.self)

		let expected = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
		XCTAssertEqual(part.key, .key2)
		XCTAssertEqual(part.flags, [])
		XCTAssertEqual(part.value.data, expected)
	}
}
