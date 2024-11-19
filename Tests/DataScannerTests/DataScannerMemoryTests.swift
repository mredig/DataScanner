import Testing
import DataScanner
import SwiftPizzaSnips
import Foundation

struct DataScannerMemoryTests {
	@Test func scanDouble() throws {
		let inputHex = "1880E32EE5124AD0B903FA814E67FCF9"

		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let doubleBE1: Double = try scanner.scan(endianness: .big)
		#expect(1.1844491647066381e-190 == doubleBE1)
		let doubleBE2: Double = try scanner.scan(endianness: .big)
		#expect(-4.8096574843181661e-34 == doubleBE2)
		scanner.currentOffset = 0
		let doubleLE1: Double = try scanner.scan(endianness: .little)
		#expect(-6.0382817660725676e+78 == doubleLE1)
		let doubleLE2: Double = try scanner.scan(endianness: .little)
		#expect(-4.0279909842408473e+279 == doubleLE2)
	}

	@Test func scanInt() throws {
		let inputHex = "1880E32EE5124AD0B903FA814E67FCF9"

		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let intBE1: Int = try scanner.scan(endianness: .big)
		#expect(1765660844480416464 == intBE1)
		let intBE2: Int = try scanner.scan(endianness: .big)
		#expect(-5114969318489588487 == intBE2)
		scanner.currentOffset = 0
		let intLE1: Int = try scanner.scan(endianness: .little)
		#expect(-3437914590000480232 == intLE1)
		let intLE2: Int = try scanner.scan(endianness: .little)
		#expect(-433357877248654407 == intLE2)
	}

	@Test func scanInt32() throws {
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
			#expect(expectedBE == num)
		}

		scanner.currentOffset = 0

		for expectedLE in leList {
			let num: Int32 = try scanner.scan(endianness: .little)
			#expect(expectedLE == num)
		}
	}

	@Test func scanChars() throws {
		let inputHex = "666F6F2062617220000000"
		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let expected = "foo bar "
		var currentIndex = expected.startIndex
		while let char = try? scanner.scanUTF8Character() {
			#expect(expected[currentIndex] == char)
			currentIndex = expected.index(after: currentIndex)
		}
	}

	@Test func scanStringBytes() async throws {
		let inputHex = "666F6F20626172200000666F6F20626172200000"
		let inputData = try Data(hexString: inputHex)

		var scanner = DataScanner(inputData)

		let firstString = try scanner.scanString(byteCount: 4)
		#expect(firstString == "foo ")

		let secondString = try scanner.scanString(byteCount: 2)
		#expect(secondString == "ba")
	}

	@Test func scanUnicodeChars() throws {
		let inputHex = "f09f9fa7f09fa5b0e1baa2e284b3e28899c380"

		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let expected = "🟧🥰Ảℳ∙À"
		var currentIndex = expected.startIndex
		while let char = try? scanner.scanUTF8Character() {
			#expect(expected[currentIndex] == char)
			currentIndex = expected.index(after: currentIndex)
		}
	}

	@Test func peekUnicodeChars() throws {
		let inputHex = "f09f9fa7f09fa5b0e1baa2e284b3e28899c380"

		let data = try Data(hexString: inputHex)

		let scanner = DataScanner(data: data)

		let expected = "🟧🥰Ảℳ∙À"
		let char = try scanner.peekUTF8Character()
		#expect(expected.first == char)
	}

	@Test func conditionalStringScan() throws {
		let inputHex = """
			5375626A6563743A20466F6F0A46726F6D3A20686540686F2E68756D0D0A0D0\
			A4461746120666F6F206261722062617A20626C6520626F6F
			"""
		let inputData = try Data(hexString: inputHex)

		var scanner = DataScanner(inputData)

		let peeked = scanner.peekString(through: { $0.hasSuffix("\r\n\r\n") })

		let string = scanner.scanString(through: { $0.hasSuffix("\r\n\r\n") })
		let expectation = """
			Subject: Foo
			From: he@ho.hum\r\n\r\n
			"""
		#expect(peeked == expectation)
		#expect(string == expectation)

		let endExpectation = "Data foo bar baz ble boo"
		let scanThroughEnd = scanner.scanString(through: { $0.hasSuffix("\r\n\r\n") })
		#expect(scanThroughEnd == endExpectation)
	}

	@Test func conditionalByteScan() throws {
		let inputHex = "666F6F20626172200000666F6F20626172200000"
		let inputData = try Data(hexString: inputHex)

		var scanner = DataScanner(data: inputData)

		let bytes = scanner.scanBytes(through: { $0.last == 0 })
		let data = Data(bytes.dropLast())

		let str = String(decoding: data, as: UTF8.self)
		#expect("foo bar " == str)
		#expect(scanner.currentOffset == 9)
	}

	@Test func byteScan() throws {
		let inputHex = "f09f9fa7f09fa5b0e1baa2e284b3e28899c380"

		let data = try Data(hexString: inputHex)

		var scanner = DataScanner(data: data)

		let expected = Array(data)

		for byte in expected {
			#expect(try scanner.scanByte() == byte)
		}
	}

	@Test func scanNullTerminatedString() throws {
		let inputHex = "666F6F20626172200000666F6F20626172200000"
		let inputData = try Data(hexString: inputHex)

		var scanner = DataScanner(data: inputData)

		let firstString = try scanner.scanStringUntilNullTerminated()
		#expect("foo bar " == firstString)
		#expect(9 == scanner.currentOffset)

		let nullCount = try scanner.scanNullBytes()
		#expect(1 == nullCount)

		let secondString = try scanner.scanStringUntilNullTerminated()
		#expect("foo bar " == secondString)
	}

	@Test func peekNullTerminatedString() throws {
		let inputHex = "666F6F20626172200000666F6F20626172200000"
		let inputData = try Data(hexString: inputHex)

		let scanner = DataScanner(data: inputData)

		let firstString = try scanner.peekStringUntilNullTerminated()
		#expect("foo bar " == firstString)
		#expect(0 == scanner.currentOffset)

		let secondString = try scanner.peekStringUntilNullTerminated()
		#expect("foo bar " == secondString)
		#expect(0 == scanner.currentOffset)
	}
}
