import XCTest
import DataScanner
import SwiftPizzaSnips

final class CharacterAnalysisTests: XCTestCase {
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
}
