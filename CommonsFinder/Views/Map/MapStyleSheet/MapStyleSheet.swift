//
//  MapStyleSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.12.25.
//

import MapKit
import SwiftUI

struct MapStyleSheet: View {
    @Binding var activeStyle: WrappedMapStyle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                let mapPreviewRegion = MKCoordinateRegion(center: .init(latitude: 40.750994, longitude: -73.966921), latitudinalMeters: 300, longitudinalMeters: 300)
                let map = Map(initialPosition: .region(mapPreviewRegion))
                    .mapControlVisibility(.hidden)
                    .allowsHitTesting(false)
                    .frame(width: 110, height: 150)

                HStack(spacing: 25) {
                    ForEach(WrappedMapStyle.allCases) { style in
                        let isSelected = activeStyle == style
                        Button {
                            activeStyle = style
                        } label: {
                            Label {
                                Text(style.labelText)
                            } icon: {
                                map.mapStyle(style.asMKMapStyle)
                            }
                            .labelStyle(MapStyleLabelStyle(isSelected: isSelected))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .animation(.default, value: activeStyle)
            .tint(.primary)
            .padding(.bottom)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("Map Style")
                        .font(.title2)
                        .bold()
                }
                ToolbarItem(placement: .automatic) {
                    Button("close", systemImage: "xmark", action: dismiss.callAsFunction)
                        .labelStyle(.iconOnly)
                }
            }

        }
        .presentationDetents([.fraction(0.28)])
    }
}

private struct MapStyleLabelStyle: LabelStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            ZStack {
                configuration.icon
                    .frame(width: 110, height: 110)
                    .clipShape(.rect(cornerRadius: 20, style: .circular))
                    .padding(isSelected ? 5 : 0)
                if isSelected {
                    RoundedRectangle(cornerRadius: 23, style: .circular)
                        .stroke(.accent, style: .init(lineWidth: 1.5))

                }
            }
            .fixedSize()

            configuration.title
        }
    }
}

#Preview {
    HStack {
        Label(title: { Text("a") }, icon: { Color.red }).labelStyle(MapStyleLabelStyle(isSelected: false))
        Label(title: { Text("b") }, icon: { Color.red }).labelStyle(MapStyleLabelStyle(isSelected: true))
        Label(title: { Text("c") }, icon: { Color.red }).labelStyle(MapStyleLabelStyle(isSelected: false))
    }

}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var mapStyle = WrappedMapStyle.standard

    ZStack {
        Color.gray.ignoresSafeArea()
        Button("show") { isPresented = true }
            .buttonStyle(.borderedProminent)
    }

    .sheet(isPresented: $isPresented) {
        MapStyleSheet(activeStyle: $mapStyle)
    }


}
