//
//  URLTrackerDatabase.swift
//  CalculatorFramework
//
//  Created by Naveen Vijay on 2024-04-07.
//

import Foundation
import SQLite3

@objc public class URLTrackerDatabase: NSObject {
    
    //@objc public static let shared = URLTrackerDatabase()
    private var database: OpaquePointer?
    
    override init() {
        super.init()
        openDatabase()
        createURLTable()
    }
    
    deinit {
        closeDatabase()
    }
    
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("URLTracker.sqlite")
        
        if sqlite3_open(fileURL.path, &database) != SQLITE_OK {
            print("Error opening database")
        }
    }
    
    private func closeDatabase() {
        if sqlite3_close(database) != SQLITE_OK {
            print("Error closing database")
        }
    }
    
    private func createURLTable() {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS URL (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            startingURL TEXT,
            finalURL TEXT,
            interval REAL,
            successful TEXT
        );
        """
        
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(database, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) != SQLITE_DONE {
                print("Error creating URL table")
            }
        } else {
            print("Error creating URL table statement")
        }
        
        sqlite3_finalize(createTableStatement)
    }
    
    @objc func insertURL(startingURL: String, finalURL: String, interval: TimeInterval, successful: Bool) {
        let insertStatementString = "INSERT INTO URL (startingURL, finalURL, interval, successful) VALUES (?, ?, ?, ?);"
        var insertStatement: OpaquePointer?
        var success = ""
        
        if successful {
            success = "Successful"
        }else{
            success = "Not Successful"
        }
        
        if sqlite3_prepare_v2(database, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (startingURL as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (finalURL as NSString).utf8String, -1, nil)
            sqlite3_bind_double(insertStatement, 3, interval)
            sqlite3_bind_text(insertStatement, 4, (success as NSString).utf8String, -1, nil)
            
            if sqlite3_step(insertStatement) != SQLITE_DONE {
                print("Error inserting URL")
            }
        } else {
            print("Error preparing insert statement")
        }
        
        sqlite3_finalize(insertStatement)
    }
    
    @objc public func retrieveTrackedURLs() -> [[String: Any]] {
        var trackedURLs: [[String: Any]] = []
        let queryStatementString = "SELECT startingURL, finalURL, interval, successful FROM URL;"
        var queryStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(database, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let startingURL = String(cString: sqlite3_column_text(queryStatement, 0))
                let finalURL = String(cString: sqlite3_column_text(queryStatement, 1))
                let interval = sqlite3_column_double(queryStatement, 2)
                let successful = String(cString: sqlite3_column_text(queryStatement, 3))
                let trackedURL: [String: Any] = [
                    "startingURL": startingURL,
                    "finalURL": finalURL,
                    "interval": interval,
                    "successful": successful
                ]
                
                trackedURLs.append(trackedURL)
            }
        } else {
            print("Error preparing query statement")
        }
        
        sqlite3_finalize(queryStatement)
        return trackedURLs
    }
}
