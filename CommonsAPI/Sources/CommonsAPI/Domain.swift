//
//  Domain.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 09.02.26.
//

// Partly copied from Wikipedia iOS app repo

    public struct Domain {
        public static let wikipedia = "wikipedia.org"
        public static let wikidata = "wikidata.org"
        public static let commons = "commons.wikimedia.org"
        public static let mediaWiki = "www.mediawiki.org"
        public static let wikispecies = "species.wikimedia.org"
        public static let englishWikipedia = "en.wikipedia.org"
        public static let testWikipedia = "test.wikipedia.org"
        public static let wikimedia = "wikimedia.org"
        public static let metaWiki = "meta.wikimedia.org"
        public static let wikimediafoundation = "wikimediafoundation.org"
        public static let uploads = "upload.wikimedia.org"
        public static let wikibooks = "wikibooks.org"
        public static let wiktionary = "wiktionary.org"
        public static let wikiquote = "wikiquote.org"
        public static let wikisource = "wikisource.org"
        public static let wikinews = "wikinews.org"
        public static let wikiversity = "wikiversity.org"
        public static let wikivoyage = "wikivoyage.org"
        
        static let centralAuthCookieSourceDomain = commons.withDotPrefix
        
        static let centralAuthCookieTargetDomains = [
            Domain.wikimedia.withDotPrefix,
            Domain.commons.withDotPrefix,
            Domain.wikidata.withDotPrefix,
            
            Domain.mediaWiki.withDotPrefix,
            Domain.wiktionary.withDotPrefix,
            Domain.wikiquote.withDotPrefix,
            Domain.wikibooks.withDotPrefix,
            Domain.wikisource.withDotPrefix,
            Domain.wikinews.withDotPrefix,
            Domain.wikiversity.withDotPrefix,
            Domain.wikispecies.withDotPrefix,
            Domain.wikivoyage.withDotPrefix,
            Domain.metaWiki.withDotPrefix
        ]
    }

private extension String {
    var withDotPrefix: String {
        return "." + self
    }
}
