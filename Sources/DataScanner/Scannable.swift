import Foundation

protocol Scannable {
	var count: Int { get }
	var startIndex: Int { get }
	var endIndex: Int { get }

	subscript(offset: Int) -> UInt8 { get }
	subscript(range: Range<Int>) -> Data { get }
}

extension Data: Scannable {}

/// All Filehandles should be privately instantiated and therefore qualify for force try usage (it would only fail if it's a socket, pipe, or if descriptor is closed)
class ScannableFileHandle: Scannable {
	var startIndex: Int { 0 }
	var endIndex: Int { count }

	let count: Int

	private let fileHandle: FileHandle

	init(url: URL) throws {
		guard
			url.isFileURL
		else { throw Error.mustBeFileURL }
		let fileHandle = try FileHandle(forReadingFrom: url)
		self.fileHandle = fileHandle

		let fd = fileHandle.fileDescriptor

		var statbuf = stat()
		guard fstat(fd, &statbuf) == 0 else { throw Error.cannotStatFile }
		switch statbuf.st_mode & S_IFMT {
		case S_IFSOCK, S_IFIFO:
			throw Error.cannotBeASocketOrPipeURL
		default:
			break
		}

		self.count = {
			let currentOffset = try! fileHandle.offset()
			let total = try! fileHandle.seekToEnd()
			try! fileHandle.seek(toOffset: currentOffset)
			return Int(total)
		}()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	subscript(offset: Int) -> UInt8 {
		let currentOffset = try! self.fileHandle.offset()
		try! fileHandle.seek(toOffset: UInt64(offset))
		let data = try! fileHandle.read(upToCount: 1)
		try! fileHandle.seek(toOffset: currentOffset)
		return data![0]
	}

	subscript(range: Range<Int>) -> Data {
		let currentOffset = try! self.fileHandle.offset()
		try! fileHandle.seek(toOffset: UInt64(range.lowerBound))
		let data = try! fileHandle.read(upToCount: range.count)
		try! fileHandle.seek(toOffset: currentOffset)
		return data!
	}

	enum Error: Swift.Error {
		case mustBeFileURL
		case cannotStatFile
		case cannotBeASocketOrPipeURL
	}
}
