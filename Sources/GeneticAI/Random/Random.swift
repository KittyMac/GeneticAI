import Foundation

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
