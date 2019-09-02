//
//  ViewControllerCopyFiles.swift
//  RcloneOSX
//
//  Created by Thomas Evensen on 12/09/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable line_length

import Foundation
import Cocoa

protocol Updateremotefilelist: class {
    func updateremotefilelist()
}

class ViewControllerCopyFiles: NSViewController, SetConfigurations, Delay, VcMain {

    var copysinglefiles: CopyFiles?
    var remotefilelist: Remotefilelist?
    var rcloneindex: Int?
    var estimated: Bool = false
    private var restoretabledata: [String]?
    var diddissappear: Bool = false

    @IBOutlet weak var numberofrows: NSTextField!
    @IBOutlet weak var server: NSTextField!
    @IBOutlet weak var rcatalog: NSTextField!
    @IBOutlet weak var info: NSTextField!

    @IBOutlet weak var restoretableView: NSTableView!
    @IBOutlet weak var rclonetableView: NSTableView!
    @IBOutlet weak var commandString: NSTextField!
    @IBOutlet weak var remoteCatalog: NSTextField!
    @IBOutlet weak var restorecatalog: NSTextField!
    @IBOutlet weak var working: NSProgressIndicator!
    @IBOutlet weak var search: NSSearchField!
    @IBOutlet weak var restorebutton: NSButton!

    @IBAction func totinfo(_ sender: NSButton) {
        guard ViewControllerReference.shared.norclone == false else {
            _ = Norclone()
            return
        }
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerRemoteInfo!)
        })
    }

    @IBAction func quickbackup(_ sender: NSButton) {
        guard ViewControllerReference.shared.norclone == false else {
            _ = Norclone()
            return
        }
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerQuickBackup!)
        })
    }

    @IBAction func information(_ sender: NSToolbarItem) {
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerInformation!)
        })
    }

    // Userconfig
    @IBAction func userconfiguration(_ sender: NSToolbarItem) {
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerUserconfiguration!)
        })
    }

    // Selecting profiles
    @IBAction func profiles(_ sender: NSButton) {
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerProfile!)
        })
    }

    // Selecting About
    @IBAction func about (_ sender: NSButton) {
        self.presentAsModalWindow(self.viewControllerAbout!)
    }

    // Selecting automatic backup
    @IBAction func automaticbackup (_ sender: NSButton) {
        self.presentAsSheet(self.viewControllerEstimating!)
    }

    // Abort button
    @IBAction func abort(_ sender: NSButton) {
        self.working.stopAnimation(nil)
        guard self.copysinglefiles != nil else { return }
        self.restorebutton.isEnabled = true
        self.copysinglefiles!.abort()
    }

    private func info(num: Int) {
        switch num {
        case 1:
            self.info.stringValue = "No such local catalog for restore or set it in user config..."
        case 2:
            self.info.stringValue = "Not a remote task, use Finder to copy files..."
        case 3:
            self.info.stringValue = "Local or remote catalog cannot be empty..."
        default:
            self.info.stringValue = ""
        }
    }

    // Do the work
    @IBAction func restore(_ sender: NSButton) {
        guard self.remoteCatalog.stringValue.isEmpty == false && self.restorecatalog.stringValue.isEmpty == false else {
            self.info(num: 3)
            return
        }
        guard self.copysinglefiles != nil else { return }
        self.restorebutton.isEnabled = false
        self.working.startAnimation(nil)
        if self.estimated == false {
            self.copysinglefiles!.executecopyfiles(remotefile: remoteCatalog!.stringValue, localCatalog: restorecatalog!.stringValue, dryrun: true, updateprogress: self)
            self.estimated = true
        } else {
            self.copysinglefiles!.executecopyfiles(remotefile: remoteCatalog!.stringValue, localCatalog: restorecatalog!.stringValue, dryrun: false, updateprogress: self)
            self.estimated = false
        }
    }

    private func displayRemoteserver(index: Int?) {
        guard index != nil else {
            self.server.stringValue = ""
            self.rcatalog.stringValue = ""
            return
        }
        let hiddenID = self.configurations!.gethiddenID(index: index!)
        globalMainQueue.async(execute: { () -> Void in
            self.server.stringValue = self.configurations!.getResourceConfiguration(hiddenID, resource: .offsiteServer)
            self.rcatalog.stringValue = self.configurations!.getResourceConfiguration(hiddenID, resource: .remoteCatalog)
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ViewControllerReference.shared.setvcref(viewcontroller: .vccopyfiles, nsviewcontroller: self)
        self.restoretableView.delegate = self
        self.restoretableView.dataSource = self
        self.rclonetableView.delegate = self
        self.rclonetableView.dataSource = self
        self.working.usesThreadedAnimation = true
        self.search.delegate = self
        self.restorecatalog.delegate = self
        self.remoteCatalog.delegate = self
        self.restoretableView.doubleAction = #selector(self.tableViewDoubleClick(sender:))
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard self.diddissappear == false else {
            globalMainQueue.async(execute: { () -> Void in
                self.rclonetableView.reloadData()
            })
            return
        }
        if let restorePath = ViewControllerReference.shared.restorePath {
            self.restorecatalog.stringValue = restorePath
        } else {
            self.restorecatalog.stringValue = ""
        }
        self.verifylocalCatalog()
        globalMainQueue.async(execute: { () -> Void in
            self.rclonetableView.reloadData()
        })
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.diddissappear = true
    }

    @objc(tableViewDoubleClick:) func tableViewDoubleClick(sender: AnyObject) {
        guard self.remoteCatalog.stringValue.isEmpty == false else { return }
        guard self.restorecatalog.stringValue.isEmpty == false else { return }
        let answer = Alerts.dialogOKCancel("Copy single files or directory", text: "Start restore?")
        if answer {
            self.restorebutton.isEnabled = false
            self.working.startAnimation(nil)
            self.copysinglefiles!.executecopyfiles(remotefile: self.remoteCatalog!.stringValue, localCatalog: self.restorecatalog!.stringValue, dryrun: false, updateprogress: self)
        }
    }

    private func verifylocalCatalog() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: self.restorecatalog.stringValue) == false {
            self.info(num: 1)
        } else {
            self.info(num: 0)
        }
    }

    private func inprogress() -> Bool {
        guard self.copysinglefiles != nil else { return false }
        if self.copysinglefiles?.process != nil {
            return true
        } else {
            return false
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let myTableViewFromNotification = (notification.object as? NSTableView)!
        if myTableViewFromNotification == self.restoretableView {
            self.info(num: 0)
            let indexes = myTableViewFromNotification.selectedRowIndexes
            if let index = indexes.first {
                guard self.restoretabledata != nil else { return }
                self.remoteCatalog.stringValue = self.restoretabledata![index]
                guard self.remoteCatalog.stringValue.isEmpty == false && self.restorecatalog.stringValue.isEmpty == false else { return }
                self.commandString.stringValue = self.copysinglefiles!.getCommandDisplayinView(remotefile: self.remoteCatalog.stringValue, localCatalog: self.restorecatalog.stringValue)
                self.estimated = false
                self.restorebutton.title = "Estimate"
                self.restorebutton.isEnabled = true
            }
        } else {
            let indexes = myTableViewFromNotification.selectedRowIndexes
            if let index = indexes.first {
                guard self.inprogress() == false else {
                    self.working.stopAnimation(nil)
                    guard self.copysinglefiles != nil else { return }
                    self.restorebutton.isEnabled = true
                    self.copysinglefiles!.abort()
                    return
                }
                self.restorebutton.title = "Estimate"
                self.restorebutton.isEnabled = false
                self.remoteCatalog.stringValue = ""
                self.rcloneindex = index
                let hiddenID = self.configurations!.getConfigurationsSyncandCopy()![index].value(forKey: "hiddenID") as? Int ?? -1
                self.copysinglefiles = CopyFiles(hiddenID: hiddenID)
                self.remotefilelist = Remotefilelist(hiddenID: hiddenID)
                self.working.startAnimation(nil)
                self.displayRemoteserver(index: index)
            } else {
                self.rcloneindex = nil
                self.restoretabledata = nil
                globalMainQueue.async(execute: { () -> Void in
                    self.restoretableView.reloadData()
                })
            }
        }
    }
}

extension ViewControllerCopyFiles: NSSearchFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        if (notification.object as? NSTextField)! == self.search {
            self.delayWithSeconds(0.25) {
                if self.search.stringValue.isEmpty {
                    globalMainQueue.async(execute: { () -> Void in
                        if let index = self.rcloneindex {
                            if let hiddenID = self.configurations!.getConfigurationsSyncandCopy()![index].value(forKey: "hiddenID") as? Int {
                                self.remotefilelist = Remotefilelist(hiddenID: hiddenID)
                            }
                        }
                    })
                } else {
                    globalMainQueue.async(execute: { () -> Void in
                        self.restoretabledata = self.restoretabledata!.filter({$0.contains(self.search.stringValue)})
                        self.restoretableView.reloadData()
                    })
                }
            }
            self.verifylocalCatalog()
        } else {
            self.delayWithSeconds(0.25) {
                self.verifylocalCatalog()
                self.restorebutton.title = "Estimate"
                self.restorebutton.isEnabled = true
                self.estimated = false
                guard self.remoteCatalog.stringValue.count > 0 else { return }
                self.commandString.stringValue = self.copysinglefiles?.getCommandDisplayinView(remotefile: self.remoteCatalog.stringValue, localCatalog: self.restorecatalog.stringValue) ?? ""
            }
        }
    }

    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        if let index = self.rcloneindex {
            if self.configurations!.getConfigurationsSyncandCopy()![index].value(forKey: "hiddenID") as? Int != nil {
                self.working.startAnimation(nil)
            }
        }
    }
}

extension ViewControllerCopyFiles: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.restoretableView {
            guard self.restoretabledata != nil else {
                self.numberofrows.stringValue = "Number of remote files: 0"
                return 0
            }
            self.numberofrows.stringValue = "Number of remote files: " + String(self.restoretabledata!.count)
            return self.restoretabledata!.count
        } else {
            return self.configurations?.getConfigurationsSyncandCopy()?.count ?? 0
        }
    }
}

extension ViewControllerCopyFiles: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == self.restoretableView {
            guard self.restoretabledata != nil else { return nil }
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "files"), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = self.restoretabledata?[row] ?? ""
                return cell
            }
        } else {
            guard row < self.configurations!.getConfigurationsSyncandCopy()!.count else { return nil }
            let object: NSDictionary = self.configurations!.getConfigurationsSyncandCopy()![row]
            let cellIdentifier: String = tableColumn!.identifier.rawValue
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: self) as? NSTableCellView {
                cell.textField?.stringValue = object.value(forKey: cellIdentifier) as? String ?? ""
                return cell
            }
        }
        return nil
    }
}

extension ViewControllerCopyFiles: UpdateProgress {
    func processTermination() {
        self.restorebutton.title = "Restore"
        self.working.stopAnimation(nil)
        self.presentAsSheet(self.viewControllerInformation!)
        self.restorebutton.isEnabled = true
        self.copysinglefiles?.process = nil
    }

    func fileHandler() {
        // nothing
    }
}

extension ViewControllerCopyFiles: DismissViewController {
    func dismiss_view(viewcontroller: NSViewController) {
        self.dismiss(viewcontroller)
    }
}

extension ViewControllerCopyFiles: TemporaryRestorePath {
    func temporaryrestorepath() {
        if let restorePath = ViewControllerReference.shared.restorePath {
            self.restorecatalog.stringValue = restorePath
        } else {
            self.restorecatalog.stringValue = ""
        }
        self.verifylocalCatalog()
    }
}

extension ViewControllerCopyFiles: NewProfile {
    func newProfile(profile: String?) {
        self.restoretabledata  = nil
        globalMainQueue.async(execute: { () -> Void in
            self.restoretableView.reloadData()
        })
    }

    func enableProfileMenu() {
        //
    }
}

extension ViewControllerCopyFiles: OpenQuickBackup {
    func openquickbackup() {
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerQuickBackup!)
        })
    }
}

extension ViewControllerCopyFiles: Updateremotefilelist {
    func updateremotefilelist() {
        self.restoretabledata = self.remotefilelist?.remotefilelist
        globalMainQueue.async(execute: { () -> Void in
            self.restoretableView.reloadData()
        })
        self.working.stopAnimation(nil)
        self.remotefilelist = nil
    }
}