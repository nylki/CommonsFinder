Color(.emptyWikiItemBackground)
                    .overlay {
                        if let imageRequest = item.base.thumbnailImage {
                            LazyImage(request: imageRequest, transaction: .init(animation: .linear)) { imageState in
                                if let image = imageState.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .scaledToFill()
                                } else {
                                    Color.clear
                                }
                            }
                        }
                    }
                    .overlay {
                        if item.base.thumbnailImage != nil {
                            LinearGradient(
                                stops: [
                                    .init(color: .init(white: 0, opacity: 0), location: 0),
                                    .init(color: .init(white: 0, opacity: 0.1), location: 0.35),
                                    .init(color: .init(white: 0, opacity: 0.2), location: 0.5),
                                    .init(color: .init(white: 0, opacity: 0.8), location: 1),
                                ], startPoint: .top, endPoint: .bottom)
                        }
                    }