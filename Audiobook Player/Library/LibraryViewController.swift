//
//  LibraryViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/7/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import MBProgressHUD
import SwiftReorder

class LibraryViewController: BaseListViewController, UIGestureRecognizerDelegate {

    // Keep in memory images to toggle play/pause
    let miniPlayImage = UIImage(named: "miniPlayButton")
    let miniPauseButton = UIImage(named: "miniPauseButton")

    // keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!

    override func viewDidLoad() {
        super.viewDidLoad()

        // enables pop gesture on pushed controller
        self.navigationController!.interactivePopGestureRecognizer!.delegate = self

        // set footer
        self.footerView.backgroundColor = UIColor.flatSkyBlue()
        self.footerHeightConstraint.constant = 0

        // set tap handler to show detail on tap on footer view
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.didPressShowDetail(_:)))

        self.footerView.addGestureRecognizer(tapRecognizer)

        // register for appDelegate openUrl notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.loadFiles), name: Notification.Name.AudiobookPlayer.openURL, object: nil)

        // register notifications when the book is ready
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady), name: Notification.Name.AudiobookPlayer.bookReady, object: nil)

        self.loadFiles()
    }

    // No longer need to deregister observers for iOS 9+!
    // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11NotificationCenter
    deinit {
        //for iOS 8
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    /**
     *  Load local files and process them (rename them if necessary)
     *  Spaces in file names can cause side effects when trying to load the data
     */
    @objc func loadFiles() {
        //load local files
        let loadingWheel = MBProgressHUD.showAdded(to: self.view, animated: true)
        loadingWheel?.labelText = "Loading Books"

        DataManager.loadBooks { (books) in
            self.bookArray = books
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)

            //show/hide instructions view
            self.tableView.reloadData()
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return navigationController!.viewControllers.count > 1
    }

    @IBAction func didPressPlay(_ sender: UIButton) {
        PlayerManager.sharedInstance.play()
    }

    @objc func forwardPressed(_ sender: UIButton) {
        PlayerManager.sharedInstance.forward()
    }

    @objc func rewindPressed(_ sender: UIButton) {
        PlayerManager.sharedInstance.rewind()
    }

    @IBAction func didPressShowDetail(_ sender: UIButton) {
        self.showPlayerView(book: PlayerManager.sharedInstance.currentBook)
    }

    @IBAction func didPressEdit(_ sender: UIBarButtonItem) {
        self.tableView.setEditing(!self.tableView.isEditing, animated: true)
    }

    @objc func bookReady() {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
        PlayerManager.sharedInstance.playPause()
    }

    func play(_ book: Book) {
        setupPlayer(book: book)
        self.setupFooter(book: book)
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

        guard let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController else {
            return
        }

        playerVC.currentBook = book
        self.present(playerVC, animated: true)
    }
}

extension LibraryViewController {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section == 0 else {
            let importAction = UIAlertAction(title: "Import Files", style: .default) { (_) in
                let providerList = UIDocumentMenuViewController(documentTypes: ["public.audio"], in: .import)
                providerList.delegate = self

                providerList.popoverPresentationController?.sourceView = self.view
                providerList.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)
                self.present(providerList, animated: true, completion: nil)
            }

            let playlistAction = UIAlertAction(title: "Create Playlist", style: .default) { (_) in

                let playlistAlert = UIAlertController(title: "Create a New Playlist", message: "Files in playlists are automatically played one after the other", preferredStyle: .alert)
                playlistAlert.addTextField(configurationHandler: { (textfield) in
                    textfield.placeholder = "Name"
                })
                playlistAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                playlistAlert.addAction(UIAlertAction(title: "Create", style: .default, handler: { (_) in
                    let name = playlistAlert.textFields!.first!.text!
                    let playlist = Playlist(percentCompletedRoundedString: "0%", title: name, author: "derp", artwork: UIImage(), books: [])
                    self.bookArray.append(playlist)
                    self.tableView.reloadData()
                }))
                self.present(playlistAlert, animated: true, completion: nil)
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

            self.showAlert(nil, message: "You can also add files via AirDrop. Select BookPlayer from the list that appears when you send a file to your device", actions: [importAction, playlistAction, cancelAction], style: .actionSheet)

            return
        }

        let libraryObject = self.bookArray[indexPath.row]

        guard let book = libraryObject as? Book else {
            //handle playlists
            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            if let playlist = libraryObject as? Playlist,
                let playlistVC = storyboard.instantiateViewController(withIdentifier: "PlaylistViewController") as? PlaylistViewController {
                playlistVC.currentPlaylist = playlist

                self.navigationController?.pushViewController(playlistVC, animated: true)
            }

            return
        }

        play(book)
    }
}

extension LibraryViewController: UIDocumentMenuDelegate {
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        //show document picker
        documentPicker.delegate = self

        documentPicker.popoverPresentationController?.sourceView = self.view
        documentPicker.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)

        self.present(documentPicker, animated: true, completion: nil)
    }
}

extension LibraryViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        //Documentation states that the file might not be imported due to being accessed from somewhere else
        do {
            try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            self.showAlert("Error", message: "File import fail, try again later", style: .alert)
            return
        }

        let trueName = url.lastPathComponent
        var finalPath = self.documentsPath+"/"+(trueName)

        if trueName.contains(" ") {
            finalPath = finalPath.replacingOccurrences(of: " ", with: "_")
        }

        let fileURL = URL(fileURLWithPath: finalPath.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)

        do {
            try FileManager.default.moveItem(at: url, to: fileURL)
        } catch {
            self.showAlert("Error", message: "File import fail, try again later", style: .alert)
            return
        }

        self.loadFiles()
    }
}
