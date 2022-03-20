// swiftlint:disable identifier_name

import Foundation

class CRandom: Randomable {

    var value: UInt64  = 55

    typealias State = (UInt64, UInt64, UInt64, UInt64)
    var state: State = (0, 0, 0, 0)

    init() {
        value = UInt64(NSDate().timeIntervalSinceReferenceDate)
    }

    init(_ seed: UInt64) {
        value = seed
    }

    init(_ seed: String) {
        value = UInt64(seed.hashValue)
    }

    public func seed(_ string: String) {
        value = UInt64(string.hashValue)
    }

    @discardableResult
    private func next() -> UInt64 {
        value = value &* 1103515245 &+ 12345
        return (value / 65536) % 32768
    }

    public func get() -> Int {
        return abs(Int(truncatingIfNeeded: next()))
    }

    public func get(min: Int, max: Int) -> Int {
        return (abs(get()) % (max - min + 1)) + min
    }

    public func get() -> UInt64 {
        return next()
    }

    public func get(min: UInt64, max: UInt64) -> UInt64 {
        return (get() % (max - min + 1)) + min
    }

    public func get() -> Float {
        return Float(next()) / Float(UInt64.max)
    }

    public func get(min: Float, max: Float) -> Float {
        return (abs(get()) * (max - min)) + min
    }

    public func get<T>(_ set: Set<T>) -> T {
        return get(Array(set))
    }

    public func get<T>(_ array: [T]) -> T {
        return array[get(min: 0, max: array.count-1)]
    }

    public func shuffled<T>(_ array: [T]) -> [T] {
        var results = [T]()
        for item in array {
            results.insert(item, at: get(min: 0, max: results.count))
        }
        return results
    }

    public func remove<T>(_ array: inout [T]) -> T? {
        if array.count == 0 {
            return nil
        }
        let idx = get(min: 0, max: array.count-1)
        let value = array[idx]
        array.remove(at: idx)
        return value
    }

    public func maybe(_ value: Float) -> Bool {
        return (Float(next()) / Float(UInt64.max)) <= value
    }
}
