//
//  Sequence+Distinct.swift
//  Remaster
//
//  Created by Cameron Slash on 11/20/26.
//

import Foundation

extension Sequence where Iterator.Element: Hashable {
    public func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}

extension Sequence {
    public func sorted<Value>(by keyPath: KeyPath<Element, Value>, using areInIncreasingOrder: (Value, Value) throws -> Bool) rethrows -> [Element] {
        try self.sorted {
            try areInIncreasingOrder($0[keyPath: keyPath], $1[keyPath: keyPath])
        }
    }
    
    public func sorted<Value: Comparable>(sortedBy keyPath: KeyPath<Element, Value>, direction: SortDirection = .asc) -> [Element] {
        self.sorted(by: keyPath, using: direction.comparator())
    }
    
    public func sorted(by sortDescriptor: NSSortDescriptor) -> [Element] {
        self.sorted { sortDescriptor.compare($0, to: $1) == .orderedAscending }
    }
}

public enum SortDirection: CaseIterable {
    case asc, desc
}

extension SortDirection {
    public func comparator<T: Comparable>() -> (T,T) -> Bool {
        switch self {
        case .asc:
            return (<)
        case .desc:
            return (>)
        }
    }
}
