import Testing
import DataScanner
import Foundation

struct MagicNumberTests {
	enum MagicNumbers: UInt32, MagicNumber {
		case phrase = 0x70687261
		case fighters = 0x66697465
		case friends = 0x6672656E
		case foes = 0x666F6573
		case foo = 0x20666F6F
	}

	@Test func createFromRawValue() throws {
		let number = MagicNumbers(rawValue: 0x66697465)

		#expect(number == .fighters)
	}

	@Test func createFromString() throws {
		let number = MagicNumbers(stringValue: "fite", endianness: .big)

		#expect(number == .fighters)
	}

	@Test func createFromData() throws {
		let data = Data([
			0x66,
			0x69,
			0x74,
			0x65,
		])
		let number = MagicNumbers(data: data, endianness: .big)

		#expect(number == .fighters)
	}

	@Test func readStringValue() throws {
		#expect(MagicNumbers.fighters.stringValue == "etif")
	}

	@Test func readHexBytes() async throws {
		let bigEndianData = Data([
			0x66,
			0x69,
			0x74,
			0x65,
		])

		#expect(MagicNumbers.fighters.getBytes(endianness: .big) == bigEndianData)
	}
}
