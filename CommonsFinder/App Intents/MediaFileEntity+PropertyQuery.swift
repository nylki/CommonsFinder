////
////  MediaFileEntity+PropertyQuery.swift
////  CommonsFinder
////
////  Created by Tom Brewe on 31.10.24.
////
//
//import Foundation
//import AppIntents
//import GRDB
//
//extension MediaFileAppEntityQuery: EntityPropertyQuery {
//    static var sortingOptions: SortingOptions {
//        SortableBy(\MediaFileAppEntity.$name)
//        SortableBy(\MediaFileAppEntity.$captions)
//    }
//
////    func entities(matching comparators: [Predicate<MediaFileAppEntity>], mode: ComparatorMode, sortedBy: [EntityQuerySort<MediaFileAppEntity>], limit: Int?) async throws -> [MediaFileAppEntity] {
////        /*var*/ matchedFiles = try
////    }
//
//    typealias ComparatorMappingType = SQLSpecificExpressible
//
//    static var properties: QueryProperties {
//        Property(\MediaFileAppEntity.$captions) {
//            ContainsComparator { searchValue in
//                MediaFile.filter(MediaFile.Columns.captions.match(.init(matchingAnyTokenIn: "*\(searchValue)*")) )
//            }
//            EqualToComparator { searchValue in
//                MediaFile.Columns.captions == searchValue
//            }
//        }
//
//        Property(\MediaFileAppEntity.$name) {
//            ContainsComparator { searchValue in
//                MediaFile.Columns.name.match(.init(matchingAnyTokenIn: "*\(searchValue)*"))
//            }
//            EqualToComparator { searchValue in
//                MediaFile.Columns.name == searchValue
//            }
//        }
////
////        Property(\MediaFileAppEntity.$categories) {
////            ContainsComparator { searchValue in
////                #Predicate<MediaFileAppEntity> {
////                    $0.categories.contains {category in
////                        category.localizedStandardContains(searchValue)
////                    }
////                }
////            }
////        }
//    }
//}
