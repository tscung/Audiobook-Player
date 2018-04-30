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
    }
}

extension PlaylistViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.currentPlaylist.books.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let spacer = tableView.reorder.spacerCell(for: indexPath) {
            return spacer
        }

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as? BookCellView else {
            return UITableViewCell()
        }

        let book = self.currentPlaylist.books[indexPath.row]

        cell.titleLabel.text = book.title
        cell.authorLabel.text = book.author

        // NOTE: we should have a default image for artwork
        cell.artworkImageView.image = book.artwork

        // Load stored percentage value
        cell.completionLabel.text = book.percentCompletedRoundedString
        cell.completionLabel.textColor = UIColor.flatGreenColorDark()

        return cell
    }
}

extension PlaylistViewController {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let book = self.currentPlaylist.books[indexPath.row] as? Book {
            play(book)
        }
    }

    func play(_ book: Book) {
        setupPlayer(book: book)
    }

    func setupPlayer(book: Book) {
        // Make sure player is for a different book
        guard PlayerManager.sharedInstance.fileURL != book.fileURL else {
            showPlayerView(book: book)

            return
        }

        MBProgressHUD.showAdded(to: self.view, animated: true)

        // Replace player with new one
        PlayerManager.sharedInstance.load(book) { (_) in
            self.showPlayerView(book: book)
        }
    }

    func showPlayerView(book: Book) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.currentBook = book

            self.present(playerVC, animated: true)
        }
    }
}
