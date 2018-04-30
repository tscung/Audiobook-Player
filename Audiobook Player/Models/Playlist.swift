//
//  Playlist.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 4/16/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

struct Playlist: LibraryObject {
    var percentCompletedRoundedString: String

    var title: String

    var author: String

    var artwork: UIImage

    var books: [LibraryObject]
}
