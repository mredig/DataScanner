import Foundation

public extension FixedWidthInteger {
	func toBytes(endianness: Endianness = .big) -> Data {
		let buffer = UnsafeMutableBufferPointer<Self>.allocate(capacity: 1)
		defer { buffer.deallocate() }
		switch endianness {
		case .little:
			buffer[0] = self.littleEndian
		case .big:
			buffer[0] = self.bigEndian
		}
		return Data(buffer: buffer)
	}
}

public extension BinaryFloatingPoint {
	func toBytes(endianness: Endianness = .big) -> Data {
		let buffer = UnsafeMutableBufferPointer<Self>.allocate(capacity: 1)
		defer { buffer.deallocate() }
		buffer[0] = self
		let data = Data(buffer: buffer)
		guard endianness != .systemEndianness else {
			return data
		}
		return Data(data.reversed())
	}
}

public extension String {
	func toBytes(nullTerminated: Bool = false) -> Data {
		var out = Data(self.utf8)
		if nullTerminated {
			out.append(contentsOf: [0])
		}
		return out
	}
}
