// DownloadsViewController.swift
//
// Copyright (c) 2015 Gurpartap Singh
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import Cheapjack


enum DownloadsTableViewCellAction: String {
    case Download = "Download"
    case Pause = "Pause"
    case Resume = "Resume"
    case Remove = "Remove"
}


class DownloadsTableViewCellItem {
    
    var identifier: String
    var urlString: String
    var infoLabelTitle: String
    var stateLabelTitle: String
    var progressLabelTitle: String
    var action: DownloadsTableViewCellAction
    var progress: Double
    
    weak var cell: DownloadsTableViewCell?
    
    init(identifier: String, urlString: String, infoLabelTitle: String, stateLabelTitle: String, progressLabelTitle: String, action: DownloadsTableViewCellAction) {
        self.identifier = identifier
        self.urlString = urlString
        self.infoLabelTitle = infoLabelTitle
        self.stateLabelTitle = stateLabelTitle
        self.progressLabelTitle = progressLabelTitle
        self.action = action
        self.progress = 0
    }
    
    func url() -> URL {
        return URL(string: urlString)!
    }
    
}


class DownloadsViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    var identifiers = Array<CheapjackFile.Identifier>()
    var downloadItems = Dictionary<CheapjackFile.Identifier, DownloadsTableViewCellItem>()
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CheapjackManager.sharedManager.delegate = self
        pause.title = "pasue"
    }
    @IBAction func addDownloadItem(sender: UIBarButtonItem) {
        let identifier = NSUUID().uuidString
        let urlString = "https://web.whatsapp.com/desktop/mac/files/WhatsApp.dmg"
        let downloadItem = DownloadsTableViewCellItem(identifier: identifier, urlString: urlString, infoLabelTitle: "mp3 test file from archive.org", stateLabelTitle: identifier, progressLabelTitle: "", action: DownloadsTableViewCellAction.Download)
        addDownloadItem(downloadItem: downloadItem, withIdentifier: identifier)
    }
    @IBOutlet weak var pause: UIBarButtonItem!
    
    var current = "pasue all"
    @IBAction func pasueDownlaod(_ sender: UIBarButtonItem) {
        if current == "pasue all"{
           //pasue all
            CheapjackManager.sharedManager.pauseAll()

            current = "resume all"
            pause.title = "resume all"

        }else{
            //resume all
            
            CheapjackManager.sharedManager.resumeAll()
            current = "pasue all"
            pause.title = "pasue all"

        }
    }
    func addDownloadItem(downloadItem: DownloadsTableViewCellItem, withIdentifier identifier: CheapjackFile.Identifier) {
        downloadItems[identifier] = downloadItem
        identifiers.append(identifier)
        
        
        let indexPathToInsert = IndexPath(row: downloadItems.count-1, section: 0)
        tableView.insertRows(at: [indexPathToInsert as IndexPath], with: UITableViewRowAnimation.automatic)
    }
    
    func removeDownloadItemWithIdentifier(identifier: CheapjackFile.Identifier) {
        if let index = self.identifiers.index(of: identifier) {
            downloadItems.removeValue(forKey: identifier)
            identifiers.remove(at: index)
            
            let indexPathToDelete = IndexPath(row: index, section: 0)
            tableView.deleteRows(at: [indexPathToDelete as IndexPath], with: UITableViewRowAnimation.automatic)
        }
    }
    
}


extension DownloadsViewController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return identifiers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadsTableViewCellIdentifier") as! DownloadsTableViewCell
        
        cell.delegate = self
        cell.downloadItem = downloadItems[identifiers[indexPath.row]]
        
        return cell
    }
    
}


extension DownloadsViewController: DownloadsTableViewCellDelegate {
    
    func actionButtonPressed(sender: UIButton, inCell cell: DownloadsTableViewCell) {
        
        

        switch (sender.titleLabel?.text)! {
        case "Download":
            CheapjackManager.sharedManager.download(cell.downloadItem.url(), identifier: cell.downloadItem.identifier)
            
        case "Pause":
            if CheapjackManager.sharedManager.pause(cell.downloadItem.identifier) {
                print("pausing")
            } else {
                print("couldn't pause")
            }
        case "Resume":
            if CheapjackManager.sharedManager.resume(cell.downloadItem.identifier) {
                print("resuming")
            } else {
                print("couldn't resume")
            }
        case "Remove":
            if CheapjackManager.sharedManager.cancel(cell.downloadItem.identifier) {
                print("cancelled")
            } else {
                print("couldn't cancel")
            }
            removeDownloadItemWithIdentifier(identifier: cell.downloadItem.identifier)
        default:
            break
        }
    }
    
}


extension DownloadsViewController: CheapjackDelegate {

    
    
    func cheapjackManager(_ manager: CheapjackManager, didChangeState from: State, to: State, forFile file: CheapjackFile) {
        DispatchQueue.main.async() {
            if let index = self.identifiers.index(of: file.identifier) {
                let indexPath = IndexPath(row: index, section: 0)
                if let cell = self.tableView.cellForRow(at: indexPath as IndexPath) as? DownloadsTableViewCell {
                    switch to {
                    case .waiting:
                        self.downloadItems[file.identifier]?.stateLabelTitle = "Waiting..."
                        self.downloadItems[file.identifier]?.action = DownloadsTableViewCellAction.Pause
                        break
                    case .downloading:
                        self.downloadItems[file.identifier]?.stateLabelTitle = "Downloading..."
                        self.downloadItems[file.identifier]?.action = DownloadsTableViewCellAction.Pause
                        break
                    case .paused:
                        self.downloadItems[file.identifier]?.stateLabelTitle = "Paused"
                        self.downloadItems[file.identifier]?.action = DownloadsTableViewCellAction.Resume
                        break
                    case .finished:
                        self.downloadItems[file.identifier]?.stateLabelTitle = "Finished"
                        self.downloadItems[file.identifier]?.action = DownloadsTableViewCellAction.Remove
                        break
                    case .cancelled:
                        self.downloadItems[file.identifier]?.stateLabelTitle = "Cancelled"
                        self.downloadItems[file.identifier]?.action = DownloadsTableViewCellAction.Download
                        break
                    case .unknown:
                        self.downloadItems[file.identifier]?.stateLabelTitle = "Unknown"
                        self.downloadItems[file.identifier]?.action = DownloadsTableViewCellAction.Download
                        break
                    default:
                        break
                    }
                    cell.downloadItem = self.downloadItems[file.identifier]
                }
            }
        }
    }
    
    func cheapjackManager(_ manager: CheapjackManager, didUpdateProgress progress: Double, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64, forFile file: CheapjackFile) {
        DispatchQueue.main.async() {
            if let index = self.identifiers.index(of: file.identifier) {
                let indexPath = IndexPath(row: index, section: 0)
                if let cell = self.tableView.cellForRow(at: indexPath as IndexPath) as? DownloadsTableViewCell {
                    let formattedWrittenBytes = ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file)
                    let formattedTotalBytes = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
                    self.downloadItems[file.identifier]?.progressLabelTitle = "\(Int(progress * 100))% - \(formattedWrittenBytes) of \(formattedTotalBytes)"
                    self.downloadItems[file.identifier]?.progress = progress
                    cell.downloadItem = self.downloadItems[file.identifier]
                }
            }
        }
    }
    
    func cheapjackManager(_ manager: CheapjackManager, didReceiveError error: NSError?) {
        DispatchQueue.main.async() {
            
        }
    }
    
    func cheapjackManager(_ manager: CheapjackManager, didFinishDownloading withSession: URLSession, downloadTask: URLSessionDownloadTask, url: URL, forFile file: CheapjackFile) {
        
        print(file.url)
        
    }
    
}


extension DownloadsViewController: CheapjackFileDelegate {
    
    func cheapjackFile(_ file: CheapjackFile, didChangeState from: State, to: State) {
        DispatchQueue.main.async() {
            
        }
    }
    
    func cheapjackFile(_ file: CheapjackFile, didUpdateProgress progress: Double, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async() {
            
        }
    }
    
}

