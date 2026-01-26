import Foundation

/// A property wrapper that provides thread-safe access to a value
@propertyWrapper
public final class ThreadSafe<Value> {
    private var value: Value
    private let lock = NSLock()

    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }

    /// Provides atomic access for read-modify-write operations
    public func modify(_ transform: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        transform(&value)
    }

    /// Provides atomic access for conditional operations
    public func withValue<T>(_ operation: (Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation(value)
    }
}

/// A thread-safe array wrapper with common collection operations
public final class ThreadSafeArray<Element> {
    private var array: [Element] = []
    private let lock = NSLock()

    public init() {}

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return array.count
    }

    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return array.isEmpty
    }

    public func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        array.append(element)
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        array.removeAll()
    }

    public func forEach(_ body: (Element) -> Void) {
        lock.lock()
        let copy = array
        lock.unlock()
        copy.forEach(body)
    }

    public func toArray() -> [Element] {
        lock.lock()
        defer { lock.unlock() }
        return array
    }
}
