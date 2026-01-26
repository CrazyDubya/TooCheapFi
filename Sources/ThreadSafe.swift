import Foundation

/// A property wrapper that provides thread-safe access to a value
@propertyWrapper
final class ThreadSafe<Value> {
    private var value: Value
    private let lock = NSLock()

    init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    var wrappedValue: Value {
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
    func modify(_ transform: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        transform(&value)
    }

    /// Provides atomic access for conditional operations
    func withValue<T>(_ operation: (Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation(value)
    }
}

/// A thread-safe array wrapper with common collection operations
final class ThreadSafeArray<Element> {
    private var array: [Element] = []
    private let lock = NSLock()

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return array.count
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return array.isEmpty
    }

    func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        array.append(element)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        array.removeAll()
    }

    func forEach(_ body: (Element) -> Void) {
        lock.lock()
        let copy = array
        lock.unlock()
        copy.forEach(body)
    }

    func toArray() -> [Element] {
        lock.lock()
        defer { lock.unlock() }
        return array
    }
}
