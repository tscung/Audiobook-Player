//
//  PlayerViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/5/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import Chameleon
import StoreKit

class PlayerViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var bottomToolbar: UIToolbar!
    @IBOutlet weak var speedButton: UIBarButtonItem!
    @IBOutlet weak var sleepButton: UIBarButtonItem!
    @IBOutlet weak var spaceBeforeChaptersButton: UIBarButtonItem!
    @IBOutlet weak var chaptersButton: UIBarButtonItem!

    private var pan: UIPanGestureRecognizer?

    private weak var controlsViewController: PlayerControlsViewController?
    private weak var metaViewController: PlayerMetaViewController?
    private weak var progressViewController: PlayerProgressViewController?

    var currentBook: Book!

    // MARK: Lifecycle

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? PlayerControlsViewController {
            self.controlsViewController = viewController
        }

        if let viewController = segue.destination as? PlayerMetaViewController {
            self.metaViewController = viewController
        }

        if let viewController = segue.destination as? PlayerProgressViewController {
            self.progressViewController = viewController
        }

        if segue.identifier == "ChapterSelectionSegue",
            let navigationController = segue.destination as? UINavigationController,
            let viewController = navigationController.viewControllers.first as? ChaptersViewController {
                viewController.book = self.currentBook
            }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupView(book: self.currentBook!)

        // Make toolbar transparent
        self.bottomToolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        self.bottomToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)

        // Observers
        NotificationCenter.default.addObserver(self, selector: #selector(self.requestReview), name: Notification.Name.AudiobookPlayer.requestReview, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.requestReview), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: Notification.Name.AudiobookPlayer.bookChange, object: nil)

        // Gesture
        self.pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.pan!.delegate = self
        self.pan!.maximumNumberOfTouches = 1
        self.pan!.cancelsTouchesInView = false

        self.view.addGestureRecognizer(pan!)
    }

    func setupView(book currentBook: Book) {
        self.metaViewController?.book = currentBook
        self.controlsViewController?.book = currentBook
        self.progressViewController?.book = currentBook
        self.progressViewController?.currentTime = UserDefaults.standard.double(forKey: currentBook.identifier)

        self.speedButton.title = "\(String(PlayerManager.sharedInstance.speed))x"

        // Colors
        guard var artworkColors = NSArray(ofColorsFrom: currentBook.artwork, withFlatScheme: false) as? [UIColor] else {
            return
        }

        artworkColors = artworkColors.sorted { (aColor, bColor) -> Bool in
            let aLightness = aColor.luminance
            let bLightness = bColor.luminance

            return aLightness > bLightness
        }

        view.backgroundColor = artworkColors.last?.withAlphaComponent(1.0) ?? view.backgroundColor

        self.setStatusBarStyle(.lightContent)

        self.closeButton.tintColor = artworkColors[1]
        self.metaViewController?.colors = artworkColors

        // @TODO: Add blurred version of the album artwork as background
    }

    // MARK: Interface actions

    @IBAction func dismissPlayer() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: Toolbar actions

    @IBAction func setSpeed() {
        let actionSheet = UIAlertController(title: nil, message: "Set playback speed", preferredStyle: .actionSheet)
        let speedOptions: [Float] = [2.5, 2.0, 1.5, 1.25, 1.0, 0.75]

        for speed in speedOptions {
            if speed == PlayerManager.sharedInstance.speed {
                actionSheet.addAction(UIAlertAction(title: "\u{00A0} \(speed) ✓", style: .default, handler: nil))
            } else {
                actionSheet.addAction(UIAlertAction(title: "\(speed)", style: .default, handler: { _ in
                    PlayerManager.sharedInstance.speed = speed

                    self.speedButton.title = "\(String(PlayerManager.sharedInstance.speed))x"
                }))
            }
        }

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(actionSheet, animated: true, completion: nil)
    }

    @IBAction func setSleepTimer() {
        let actionSheet = SleepTimer.shared.actionSheet(
            onStart: {},
            onProgress: { (_: Double) -> Void in
//                self.sleepButton.title = SleepTimer.shared.durationFormatter.string(from: timeLeft)
            },
            onEnd: { (_ cancelled: Bool) -> Void in
                if !cancelled {
                    PlayerManager.sharedInstance.stop()
                }

//                self.sleepButton.title = "Timer"
            }
        )

        self.present(actionSheet, animated: true, completion: nil)
    }

    @IBAction func showMore() {
        guard PlayerManager.sharedInstance.isLoaded else {
            return
        }

        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Jump To Start", style: .default, handler: { _ in
            PlayerManager.sharedInstance.stop()
            PlayerManager.sharedInstance.jumpTo(0.0)
        }))

        actionSheet.addAction(UIAlertAction(title: "Mark as Finished", style: .default, handler: { _ in
            PlayerManager.sharedInstance.stop()
            PlayerManager.sharedInstance.jumpTo(0.0, fromEnd: true)

            self.requestReview()
        }))

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(actionSheet, animated: true, completion: nil)
    }

    // MARK: Other Methods

    @objc func requestReview() {
        // don't do anything if flag isn't true
        guard UserDefaults.standard.bool(forKey: "ask_review") else {
            return
        }

        // request for review
        if #available(iOS 10.3, *), UIApplication.shared.applicationState == .active {
            #if RELEASE
                SKStoreReviewController.requestReview()
            #endif

            UserDefaults.standard.set(false, forKey: "ask_review")
        }
    }

    @objc func bookChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let books = userInfo["books"] as? [Book],
            let book = books.first else {
                return
        }

        self.currentBook = book

        self.setupView(book: book)
    }

    // MARK: Gesture recognizers
    // Based on https://github.com/HarshilShah/DeckTransition/blob/master/Source/DeckPresentationController.swift

    private func updatePresentedViewForTranslation(inVerticalDirection translation: CGFloat) {
        let elasticThreshold: CGFloat = 120.0
        let dismissThreshold: CGFloat = 240.0
        let translationFactor: CGFloat = 0.5

        if translation >= 0 {
            let translationForModal: CGFloat = {
                if translation >= elasticThreshold {
                    let frictionLength = translation - elasticThreshold
                    let frictionTranslation = 30 * atan(frictionLength/120) + frictionLength/10

                    return frictionTranslation + (elasticThreshold * translationFactor)
                } else {
                    return translation * translationFactor
                }
            }()

            self.view?.transform = CGAffineTransform(translationX: 0, y: translationForModal)

            if translation >= dismissThreshold {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    @objc private func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(pan) else {
            return
        }

        switch gestureRecognizer.state {
            case .began:
                gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self.view.superview)

            case .changed:
                let translation = gestureRecognizer.translation(in: self.view)

                self.updatePresentedViewForTranslation(inVerticalDirection: translation.y)

            case .ended:
                UIView.animate(
                    withDuration: 0.25,
                    animations: {
                        self.view?.transform = .identity
                    }
                )

            default: break
        }
    }
}