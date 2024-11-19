import Foundation
import Testing
import DataScanner

struct MagicNumberTests {
	struct Foo: MagicNumber {
		var rawValue: UInt32

		init(rawValue: UInt32) {
			self.rawValue = rawValue
		}
	}

	@Test func magicNumber() {
		let magic = Foo(stringValue: "abcd")
		#expect(magic?.rawValue == 0x61626364)
	}

	@Test func invalidMagicNumber() {
		let magic = Foo(stringValue: "abcde")
		#expect(magic == nil)
	}

	@Test func invalidMagicNumber2() {
		let magic = Foo(stringValue: "cde")
		#expect(magic == nil)
	}

	@Test func leMagicNumber() {
		let magic = Foo(data: Data([0x61, 0x62, 0x63, 0x64]), endianness: .little)
		#expect(magic?.rawValue == 0x64636261)
	}
}
