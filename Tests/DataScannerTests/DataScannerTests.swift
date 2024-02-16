import XCTest
import DataScanner
import SwiftPizzaSnips

final class DataScannerTests: XCTestCase {
	func testScanDouble() throws {
		let inputHex = "1880E32EE5124AD0B903FA814E67FCF9"

		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let doubleBE1: Double = try scanner.scan(endianness: .big)
		XCTAssertEqual(1.1844491647066381e-190, doubleBE1)
		let doubleBE2: Double = try scanner.scan(endianness: .big)
		XCTAssertEqual(-4.8096574843181661e-34, doubleBE2)
		scanner.currentOffset = 0
		let doubleLE1: Double = try scanner.scan(endianness: .little)
		XCTAssertEqual(-6.0382817660725676e+78, doubleLE1)
		let doubleLE2: Double = try scanner.scan(endianness: .little)
		XCTAssertEqual(-4.0279909842408473e+279, doubleLE2)
	}

	func testScanInt() throws {
		let inputHex = "1880E32EE5124AD0B903FA814E67FCF9"

		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let intBE1: Int = try scanner.scan(endianness: .big)
		XCTAssertEqual(1765660844480416464, intBE1)
		let intBE2: Int = try scanner.scan(endianness: .big)
		XCTAssertEqual(-5114969318489588487, intBE2)
		scanner.currentOffset = 0
		let intLE1: Int = try scanner.scan(endianness: .little)
		XCTAssertEqual(-3437914590000480232, intLE1)
		let intLE2: Int = try scanner.scan(endianness: .little)
		XCTAssertEqual(-433357877248654407, intLE2)
	}

	func testScanInt32() throws {
		let inputHex = "1880E32EE5124AD0B903FA814E67FCF9"

		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let beList: [Int32] = [
			411099950,
			-451786032,
			-1190921599,
			1315437817,
		]

		let leList: [Int32] = [
			786661400,
			-800451867,
			-2114321479,
			-100898994,
		]

		for expectedBE in beList {
			let num: Int32 = try scanner.scan(endianness: .big)
			XCTAssertEqual(expectedBE, num)
		}

		scanner.currentOffset = 0

		for expectedLE in leList {
			let num: Int32 = try scanner.scan(endianness: .little)
			XCTAssertEqual(expectedLE, num)
		}
	}

	func testScanChars() throws {
		let inputHex = "666F6F2062617220000000"
		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let expected = "foo bar "
		var currentIndex = expected.startIndex
		while let char = try? scanner.scanUTF8Character() {
			XCTAssertEqual(expected[currentIndex], char)
			currentIndex = expected.index(after: currentIndex)
		}
	}

	func testScanUnicodeChars() throws {
		let inputHex = "f09f9fa7f09fa5b0e1baa2e284b3e28899c380"

		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let expected = "🟧🥰Ảℳ∙À"
		var currentIndex = expected.startIndex
		while let char = try? scanner.scanUTF8Character() {
			XCTAssertEqual(expected[currentIndex], char)
			currentIndex = expected.index(after: currentIndex)
		}
	}

	func testCharacterAnalyst() throws {
		let illegalByte: UInt8 = 248
		let oneByte: UInt8 = 0b01111111
		let twoByte: UInt8 = 0b11011111
		let threeByte: UInt8 = 0b11101111
		let fourByte: UInt8 = 0b11110111
		let contByte: UInt8 = 0b10111111

		typealias Analyst = DataScanner.CharacterAnalyst

		XCTAssertEqual(Analyst.analyzeByte(illegalByte), .illegalByte)
		XCTAssertEqual(Analyst.analyzeByte(oneByte), .oneByte)
		XCTAssertEqual(Analyst.analyzeByte(twoByte), .twoByte)
		XCTAssertEqual(Analyst.analyzeByte(threeByte), .threeByte)
		XCTAssertEqual(Analyst.analyzeByte(fourByte), .fourByte)
		XCTAssertEqual(Analyst.analyzeByte(contByte), .continuationByte)

		var alphanum = "abcdefghijklmnopqrstuvwxyz0123456789"
		alphanum += alphanum.uppercased()

		let alphaData = Data(alphanum.utf8)
		alphaData.forEach {
			XCTAssertEqual(Analyst.analyzeByte($0), .oneByte)
		}

		let fourBytes = ("🟧🥰", Analyst.fourByte)
		let threeBytes = ("Ảℳ∙", Analyst.threeByte)
		let twoBytes = ("À", Analyst.twoByte)
		let tests = [fourBytes, threeBytes, twoBytes]

		for (string, expected) in tests {
			for char in string {
				let charData = Data(char.utf8)
				for (index, byte) in charData.enumerated() {
					XCTAssertEqual(Analyst.analyzeByte(byte), index == 0 ? expected : .continuationByte)
				}
			}
		}
	}

	func testScanNullTerminatedString() throws {
		let inputHex = "666F6F20626172200000666F6F20626172200000"
		let inputData = try Data(hexString: inputHex)

		var scanner = DataScanner(data: inputData)

		let firstString = try scanner.scanStringUntilNullTerminated()
		XCTAssertEqual("foo bar ", firstString)
	}
}
