import Foundation

public protocol PartFlags: OptionSet where RawValue: FixedWidthInteger {
	static var hasChildParts: Self.Element { get }
}

public struct BasicFlags: PartFlags {
	public static let hasChildParts: BasicFlags = BasicFlags(rawValue: 1)

	public let rawValue: UInt8

	public init(rawValue: UInt8) {
		self.rawValue = rawValue
	}
}
