import Foundation

public enum Endianness {
	case little
	case big

	public static let systemEndianness: Endianness = {
		#if canImport(Darwin)
		let system = CFByteOrderGetCurrent()
		return Endianness(system) ?? .little
		#else
		let testValue: UInt32 = 0x04030201

		let buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: 1)
		defer { buffer.deallocate() }
		buffer[0] = testValue

		let rawBuffer = UnsafeMutableRawBufferPointer(buffer)

		if rawBuffer[0] == 1 {
			return .little
		} else {
			return .big
		}
		#endif
	}()

	#if canImport(Darwin)
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
	#endif
}
