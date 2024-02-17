import Foundation

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
