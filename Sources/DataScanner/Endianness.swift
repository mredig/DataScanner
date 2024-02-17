import Foundation

public enum Endianness {
	case little
	case big

	public static let systemEndianness: Endianness = {
		let system = CFByteOrderGetCurrent()
		return Endianness(system) ?? .little
	}()

	init?(_ system: __CFByteOrder) {
		switch system {
		case CFByteOrderBigEndian:
			self = .big
		case CFByteOrderLittleEndian:
			self = .little
		default: return nil
		}
	}

	init?(_ byteOrder: CFByteOrder) {
		let systemType = __CFByteOrder(UInt32(byteOrder))
		self.init(systemType)
	}
}
