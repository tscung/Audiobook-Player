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

        let settingsButton = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(self.showSettings))
        self.navigationItem.leftBarButtonItem = settingsButton

        // set tap handler to show detail on tap on footer view
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.didPressShowDetail(_:)))

        self.footerView.addGestureRecognizer(tapRecognizer)

        // register for appDelegate openUrl notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.loadFiles), name: Notification.Name.AudiobookPlayer.openURL, object: nil)

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

    @IBAction func didPressShowDetail(_ sender: UIButton) {
        self.showPlayerView(book: PlayerManager.sharedInstance.currentBook)
    }

    @IBAction func didPressEdit(_ sender: UIBarButtonItem) {
        self.tableView.setEditing(!self.tableView.isEditing, animated: true)
    }

    @objc func showSettings() {
        self.performSegue(withIdentifier: "showSettingsSegue", sender: nil)
    }

    override func bookReady() {
        super.bookReady()
        PlayerManager.sharedInstance.playPause()
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
                playlistVC.bookArray = playlist.books

                self.navigationController?.pushViewController(playlistVC, animated: true)
            }

            return
        }

        self.play(book)
    }

    override func tableViewDidFinishReordering(_ tableView: UITableView, from initialSourceIndexPath: IndexPath, to finalDestinationIndexPath: IndexPath, dropped overIndexPath: IndexPath?) {

        guard let overIndexPath = overIndexPath,
            overIndexPath.section == 0,
            let book = self.bookArray[finalDestinationIndexPath.row] as? Book else {
                return
        }

        let libraryObject = self.bookArray[overIndexPath.row]
        let isPlaylist = libraryObject is Playlist
        let title = isPlaylist
            ? "Playlist"
            : "Create a New Playlist"
        let message = isPlaylist
            ? "Add the book to \(libraryObject.title)"
            : "Files in playlists are automatically played one after the other"

        let hoverAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        hoverAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        if isPlaylist {
            hoverAlert.addAction(UIAlertAction(title: "Add", style: .default, handler: { (_) in

                if var playlist = libraryObject as? Playlist {
                    playlist.books.append(book)
                    self.bookArray[overIndexPath.row] = playlist
                }
                self.bookArray.remove(at: finalDestinationIndexPath.row)
                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [finalDestinationIndexPath], with: .fade)
                self.tableView.endUpdates()
            }))
        } else {
            hoverAlert.addTextField(configurationHandler: { (textfield) in
                textfield.placeholder = "Name"
            })

            hoverAlert.addAction(UIAlertAction(title: "Create", style: .default, handler: { (_) in
                let name = hoverAlert.textFields!.first!.text!

                let minIndex = min(finalDestinationIndexPath.row, overIndexPath.row)
                //removing based on minIndex works because the cells are always adjacent
                let book1 = self.bookArray.remove(at: minIndex)
                let book2 = self.bookArray.remove(at: minIndex)

                let playlist = Playlist(percentCompletedRoundedString: "0%", title: name, author: "derp", artwork: UIImage(), books: [book1, book2])

                self.bookArray.insert(playlist, at: minIndex)
                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [IndexPath(row: minIndex, section: 0), IndexPath(row: minIndex + 1, section: 0)], with: .fade)
                self.tableView.insertRows(at: [IndexPath(row: minIndex, section: 0)], with: .fade)
                self.tableView.endUpdates()
            }))
        }

        self.present(hoverAlert, animated: true, completion: nil)
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
