import XCTest
import DataScanner
import SwiftPizzaSnips

final class DataScannerMemoryTests: XCTestCase {
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

	func testScanNullTerminatedString() throws {
		let inputHex = "666F6F20626172200000666F6F20626172200000"
		let inputData = try Data(hexString: inputHex)

		var scanner = DataScanner(data: inputData)

		let firstString = try scanner.scanStringUntilNullTerminated()
		XCTAssertEqual("foo bar ", firstString)
		XCTAssertEqual(9, scanner.currentOffset)

		let nullCount = try scanner.scanNullBytes()
		XCTAssertEqual(1, nullCount)

		let secondString = try scanner.scanStringUntilNullTerminated()
		XCTAssertEqual("foo bar ", secondString)
	}
}
