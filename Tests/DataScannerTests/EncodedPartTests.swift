import XCTest
import DataScanner
import SwiftPizzaSnips

final class EncodedPartTests: XCTestCase {
	enum MagicNumbers: UInt32, MagicNumber {
		case key1 = 1801812273
		case key2 = 1801812274
		case key3 = 1801812275
		case key4 = 1801812276
		case key5 = 1801812277
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

		let part = try EncodedPart(decoding: inData, magicNumberType: MagicNumbers.self, flagType: BasicFlags.self)

		let expected = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
		XCTAssertEqual(part.key, .key2)
		XCTAssertEqual(part.flags, [])
		XCTAssertEqual(part.data, expected)
	}

	func testEncodingEmbeddedParts() throws {
		let valueA = Data([0b11011110, 0b10101101, 0b10111110, 0b11101111])
		let valueB = Data([0b11011110, 0b11001010])
		let valueC = try Data(hexString: "CAFEFACEDECAFBABEBADC0DE")

		let mostInternalPart = EncodedPart(key: MagicNumbers.key5, flags: BasicFlags(), value: .data(valueC))
		let parentPart = EncodedPart(key: MagicNumbers.key4, flags: BasicFlags(), value: .parts([mostInternalPart]))

		let secondLevelParts: [EncodedPart] = [
			EncodedPart(key: MagicNumbers.key2, flags: BasicFlags(), value: .data(valueA)),
			EncodedPart(key: MagicNumbers.key2, flags: BasicFlags(), value: .data(valueB)),
			EncodedPart(key: MagicNumbers.key3, flags: BasicFlags(), value: .parts([parentPart])),
		]

		let topLevelPart = EncodedPart(key: MagicNumbers.key1, flags: BasicFlags(), value: .parts(secondLevelParts))

		let renderedData = topLevelPart.renderData()

		let expectedHexString = """
			6b6579310000000000000053016b657932000000000000000400deadbeef6b657932000000000000000200deca6b657933000000000\
			0000026016b6579340000000000000019016b657935000000000000000c00cafefacedecafbabebadc0de
			"""

		XCTAssertEqual(renderedData.toHexString(), expectedHexString)
	}

	func testDecodingEmbeddedParts() throws {
		let expectedValueA = Data([0b11011110, 0b10101101, 0b10111110, 0b11101111])
		let expectedValueB = Data([0b11011110, 0b11001010])
		let expectedValueC = try Data(hexString: "CAFEFACEDECAFBABEBADC0DE")

		let hexString = """
			6b6579310000000000000053016b657932000000000000000400deadbeef6b657932000000000000000200deca6b657933000000000\
			0000026016b6579340000000000000019016b657935000000000000000c00cafefacedecafbabebadc0de
			"""
		let data = try Data(hexString: hexString)

		let topDecodedParts = try EncodedPart(decoding: data, magicNumberType: MagicNumbers.self, flagType: BasicFlags.self)
		XCTAssertEqual(topDecodedParts.key, .key1)
		XCTAssertEqual(topDecodedParts.flags, .hasChildParts)
		let topParts = topDecodedParts.childParts
		XCTAssertEqual(topParts.count, 3)

		let partA = topParts[0]
		let partB = topParts[1]
		let parent1Part = topParts[2]

		XCTAssertEqual(partA.data, expectedValueA)
		XCTAssertEqual(partA.flags, [])
		XCTAssertEqual(partA.key, .key2)

		XCTAssertEqual(partB.data, expectedValueB)
		XCTAssertEqual(partB.flags, [])
		XCTAssertEqual(partB.key, .key2)

		XCTAssertEqual(parent1Part.flags, .hasChildParts)
		XCTAssertEqual(parent1Part.key, .key3)

		let parent2Parts = parent1Part.childParts
		XCTAssertEqual(parent2Parts.count, 1)
		let parent2Part = parent2Parts[0]
		XCTAssertEqual(parent2Part.flags, .hasChildParts)
		XCTAssertEqual(parent2Part.key, .key4)

		let partCParts = parent2Part.childParts
		XCTAssertEqual(partCParts.count, 1)
		let partC = partCParts[0]
		XCTAssertEqual(partC.flags, [])
		XCTAssertEqual(partC.key, .key5)
		XCTAssertEqual(partC.data, expectedValueC)
	}

	enum Error: Swift.Error {
		case testFail
	}
}
