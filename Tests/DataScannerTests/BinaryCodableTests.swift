import XCTest
import DataScanner
import SwiftPizzaSnips

final class BinaryCodableTests: XCTestCase {
	struct Foo: BinaryCodable, Hashable {
		init(phrase: String, fighters: Int, friends: [String]) {
			self.phrase = phrase
			self.fighters = fighters
			self.friends = friends
		}
		
		init(from binaryDecoder: BinaryDecodingContainer<MagicNumbers, BasicFlags>) throws {
			let parts = binaryDecoder.topPart.childParts

			var phraseScanner = DataScanner(data: parts[0].data)
			self.phrase = try phraseScanner.scanStringUntilNullTerminated()
			
			var fightersScanner = DataScanner(data: parts[1].data)
			self.fighters = try fightersScanner.scan(endianness: .big)

			var friendsScanner = DataScanner(data: parts[2].data)
			var friends: [String] = []
			while friendsScanner.isAtEnd == false {
				let friend = try friendsScanner.scanStringUntilNullTerminated()
				friends.append(friend)
			}
			self.friends = friends
		}

		let rootKey: MagicNumbers = .foo

		let phrase: String
		let fighters: Int
		let friends: [String]

		enum MagicNumbers: UInt32, MagicNumber {
			case phrase = 0x70687261
			case fighters = 0x66697465
			case friends = 0x6672656E
			case foo = 0x20666F6F
		}

		typealias Flags = BasicFlags

		func encodeToBinaryData(_ coder: inout BinaryEncodingContainer<MagicNumbers, BasicFlags>) throws {
			coder.encodeData(phrase.toBytes(), magicNumber: .phrase)
			coder.encodeData(fighters.toBytes(), magicNumber: .fighters)
			let friendsData = friends.reduce(into: Data()) {
				$0.append(contentsOf: $1.toBytes(nullTerminated: true))
			}
			coder.encodeData(friendsData, magicNumber: .friends)
		}
	}

	let aTestValue = Foo(
		phrase: "do or do not",
		fighters: 54312332,
		friends: [
			"Derek",
			"Cody",
			"Kurt"
		])

	func testEncodingData() throws {
		let encoder = BinaryEncoder()
		let data = try encoder.encode(aTestValue, topKey: .foo)

		let expectedHexString = """
			20666f6f000000000000004b0170687261000000000000000c00646f206f7220646f206e6f746669746500000000000000080000000\
			000033cbd8c6672656e000000000000001000446572656b00436f6479004b75727400
			"""
		XCTAssertEqual(expectedHexString, data.toHexString())
	}

	func testDecodingData() throws {
		let decoder = BinaryDecoder()
		let hexString = """
			20666f6f000000000000004b0170687261000000000000000c00646f206f7220646f206e6f746669746500000000000000080000000\
			000033cbd8c6672656e000000000000001000446572656b00436f6479004b75727400
			"""

		let data = try Data(hexString: hexString)

		let newValue: Foo = try decoder.decode(from: data, topKey: .foo)

		XCTAssertEqual(newValue, aTestValue)
	}

//	func testDecodingData() throws {
//		let inData = try Data(hexString: "6b657932000000000000000a0001020304050607080900")
//
//		let part = try EncodedPart(decoding: inData, magicNumbersType: MagicNumbers.self, flagsType: BasicFlags.self)
//
//		let expected = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
//		XCTAssertEqual(part.key, .key2)
//		XCTAssertEqual(part.flags, [])
//		XCTAssertEqual(part.data, expected)
//	}
//
//	func testEncodingEmbeddedParts() throws {
//		let valueA = Data([0b11011110, 0b10101101, 0b10111110, 0b11101111])
//		let valueB = Data([0b11011110, 0b11001010])
//		let valueC = try Data(hexString: "CAFEFACEDECAFBABEBADC0DE")
//
//		let mostInternalPart = EncodedPart(key: MagicNumbers.key5, flags: BasicFlags(), value: .data(valueC))
//		let parentPart = EncodedPart(key: MagicNumbers.key4, flags: BasicFlags(), value: .parts([mostInternalPart]))
//
//		let secondLevelParts: [EncodedPart] = [
//			EncodedPart(key: MagicNumbers.key2, flags: BasicFlags(), value: .data(valueA)),
//			EncodedPart(key: MagicNumbers.key2, flags: BasicFlags(), value: .data(valueB)),
//			EncodedPart(key: MagicNumbers.key3, flags: BasicFlags(), value: .parts([parentPart])),
//		]
//
//		let topLevelPart = EncodedPart(key: MagicNumbers.key1, flags: BasicFlags(), value: .parts(secondLevelParts))
//
//		let renderedData = topLevelPart.renderData()
//
//		let expectedHexString = """
//			6b6579310000000000000053016b657932000000000000000400deadbeef6b657932000000000000000200deca6b657933000000000\
//			0000026016b6579340000000000000019016b657935000000000000000c00cafefacedecafbabebadc0de
//			"""
//
//		XCTAssertEqual(renderedData.toHexString(), expectedHexString)
//	}
//
//	func testDecodingEmbeddedParts() throws {
//		let expectedValueA = Data([0b11011110, 0b10101101, 0b10111110, 0b11101111])
//		let expectedValueB = Data([0b11011110, 0b11001010])
//		let expectedValueC = try Data(hexString: "CAFEFACEDECAFBABEBADC0DE")
//
//		let hexString = """
//			6b6579310000000000000053016b657932000000000000000400deadbeef6b657932000000000000000200deca6b657933000000000\
//			0000026016b6579340000000000000019016b657935000000000000000c00cafefacedecafbabebadc0de
//			"""
//		let data = try Data(hexString: hexString)
//
//		let topDecodedParts = try EncodedPart(decoding: data, magicNumbersType: MagicNumbers.self, flagsType: BasicFlags.self)
//		XCTAssertEqual(topDecodedParts.key, .key1)
//		XCTAssertEqual(topDecodedParts.flags, .hasChildParts)
//		let topParts = topDecodedParts.childParts
//		XCTAssertEqual(topParts.count, 3)
//
//		let partA = topParts[0]
//		let partB = topParts[1]
//		let parent1Part = topParts[2]
//
//		XCTAssertEqual(partA.data, expectedValueA)
//		XCTAssertEqual(partA.flags, [])
//		XCTAssertEqual(partA.key, .key2)
//
//		XCTAssertEqual(partB.data, expectedValueB)
//		XCTAssertEqual(partB.flags, [])
//		XCTAssertEqual(partB.key, .key2)
//
//		XCTAssertEqual(parent1Part.flags, .hasChildParts)
//		XCTAssertEqual(parent1Part.key, .key3)
//
//		let parent2Parts = parent1Part.childParts
//		XCTAssertEqual(parent2Parts.count, 1)
//		let parent2Part = parent2Parts[0]
//		XCTAssertEqual(parent2Part.flags, .hasChildParts)
//		XCTAssertEqual(parent2Part.key, .key4)
//
//		let partCParts = parent2Part.childParts
//		XCTAssertEqual(partCParts.count, 1)
//		let partC = partCParts[0]
//		XCTAssertEqual(partC.flags, [])
//		XCTAssertEqual(partC.key, .key5)
//		XCTAssertEqual(partC.data, expectedValueC)
//	}
//
//	enum Error: Swift.Error {
//		case testFail
//	}
}
