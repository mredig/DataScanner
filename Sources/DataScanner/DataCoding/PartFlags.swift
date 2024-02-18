import Foundation

/// In the current implementation, you can only use one flag type for the entire blob. However, you can share bit positions
/// between non similar sections, just make sure that `hasChildParts` always resolves to the same bit position.
public protocol PartFlags: OptionSet where RawValue: FixedWidthInteger {
	static var hasChildParts: Self.Element { get }
}

/// A simple, concrete implementation of PartFlags, including `hasChildParts`. You may extend in any bit position other than `1`.
public struct BasicFlags: PartFlags {
	public static let hasChildParts: BasicFlags = BasicFlags(rawValue: 1)

	public let rawValue: UInt8

	public init(rawValue: UInt8) {
		self.rawValue = rawValue
	}
}
