//
//  Sequence+Distinct.swift
//  Remaster
//
//  Created by Cameron Slash on 11/20/26.
//

extension Sequence where Iterator.Element: Hashable {
    public func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}
