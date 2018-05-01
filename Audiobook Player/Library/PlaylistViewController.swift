//
//  PlaylistViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 4/29/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import MBProgressHUD

class PlaylistViewController: BaseListViewController {

    var currentPlaylist: Playlist!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = self.currentPlaylist.title
        
        self.bookArray = self.currentPlaylist.books
    }

    override func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard destinationIndexPath.section == 0 else {
            return
        }

        let book = self.bookArray[sourceIndexPath.row]
        self.bookArray.remove(at: sourceIndexPath.row)
        self.bookArray.insert(book, at: destinationIndexPath.row)
        self.currentPlaylist.books = self.bookArray
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForReorderFromRowAt sourceIndexPath: IndexPath, to proposedDestinationIndexPath: IndexPath, snapshot: UIView?) -> IndexPath {

        guard proposedDestinationIndexPath.section == 0 else {
            return sourceIndexPath
        }

        return proposedDestinationIndexPath
    }

    override func tableView(_ tableView: UITableView, sourceIndexPath: IndexPath, overIndexPath: IndexPath, snapshot: UIView) {
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}

extension PlaylistViewController {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let book = self.bookArray[indexPath.row] as? Book else {
            return
        }

        self.play(book)
    }
}
