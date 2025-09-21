# CommonsFinder

CommonsFinder is an iOS app to explore and upload media to [Wikimedia Commons](https://commons.wikimedia.org).

The test version can be installed via TestFlight: https://testflight.apple.com/join/15KtE2Mn

## Features

The project is **currently work-in-progress**, but several core features already work. You can:

- upload single images
- save image-drafts for later uploading
- search images and categories (including wikidata items that are depicted in images)
- view images and their metadata, including categories and depicted wikidata items
- explore images and locations on a map
- view a list of uploads of a user
- view a list of images per category + depicted item
- history of previously viewed images
- works well with increased font sizes and other accessibility system features
- dark and light color schemes


## Demo videos and screenshots
Here are some demo videos and screenshots representing the development state of ~ 2025-06-05.

### Drafts / Uploading
[2025-06-05-CommonsFinder-drafting.webm](https://github.com/user-attachments/assets/de33119a-dfde-4492-bd2b-fd964601f079)

### Search
[2025-06-05-CommonsFinder-search.webm](https://github.com/user-attachments/assets/d8b1019a-7a64-4348-b09e-b889549060b8)

### Exploring Categories
[2025-06-05-CommonsFinder-category-exploration.webm](https://github.com/user-attachments/assets/79b1997f-6508-47c9-b5c1-88b1e51c408d)

### Map
[2025-06-05-CommonsFinder-map.webm](https://github.com/user-attachments/assets/45fa46a9-ebe6-4d19-964e-2149ce509a14)

## Roadmap

I plan an implement more functionality in the next months and improve on the current ones. The priority is on these topics next:

- [ ] fullscreen (and zoomable) view for images
- [x] bookmark images and categories/items
- [ ] improve map: better live-location experience, direct opening of single items on the map
- [x] improve search: search for categories, currently only images can be searched
- [x] when uploading, suggest nearby location categories/items to add
- [ ] make upload more robust in some areas (eg. check if filename already exists)
- [ ] editing of uploaded files (eg. changing the caption or adding categories)
- [ ] improve author and attribution editing and viewing

Those above have priority, but there are many more things planned. Here is a rough overview of what I would like the app to be able to do at some point:

- multi-image/batch uploads
- dedicated panorama viewer for wide-aspect/panorama images
- supporting sending wiki-love
- visible qualifiers for depict items etc.
- privacy features: eg. support face and number plate detection, to allow the user to blur face and number plates without using an external image editor
- investigate how to allow users to contribute to recurring events and contests like "wiki loves earth" without manually editing wikitext (if thats possible)
- explore if OAuth is feasible. It would be great, because log-in would be easier when the user already has the credentials stored in the keychain for the wikimedia domains. Technically, it should be possible but there is conflicting information regarding security, eg. if it's ok to use inside an app or if it should only be used in hosted applications. This topic needs more investigation and communication with other people from the Wikimedia Foundation
- audio file support, video support, 3d-files?

At some point I'd also love to see an iPadOS and MacOS adaptation. This should not be too difficult, since the UI-code is mainly SwiftUI and should be relatively straight-forward to port and adapt to other Apple platforms in the future.


## App Name

The idea for "CommonsFinder" came from combining the [view*finder*](https://en.wikipedia.org/wiki/Viewfinder) in cameras with the word "commons". Since the aspect of taking photos mobile and on-the-go and contributing them to wiki commons is one goal of this app, using a camera's viewfinder as part of the app name seemed fitting. The word "finder" is also used in combination like path*finder* and Mac users may be familiar  with the file manager "Finder", so the name hopefully evokes a theme of both photo-taking ("viewfinder"), exploring ("pathfinder"), finding ("find") and also managing and organizing files (file manager "Finder"); and all that in relation to "commons", both regarding the project Wikimedia Commons, but also in a more general and broader meaning of the word.

Another app name idea was "CommonExplorer" (or alternatively "CommonsExplorer"), but unfortunately the word is a bit too long to fit on the homescreen without being truncated, so the current "CommonsFinder" was chosen instead.

Although I am happy with the current name, I am open to other suggestins if they fit the use-case well and are short enough to not be truncated when the app(-icon) is placed on the home screen, so unfortunately not more than 11-13 characters, it seems.


## Contributing and Testing

The best way to curently help, is by using the TestFlight releases and especially reporting crashes (should they occur) as well as other experience breaking issues: https://testflight.apple.com/join/15KtE2Mn


Regarding MRs and Issues: Although a lot of stuff already works well, the project and code base is still work-in-progress and several parts are actively being worked on. I value your and my time and therefore do not consider MR's to avoid duplicate over conflicting work.
Once the development becomes slower-paced and the code base settles a bit more I'll be happy to consider contributions.

## Funding and Donations

The app is currently developed in my free time and don't currently recieve any funding for the development of this app. So if you like the app and want to actively support my ongoing work in a financial way, I do also accept and appreciate any donations :) !

Donations are currently possible via Github-sponsors.

## License

I have **not yet finally decided** on the open-source license. I would like to use GPL-3 or AGPL-3, but as far as I know there are some complications in regards to publishing to the iOS AppStore, especially when accepting contributions (MRs/PRs) from others. I will need some more time to decide on that and gather input from other open source iOS-apps projects who use GPL.

