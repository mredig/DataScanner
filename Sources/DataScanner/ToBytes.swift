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
		Data.valueTypeToBytes(self, endianness: endianness)
	}
}

public extension Data {
	/// This will only work on self contained value types. If it contains a reference type as a property (public or hidden) it won't work.
	/// It might not even work on structs with multiple stored properties. It's really meant for things like Int, UInt, Float, Double, Bool,
	/// etc. Use at your own risk
	@inline(__always)
	static func valueTypeToBytes<ValueType>(
		_ value: ValueType,
		endianness: Endianness = .big
	) -> Data {
		let typeSize = MemoryLayout.size(ofValue: value)

		let pointer = UnsafeMutablePointer<ValueType>.allocate(capacity: 1)
		pointer.pointee = value
		defer { pointer.deallocate() }
		let rawPointer = UnsafeRawPointer(pointer).bindMemory(to: UInt8.self, capacity: typeSize)

		var data = Data(count: MemoryLayout.size(ofValue: value))
		if endianness == .systemEndianness {
			for i in 0..<typeSize {
				let bytePointer = rawPointer.advanced(by: i)
				data[i] = bytePointer.pointee
			}
			return data
		} else {
			for i in 0..<typeSize {
				let advancing = typeSize - (i + 1)
				let bytePointer = rawPointer.advanced(by: advancing)
				data[i] = bytePointer.pointee
			}
			return data
		}
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

public extension Bool {
	func toByte() -> Data {
		switch self {
		case true:
			Data([1])
		case false:
			Data([0])
		}
	}
}

