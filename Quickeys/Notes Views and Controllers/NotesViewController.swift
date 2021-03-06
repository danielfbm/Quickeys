//
//  NotesViewController.swift
//  Quickies
//
//  Created by Alex Rosenfeld on 12/8/16.
//  Copyright © 2016 Alex Rosenfeld. All rights reserved.
//

import Cocoa

// Notes View Controller class

class NotesViewController: NSViewController, NotesTextViewControllerDelegate {
    
    // Lets and vars
    
    let pastebinAPI = PastebinAPI()
    
    let defaults = UserDefaults.standard
    var preferencesActive = false
    
    let FIXED_WIDTH = CGFloat(372)
    let MIN_HEIGHT = CGFloat(169)
    let MAX_HEIGHT = CGFloat(500)
    
    // Outlets
    
    @IBOutlet var inputText: NotesTextViewController!
    @IBOutlet weak var preferencesView: NSView!
    @IBOutlet weak var notesContainer: NSScrollView!
    
    @IBOutlet weak var searchButton: NSButton!
    @IBOutlet weak var searchTarget: NSPopUpButton!
    @IBOutlet weak var searchWithMenuButton: NSPopUpButton!
    @IBOutlet weak var searchWithMenu: NSMenu!
    
    @IBOutlet weak var pastebinButton: NSButton!
    @IBOutlet weak var pastebinProgressIndicator: NSProgressIndicator!
    
    // Overrides
    
    override func awakeFromNib() {
        inputText.notesTextViewControllerDelegate = self
        populateMenuItems()
        self.notesContainer.horizontalScrollElasticity = .none
        self.notesContainer.hasHorizontalScroller = false
    }
    
    override func viewDidLoad() {
        // Receive previous sessions data
        if let savedUserInputTextData = defaults.string(forKey: "userInputTextData")
        {
            inputText.insertText(savedUserInputTextData, replacementRange: inputText.rangeForUserTextChange)
        }
    }
    
    override func viewDidDisappear() {
        // Save the user input data. This occurs on leaving the view or on closing the app.
        defaults.set(getAllTextFromView(), forKey: "userInputTextData")
        if let savedUserInputTextData = defaults.string(forKey: "userInputTextData")
        {
            NSLog("Saved " + savedUserInputTextData)
        }
    }
    
    override func mouseDragged(with theEvent: NSEvent) {
        let currentLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame
        
        var newY = screenFrame!.size.height - currentLocation.y
        
        if newY < MIN_HEIGHT {
            newY = MIN_HEIGHT
        }
        
        if newY > MAX_HEIGHT {
            newY = MAX_HEIGHT
        }
        
        let appDelegate : AppDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.popover.contentSize = NSSize(width: FIXED_WIDTH, height: newY)
    }
    
    // Delegate functions
    
    func NotesTextViewiewControllerCommandEnterPressed() {
        searchClicked(self)
    }
    
    func NotesTextViewiewControllerAltOptionEnterPressed() {
        pastebinClicked(self)
    }
    
    // Functions
    
    func getAllTextFromView() -> String {
        return inputText.attributedString().string
    }
    
    func getHighlightedOrAllTextFromView() -> String {
        if let selectedText = inputText.attributedSubstring(forProposedRange: inputText.selectedRange(), actualRange: nil)?.string {
            return selectedText
        } else {
            return getAllTextFromView()
        }
    }
    
    func urlEscapeText(txt: String) -> String {
        let unreserved = "-._~/?"
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: unreserved)
        return txt.addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet)!
    }
    
    func searchTextOnWebsite(website: String) {
        // Set our destination url
        let url_text = urlEscapeText(txt: getHighlightedOrAllTextFromView())
        
        if let url = URL(string: website + url_text), NSWorkspace.shared.open(url) {
            NSLog("browser opened successfully")
        } else {
            NSLog("browser failed to open")
        }
    }
    
    func populateMenuItems() {
        let lastSelectedItem = searchWithMenuButton.selectedItem
        
        searchWithMenu.removeAllItems()
        if let menuItems = Utility.arrayFromSource(from: "Urls") {
            for case let menuItem as NSDictionary in menuItems {
                if (menuItem.value(forKey: "isEnabled") as! Bool) {
                    let newItem = NSMenuItem(title: menuItem.allKeys[0] as! String, action: nil, keyEquivalent: "")
                    newItem.representedObject = menuItem.allValues[0] as! String
                    
                    searchWithMenu.addItem(newItem)
                }
            }
        }
        
        if let title = lastSelectedItem?.title, searchWithMenuButton.itemTitles.contains(title) {
            searchWithMenuButton.selectItem(withTitle: title)
        }
        else {
            searchWithMenuButton.selectItem(at: 0)
        }
    }
    
    func togglePreferencesView() {
        self.preferencesActive = !self.preferencesActive
        
        if (pastebinButton.title == "Pastebin") {
            pastebinButton.isEnabled = !pastebinButton.isEnabled
        }
        
        preferencesView.isHidden = !preferencesView.isHidden
        notesContainer.isHidden = !notesContainer.isHidden
        searchWithMenuButton.isEnabled = !searchWithMenuButton.isEnabled
        searchButton.isEnabled = !searchButton.isEnabled
    }
    
    func applyPreferences() {
        // Apply selections to plist file
        if let (menuItems, filePath) = Utility.arrayAndPathFromSource(from: "Urls") {
            for case let menuItem as NSDictionary in menuItems! {
                // Loop through check boxes in preference list
                /* if (menuItem.allKeys[0] as! String == checkboxes.title) {
                 menuItem.setValue(checkbox.state == NSOnState, forKey: "isEnabled")
                 }
                 */
            }
            menuItems?.write(toFile: filePath!, atomically: true)
        }
        
        populateMenuItems()
    }
}

// Actions extension

extension NotesViewController {
    // Actions
    
    @IBAction func quit(_ sender: NSButton) {
        NSApplication.shared.terminate(sender)
    }
    
    @IBAction func searchClicked(_ sender: AnyObject) {
        if let target = searchTarget.selectedItem {
            searchTextOnWebsite(website: (target.representedObject as! String))
        } else {
            NSLog("No search targets in searchTarget menu")
        }
    }
    
    @IBAction func pastebinClicked(_ sender: AnyObject) {
        if Reachability.isInternetAvailable() {
            let text = getHighlightedOrAllTextFromView()
            if !text.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines).isEmpty {
                
                self.pastebinButton.isEnabled = false
                self.pastebinButton.title = ""
                self.pastebinProgressIndicator.startAnimation(nil)
                
                pastebinAPI.postPasteRequest(urlEscapedContent: urlEscapeText(txt: text)) { pasteResponse in
                    
                    DispatchQueue.main.async {
                        self.pastebinProgressIndicator.stopAnimation(nil)
                        if pasteResponse.isEmpty {
                            self.pastebinButton.title = "Error"
                        } else {
                            self.pastebinButton.title = "Copied!"
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: {
                        self.pastebinButton.title = "Pastebin"
                        if (!self.preferencesActive) {
                            self.pastebinButton.isEnabled = true
                        }
                    })
                }
            } else {
                Utility.playFunkSound()
            }
        } else {
            NSLog("No internet connection")
            Utility.playFunkSound()
        }
    }
    
    @IBAction func preferencesClicked(_ sender: Any) {
        if (self.preferencesActive) {
            applyPreferences()
        }
        togglePreferencesView()
    }
}
