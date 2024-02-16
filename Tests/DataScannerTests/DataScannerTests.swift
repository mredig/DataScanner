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
}
