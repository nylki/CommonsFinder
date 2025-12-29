//
//  FilenameSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.12.25.
//

import SwiftUI
import FrameUp
import TipKit

struct FileNameTypeTuple: Equatable, Hashable, Identifiable {
    let name: String
    let type: FileNameType
    
    var id: String { type.description }
}

struct FilenameSheet: View {
    let model: MediaFileDraftModel
    
    @State private var editedFilename: String = ""
    @State private var choosenFilenameType: FileNameType?
    
    @State private var suggestedFilenames: [FileNameTypeTuple] = []
    @FocusState private var isEditing: Bool
    @Namespace private var namespace
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        @Bindable var model = model
        NavigationStack {
            
            VStack(alignment: .leading) {
                
  
                    TextField("Filename", text: $editedFilename, axis: .vertical)
                        .focused($isEditing)
                        .textInputAutocapitalization(.sentences)
                        .font(.title2)

                        .textFieldStyle(.roundedBorder)
                        .clipShape(.rect(cornerRadius: 15))
                    
                    if let choosenFilenameType {
                        HStack(spacing: 5) {
                            Image(systemName: choosenFilenameType.systemIconName)
                            Text(choosenFilenameType.description)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .font(.callout)

                            
                    }
                

                    

                    if choosenFilenameType == .custom {
                        TipView(FilenameTip(), arrowEdge: .top) { action in
                            openURL(.commonsWikiFileNaming)
                        }
                    }

                if !isEditing, !suggestedFilenames.isEmpty {
                    suggestionBox
                        .padding(.top)
                }

            }
            .scenePadding(.horizontal)
            .animation(.default, value: choosenFilenameType)
            .animation(.default, value: isEditing)
            .animation(.default, value: suggestedFilenames.isEmpty)
            .presentationDragIndicator(.hidden)
            .navigationTitle("Choose a Filename")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ok", systemImage: "checkmark", action: dismiss.callAsFunction)
                }
            }
        }
        .onChange(of: editedFilename) {
            guard isEditing, !editedFilename.isEmpty, choosenFilenameType != nil else { return }
            let matchingAutomatic = suggestedFilenames.first(where: { suggestion in
                editedFilename == suggestion.name
            })
            
            if let matchingAutomatic {
                choosenFilenameType = matchingAutomatic.type
            } else {
                choosenFilenameType = .custom
            }
        }
        .onAppear {
            editedFilename = model.draft.name
            choosenFilenameType = model.draft.selectedFilenameType
        }
        .task {
            var generatedSuggestions: [FileNameTypeTuple] = []
            for type in FileNameType.automaticTypes {
                let generatedFilename =
                    await type.generateFilename(
                        coordinate: model.exifData?.coordinate,
                        date: model.draft.inceptionDate,
                        desc: model.draft.captionWithDesc,
                        locale: Locale.current,
                        tags: model.draft.tags
                    ) ?? model.draft.name
                
                generatedSuggestions.append(.init(name: generatedFilename, type: type))
            }
            
            suggestedFilenames = generatedSuggestions
        }
        .onDisappear {
            guard !editedFilename.isEmpty, let choosenFilenameType else { return }
            if editedFilename != model.draft.name || choosenFilenameType != model.draft.selectedFilenameType {
                model.draft.name = editedFilename
                model.draft.selectedFilenameType = choosenFilenameType
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private var suggestionBox: some View {

            GroupBox("suggestions") {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(suggestedFilenames) { suggestion in
                            
                            let isSelectedType = suggestion.type == choosenFilenameType
                            Button {
                                choosenFilenameType = suggestion.type
                                editedFilename = suggestion.name
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(suggestion.type.description)
                                        .foregroundStyle(.primary)
                                        .bold()
                                        
                                    Text(suggestion.name)
                                        .lineLimit(3)
                                        .italic()
                                        .multilineTextAlignment(.leading)

                                        
                                }
                                .padding()
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isSelectedType ? Color.accentColor : Color.clear, lineWidth: 1)
                                }

                            }
                            .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: 0)
                            .frame(height: 150)
                            .tint(.primary)
                        }
                    }
                }

            }
            .geometryGroup()
    
        .animation(.default, value: choosenFilenameType)
        .animation(.default, value: editedFilename)
    }
}

#Preview {
    @Previewable @State var presented = false
    @Previewable @State var model = MediaFileDraftModel.init(existingDraft: .makeRandomDraft(id: "abc"))
    
    Button {
        presented = true
    } label: {
        VStack {
            Text(model.draft.name)
            Text(model.draft.selectedFilenameType.description)
                .foregroundStyle(.secondary)
        }
        
    }
    .sheet(isPresented: $presented) {
        FilenameSheet(model: model)
    }

}
