//
//  ProceduralBackground.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.08.25.
//

import Algorithms
import NaturalLanguage
import RegexBuilder
import SwiftUI

struct ProceduralBackground: View {
    let categoryName: String
    var body: some View {
        proceduralMeshGradient(from: categoryName)
    }
}

@ViewBuilder
private func proceduralMeshGradient(from string: String) -> MeshGradient {
    let colors = categoryColors(for: string)
    let hues = categoryHues(for: string)
    let points: [SIMD2<Float>] = hues.adjacentPairs()
        .map({ (x, y) in
            .init(x: Float(x), y: Float(y))
        })
    let dim = Int(sqrt(Double(points.count)))


    MeshGradient(width: dim, height: dim, points: points, colors: colors, background: colors.first?.opacity(0.8) ?? .clear, smoothsColors: true)
}


private func categoryHues(for string: String) -> [Double] {
    string
        .lowercased()
        .adjacentPairs()
        .map { [$0.0, $0.1] }
        .map { $0.prefix(2).hashValue }
        .map { v in
            (Double(v) - Double(Int.min)) / Double(UInt.max)
        }
}

private func categoryColors(for string: String) -> [Color] {
    let colors: [Color] = categoryHues(for: string)
        .map { hue in
            .init(hue: hue, saturation: 0.6, brightness: 0.5, opacity: 1)
        }
    return colors
}


#Preview {
    let categorieNames = [
        "apples of the forrest",
        "people of france",
        "people of Paris",
        "sheep walking",
        "people with sheep",
        "aaa aaa",
        "Ananas food",
        "Banana Food",
        "Banana dessert",
        "Berlin-Adlershof",
        "Berlin-Kreuzberg",
        "Berlin-Friedrichshain",
        "Berlin-Zehlendorf",
        "Potsdam-Babelsberg",
        "Potsdam-Jägervorstadt",
        "Potsdam-West",
        "Potsdam-Drewitz",
        "zzz zzz",
        "3 continents",
        "Streets of Berlin",
        "Streets of New York City in the 1990s",
        "Berlin",
        "Berlin Wall",
        "Sundown in Paris",
        "cities in Africa",
        "cities in America",
        "Cities in Europe",
        "Flux Compensator",
        "Fluvial geomorphology",

    ]

    ScrollView(.vertical) {
        LazyVGrid(columns: [.init(), .init(), .init()]) {
            ForEach(categorieNames, id: \.self) { categoryName in
                ProceduralBackground(categoryName: categoryName)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Text(categoryName)
                    }
            }
        }
    }
}
