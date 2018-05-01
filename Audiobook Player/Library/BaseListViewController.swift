//
//  BaseListViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 4/30/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import SwiftReorder
import MBProgressHUD

class BaseListViewController: UIViewController {
    // TableView's datasource
    var bookArray = [LibraryObject]()

    let tableView = UITableView()
    let footerView = UIView()
    var footerHeightConstraint: NSLayoutConstraint!

    let constraintOffset: CGFloat = 16

    override func viewDidLoad() {
        super.viewDidLoad()

        let margins = self.view.layoutMarginsGuide

        //should enforce in some way that the footer should be initialized first
        self.addFooter(margins)
        self.addTable(margins)

        self.setupTable()

        // register for percentage change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.updatePercentage(_:)), name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil)

        // register notifications when the book is ready
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady), name: Notification.Name.AudiobookPlayer.bookReady, object: nil)

        // register notifications when the book is played
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookPlayed), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)

        // register notifications when the book is paused
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookPaused), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)

        // register for book end notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookEnd(_:)), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
    }

    func addFooter(_ margins: UILayoutGuide) {
        self.footerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.footerView)
        self.footerHeightConstraint = self.footerView.heightAnchor.constraint(equalToConstant: 55)
        self.footerHeightConstraint.isActive = true

        self.footerView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: -constraintOffset).isActive = true
        self.footerView.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: constraintOffset).isActive = true
        self.footerView.bottomAnchor.constraint(equalTo: margins.bottomAnchor).isActive = true
    }

    func addTable(_ margins: UILayoutGuide) {
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tableView)
        self.tableView.topAnchor.constraint(equalTo: margins.topAnchor).isActive = true
        self.tableView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: -constraintOffset).isActive = true
        self.tableView.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: constraintOffset).isActive = true
        self.tableView.bottomAnchor.constraint(equalTo: self.footerView.topAnchor).isActive = true
    }

    func setupTable() {
        self.tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
        self.tableView.register(UINib(nibName: "AddCellView", bundle: nil), forCellReuseIdentifier: "AddCellView")

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.reorder.delegate = self
        self.tableView.reorder.cellScale = 1.05
        self.tableView.tableFooterView = UIView()

        // fixed tableview having strange offset
        self.edgesForExtendedLayout = UIRectEdge()
    }
}

extension BaseListViewController {
    // Percentage callback
    @objc func updatePercentage(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let percentCompletedString = userInfo["percentCompletedString"] as? String else {
                return
        }

        guard let index = (self.bookArray.index { (libraryObject) -> Bool in
            if let book = libraryObject as? Book {
                return book.fileURL == fileURL
            }

            return false
        }), let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BookCellView else {
            return
        }

        cell.completionLabel.text = percentCompletedString
    }

    @objc func bookReady() {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
    }

    @objc func bookPlayed() {
        //        self.footerPlayButton.setImage(self.miniPauseButton, for: UIControlState())
    }

    @objc func bookPaused() {
        //        self.footerPlayButton.setImage(self.miniPlayImage, for: UIControlState())
    }

    @objc func bookEnd(_ notification: Notification) {
        //        self.footerPlayButton.setImage(self.miniPlayImage, for: UIControlState())
    }

    func play(_ book: Book) {
        self.setupPlayer(book: book)
        self.setupFooter(book: book)
    }

    func setupFooter(book: Book) {
        //setup relevant information
    }

    func setupPlayer(book: Book) {
        // Make sure player is for a different book
        guard PlayerManager.sharedInstance.fileURL != book.fileURL else {
            self.showPlayerView(book: book)
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

        guard let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController else {
            return
        }

        playerVC.currentBook = book
        self.present(playerVC, animated: true)
    }
}

extension BaseListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 0 else {
            return 1
        }
        return self.bookArray.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let spacer = tableView.reorder.spacerCell(for: indexPath) {
            return spacer
        }

        guard indexPath.section == 0,
            let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as? BookCellView else {
                //load add cell
                return tableView.dequeueReusableCell(withIdentifier: "AddCellView", for: indexPath)
        }

        let book = self.bookArray[indexPath.row]

        cell.titleLabel.text = book.title
        cell.authorLabel.text = book.author

        // NOTE: we should have a default image for artwork
        cell.artworkImageView.image = book.artwork

        // Load stored percentage value
        cell.completionLabel.text = book.percentCompletedRoundedString
        cell.completionLabel.textColor = UIColor.flatGreenColorDark()

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
}

@objc extension BaseListViewController: TableViewReorderDelegate {
    func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard destinationIndexPath.section == 0 else {
            return
        }

        let book = self.bookArray[sourceIndexPath.row]
        self.bookArray.remove(at: sourceIndexPath.row)
        self.bookArray.insert(book, at: destinationIndexPath.row)
    }

    func tableView(_ tableView: UITableView, canReorderRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0
    }

    func tableView(_ tableView: UITableView, targetIndexPathForReorderFromRowAt sourceIndexPath: IndexPath, to proposedDestinationIndexPath: IndexPath, snapshot: UIView?) -> IndexPath {

        guard proposedDestinationIndexPath.section == 0 else {
            return sourceIndexPath
        }

        if let snapshot = snapshot {
            UIView.animate(withDuration: 0.2) {
                snapshot.transform = CGAffineTransform.identity
            }
        }

        return proposedDestinationIndexPath
    }

    func tableView(_ tableView: UITableView, sourceIndexPath: IndexPath, overIndexPath: IndexPath, snapshot: UIView) {
        guard overIndexPath.section == 0 else {
            return
        }

        UIView.animate(withDuration: 0.2) {
            snapshot.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    func tableViewDidFinishReordering(_ tableView: UITableView, from initialSourceIndexPath: IndexPath, to finalDestinationIndexPath: IndexPath, dropped overIndexPath: IndexPath?) {}
}

extension BaseListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.section == 0 else {
            return nil
        }

        let deleteAction = UITableViewRowAction(style: .default, title: "Delete") { (_, indexPath) in

            let cancelAction = UIAlertAction(title: "No", style: .cancel, handler: { _ in
                tableView.setEditing(false, animated: true)
            })
            let okAction = UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
                let book = (self.bookArray[indexPath.row] as? Book)!

                do {
                    try FileManager.default.removeItem(at: book.fileURL)

                    self.bookArray.remove(at: indexPath.row)
                    tableView.beginUpdates()
                    tableView.deleteRows(at: [indexPath], with: .none)
                    tableView.endUpdates()
                } catch {
                    self.showAlert("Error", message: "There was an error deleting the book, please try again.", style: .alert)
                }
            })

            self.showAlert("Confirmation", message: "Are you sure you would like to remove this audiobook?", actions: [cancelAction, okAction], style: .alert)
        }

        deleteAction.backgroundColor = UIColor.red

        return [deleteAction]
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        guard indexPath.section == 0 else {
            return .insert
        }
        return .delete
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let index = tableView.indexPathForSelectedRow else {
            return indexPath
        }

        tableView.deselectRow(at: index, animated: true)

        return indexPath
    }
}
