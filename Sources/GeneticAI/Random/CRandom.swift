// swiftlint:disable identifier_name

import Foundation

public class CRandom: Randomable {
    @usableFromInline
    var value: UInt64  = 55
    @usableFromInline
    let kMax = 32768

    public init() {
        value = UInt64(NSDate().timeIntervalSinceReferenceDate)
    }

    public init(_ seed: UInt64) {
        value = seed
    }

    public init(_ seed: String) {
        value = UInt64(seed.seedHash())
    }

    public func seed(_ string: String) {
        value = UInt64(string.seedHash())
    }

    @discardableResult
    @inlinable @inline(__always)
    func next() -> UInt64 {
        value = value &* 1103515245 &+ 12345
        return (value / 65536) % 32768
    }

    @inlinable @inline(__always)
    public func get() -> Int {
        return abs(Int(truncatingIfNeeded: next()))
    }

    @inlinable @inline(__always)
    public func get(min: Int, max: Int) -> Int {
        guard (max - min + 1) > 0 else { return 0 }
        return (abs(get()) % (max - min + 1)) + min
    }

    @inlinable @inline(__always)
    public func get() -> UInt64 {
        return next()
    }

    @inlinable @inline(__always)
    public func get(min: UInt64, max: UInt64) -> UInt64 {
        return (get() % (max - min + 1)) + min
    }

    @inlinable @inline(__always)
    public func get() -> Float {
        return Float(next()) / Float(kMax)
    }

    @inlinable @inline(__always)
    public func get(min: Float, max: Float) -> Float {
        return (abs(get()) * (max - min)) + min
    }

    @inlinable @inline(__always)
    public func get<T>(_ set: Set<T>) -> T? {
        return get(Array(set))
    }

    @inlinable @inline(__always)
    public func get<T>(_ array: [T]) -> T? {
        guard array.count > 0 else { return nil }
        return array[get(min: 0, max: array.count-1)]
    }

    @inlinable @inline(__always)
    public func get<T>(_ buffer: UnsafeMutableBufferPointer<T>) -> T {
        return buffer[get(min: 0, max: buffer.count-1)]
    }

    @inlinable @inline(__always)
    public func shuffled<T>(_ array: [T]) -> [T] {
        var results = [T]()
        for item in array {
            results.insert(item, at: get(min: 0, max: results.count))
        }
        return results
    }

    @inlinable @inline(__always)
    public func remove<T>(_ array: inout [T]) -> T? {
        if array.count == 0 {
            return nil
        }
        let idx = get(min: 0, max: array.count-1)
        let value = array[idx]
        array.remove(at: idx)
        return value
    }

    @inlinable @inline(__always)
    public func maybe(_ value: Float) -> Bool {
        return (Float(next()) / Float(kMax)) <= value
    }
}
