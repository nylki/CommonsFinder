//
//  LicensePicker.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 30.01.25.
//

import SwiftUI

struct LicensePicker: View {
    @Binding var selectedLicense: DraftMediaLicense?
    @Environment(\.dismiss) private var dismiss

    // TODO: show licensing tutorial image
    // with some interaction:

    //                Image(.licenseTutorial)
    //                    .resizable()
    //                    .scaledToFit()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(DraftMediaLicense.allCases, id: \.rawValue) { license in
                    LicenseButton(license: license, isSelected: license == selectedLicense) {
                        selectedLicense = license
                    }
                }
            }
            .compositingGroup()
            .scenePadding()
            //            .shadow(radius: 200)
            .navigationTitle("Choose a License")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Link(destination: URL(string: "https://commons.wikimedia.org/wiki/Commons:Choosing_a_license")!) {
                        Label("help", systemImage: "questionmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", systemImage: "checkmark", role: .confirm, action: dismiss.callAsFunction)
                }
            }
            .frame(minHeight: 0, maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))

        }
        .presentationDetents([.fraction(0.63), .large])
    }
}

private struct LicenseButton: View {
    let license: DraftMediaLicense
    let isSelected: Bool

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {

                Text(license.shortDescription).bold()
                Text(license.explanation)
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(isSelected ? Color.white : .primary)
            .labelStyle(ExpandingLabelStyle())
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview("LicensePicker") {
    @Previewable @State var selected: DraftMediaLicense? = nil
    Color.clear.sheet(isPresented: .constant(true)) {
        LicensePicker(selectedLicense: $selected)
    }
}


#Preview("LicensePicker as Sheet") {
    @Previewable @State var selected: DraftMediaLicense? = nil

    ZStack {}
        .sheet(isPresented: .constant(true)) {
            LicensePicker(selectedLicense: $selected)
                .presentationDetents([.medium, .large])
        }
}
