import Foundation

/// If you set up as an enum (which is probably the easiest), Swift requires that you implement the enum values statically (like a
/// StaticString, but for UInt32). I tried to use a macro to generate the value from a four character string (which in theory should
/// work), but it didn't work. Maybe I just don't know enough about macros (which is definitely true). However, until I can determine
/// a better solution, you can refer to [this table](https://www.utf8-chartable.de) to determine your hex values.
public protocol MagicNumber: RawRepresentable, Hashable {
	var rawValue: UInt32 { get }

	init?(rawValue: UInt32)
	init?(stringValue: String)
	init?(data: Data)
}

public extension MagicNumber {
	init?(stringValue: String) {
		let data = Data(stringValue.utf8)
		self.init(data: data)
	}

	init?(data: Data) {
		guard data.count == 4 else {
			return nil
		}
		let value = data.withUnsafeBytes { pointer in
			pointer.load(as: UInt32.self)
		}
		self.init(rawValue: value)
	}
}
