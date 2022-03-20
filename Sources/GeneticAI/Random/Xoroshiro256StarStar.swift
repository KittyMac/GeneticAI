// https://forums.swift.org/t/deterministic-randomness-in-swift/20835/6

// swiftlint:disable identifier_name

import Foundation

private func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
    return (x << k) | (x >> (64 &- k))
}

class Xoroshiro256StarStar: Randomable {
    typealias State = (UInt64, UInt64, UInt64, UInt64)
    var state: State = (0, 0, 0, 0)

    init() {
        generateSeeds(seed: UInt64(NSDate().timeIntervalSinceReferenceDate))
    }

    init(_ seed: UInt64) {
        generateSeeds(seed: seed)
    }

    init(_ seed: String) {
        generateSeeds(seed: UInt64(abs(seed.hashValue)))
    }

    private func generateSeeds(seed: UInt64) {
        state.0 = seed &* 3216541354
        state.1 = seed &* 23215623
        state.2 = seed &* 328999
        state.3 = seed &* 32956

        for _ in 0..<100 {
            next()
        }
    }

    @discardableResult
    @inlinable @inline(__always)
    func next() -> UInt64 {
        let result = rotl(state.1 &* 5, 7) &* 9

        let t = state.1 << 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3

        state.2 ^= t

        state.3 = rotl(state.3, 45)

        return result
    }

    @inlinable @inline(__always)
    public func seed(_ string: String) {
        generateSeeds(seed: UInt64(abs(string.hashValue)))
    }

    @inlinable @inline(__always)
    public func get() -> Int {
        return abs(Int(truncatingIfNeeded: next()))
    }

    @inlinable @inline(__always)
    public func get(min: Int, max: Int) -> Int {
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
        return Float(next()) / Float(UInt64.max)
    }

    @inlinable @inline(__always)
    public func get(min: Float, max: Float) -> Float {
        return (abs(get()) * (max - min)) + min
    }

    @inlinable @inline(__always)
    public func get<T>(_ set: Set<T>) -> T {
        return get(Array(set))
    }

    @inlinable @inline(__always)
    public func get<T>(_ array: [T]) -> T {
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
        return (Float(next()) / Float(UInt64.max)) <= value
    }
}
