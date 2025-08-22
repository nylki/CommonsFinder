//
//  Array+safeIndex.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 21.08.25.
//


extension Array {
    public subscript(safeIndex index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }

        return self[index]
    }
}
