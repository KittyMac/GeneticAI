import Foundation

extension String {
    public func seedHash() -> UInt32 {
        var hash: UInt32 = 0
        var idx: UInt32 = 0
        for char in self {
            let optionalASCIIvalue = char.unicodeScalars.filter {$0.isASCII}.first?.value
            if let ASCIIvalue = optionalASCIIvalue {
                hash = (hash &+ ASCIIvalue &* idx) &* (hash &+ ASCIIvalue &* idx)
            }
            idx += 1
        }
        return hash
    }
}

public protocol Randomable {
    func seed(_ string: String)

    func get() -> UInt64
    func get(min: UInt64, max: UInt64) -> UInt64

    func get() -> Int
    func get(min: Int, max: Int) -> Int

    func get() -> Float
    func get(min: Float, max: Float) -> Float

    func get<T>(_ set: Set<T>) -> T
    func get<T>(_ array: [T]) -> T
    func get<T>(_ buffer: UnsafeMutableBufferPointer<T>) -> T
    func shuffled<T>(_ array: [T]) -> [T]

    func remove<T>(_ array: inout [T]) -> T?

    func maybe(_ value: Float) -> Bool
}
