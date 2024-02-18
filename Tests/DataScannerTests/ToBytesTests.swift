import XCTest
import DataScanner
import SwiftPizzaSnips

final class ToBytesTests: XCTestCase {
	func testToBytesIntValues() throws {
		let a: UInt8 = 0xDE
		let b: UInt16 = 0xADBE
		let c: UInt32 = 0xDEADBEEF
		let d: UInt64 = 0xCAFEFACE_BAD0C0DE
		let e: UInt = 0xDECAFBAB_EBADC0DE
		let f: Int8 = 0x0F
		let g: Int16 = 0x0BAD
		let h: Int32 = 0x0BADC0DE
		let i: Int64 = 0x1DEAC0DE_0BADF00D
		let j: Int = 0x1DEAC0DE_0BADF00D

		XCTAssertEqual(a.toBytes(endianness: .big).toHexString(), "de")
		XCTAssertEqual(a.toBytes(endianness: .little).toHexString(), "de")

		XCTAssertEqual(b.toBytes(endianness: .big).toHexString(), "adbe")
		XCTAssertEqual(b.toBytes(endianness: .little).toHexString(), "bead")

		XCTAssertEqual(c.toBytes(endianness: .big).toHexString(), "deadbeef")
		XCTAssertEqual(c.toBytes(endianness: .little).toHexString(), "efbeadde")

		XCTAssertEqual(d.toBytes(endianness: .big).toHexString(), "cafefacebad0c0de")
		XCTAssertEqual(d.toBytes(endianness: .little).toHexString(), "dec0d0bacefafeca")

		XCTAssertEqual(e.toBytes(endianness: .big).toHexString(), "decafbabebadc0de")
		XCTAssertEqual(e.toBytes(endianness: .little).toHexString(), "dec0adebabfbcade")

		XCTAssertEqual(f.toBytes(endianness: .big).toHexString(), "0f")
		XCTAssertEqual(f.toBytes(endianness: .little).toHexString(), "0f")

		XCTAssertEqual(g.toBytes(endianness: .big).toHexString(), "0bad")
		XCTAssertEqual(g.toBytes(endianness: .little).toHexString(), "ad0b")

		XCTAssertEqual(h.toBytes(endianness: .big).toHexString(), "0badc0de")
		XCTAssertEqual(h.toBytes(endianness: .little).toHexString(), "dec0ad0b")

		XCTAssertEqual(i.toBytes(endianness: .big).toHexString(), "1deac0de0badf00d")
		XCTAssertEqual(i.toBytes(endianness: .little).toHexString(), "0df0ad0bdec0ea1d")

		XCTAssertEqual(j.toBytes(endianness: .big).toHexString(), "1deac0de0badf00d")
		XCTAssertEqual(j.toBytes(endianness: .little).toHexString(), "0df0ad0bdec0ea1d")
	}

	func testToBytesFloatValues() throws {
		#if arch(arm64)
		let a: Float16 = -427.25
		#endif
		let b: Float32 = -0.468345582
		let c: Float64 = -4.3128027387708127e+148

		#if arch(arm64)
		XCTAssertEqual(a.toBytes(endianness: .big).toHexString(), "dead")
		XCTAssertEqual(a.toBytes(endianness: .little).toHexString(), "adde")
		#endif

		XCTAssertEqual(b.toBytes(endianness: .big).toHexString(), "beefcafe")
		XCTAssertEqual(b.toBytes(endianness: .little).toHexString(), "fecaefbe")

		XCTAssertEqual(c.toBytes(endianness: .big).toHexString(), "decafbabebadc0de")
		XCTAssertEqual(c.toBytes(endianness: .little).toHexString(), "dec0adebabfbcade")
	}
}
