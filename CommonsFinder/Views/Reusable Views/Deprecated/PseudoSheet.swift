////
////  PseudoSheet.swift
////  CommonsFinder
////
////  Created by Tom Brewe on 11.03.25.
////
//
//import SwiftUI
//
//extension View {
//    func pseudoSheet<SheetContent: View>(
//        isPresented: Binding<Bool>,
//        @ViewBuilder content: @escaping () -> SheetContent
//    ) -> some View {
//        modifier(PseudoSheet(isPresented: isPresented, sheetContent: content))
//    }
//}
//
//

//
//private struct PseudoSheet<SheetContent: View>: ViewModifier {
//    @Binding var isPresented: Bool
//    @ViewBuilder var sheetContent: () -> SheetContent
//
//    @GestureState private var verticalTranslation: Double = 0
//
//    func body(content: Content) -> some View {
//        //        let dragGesture = DragGesture(minimumDistance: 5)
//        //            .updating($verticalTranslation) { value, state, transaction in
//        //                transaction.isSheetDragging = true
//        //                state = value.translation.height
//        //            }
//        //            .onEnded { value in
//        //                if value.predictedEndTranslation.height > 100 {
//        //                    isPresented = false
//        //                }
//        //            }
//
//        content
//            .overlay(alignment: .bottom) {
//
//                ZStack {
//                    if isPresented {
//                        sheetContent()
//                            .clipShape(ViewConstants.mapSheetContainerShape)
//                            // NOTE: .glassEffect is glitchy in combination with image navigation
//                            .background(.thinMaterial, in: ViewConstants.mapSheetContainerShape)
//                            .padding()  // Outer padding to show the view behind
//                            .geometryGroup()
//                            .compositingGroup()
//                            .shadow(radius: 30)
//                            // This offset handles the interactive gesture/finger movement
//                            .offset(y: verticalTranslation)
//                            //                            .gesture(dragGesture)
//                            .transaction(value: verticalTranslation) { transaction in
//                                if transaction.isDragging {
//                                    // During interactivity of the user, vertically dragging the sheet
//                                    // print("dragging")
//                                    transaction.animation = .interactiveSpring()
//                                } else {
//                                    // When the @GestureState resets the offset to 0
//                                    // print("idle")
//                                    transaction.animation = .spring
//                                }
//                            }
//                            // This transition handles the toggling of `isPresented`
//                            .transition(
//                                .asymmetric(
//                                    insertion: .push(from: .bottom),
//                                    removal: .push(from: .top)
//                                ))
//                    }
//                }
//                .animation(.snappy, value: isPresented)
//
//            }
//    }
//}
