//
//  URLTrackerDatabase.swift
//  CalculatorFramework
//
//  Created by Naveen Vijay on 2024-04-07.
//

import Foundation
import SQLite3
import OSLog

// This class manages the SQLite database for storing tracked URLs and their details.
@objc public class URLTrackerDatabase: NSObject {
    
    private var database: OpaquePointer?
    
    override init() {
        super.init()
        openDatabase()
        createURLTable()
    }
    
    deinit {
        closeDatabase()
    }
    
    // Open the SQLite database
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("URLTracker.sqlite")
        
        if sqlite3_open(fileURL.path, &database) != SQLITE_OK {
            os_log("Error opening database", type: .error)
        }
    }
    
    // Close the SQLite database
    private func closeDatabase() {
        if sqlite3_close(database) != SQLITE_OK {
            os_log("Error closing database", type: .error)
        }
    }
    
    // Create the URL table in the database if it does not exist
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
        // Prepare and execute the SQLite query to create the table
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(database, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) != SQLITE_DONE {
                os_log("Error creating URL table", type: .error)
            }
        } else {
            os_log("Error creating URL table statement", type: .error)
        }
        
        sqlite3_finalize(createTableStatement)
    }
    
    // Insert a tracked URL details into the database
    @objc func insertURL(startingURL: String, finalURL: String, interval: TimeInterval, successful: Bool) {
        let insertStatementString = "INSERT INTO URL (startingURL, finalURL, interval, successful) VALUES (?, ?, ?, ?);"
        var insertStatement: OpaquePointer?
        var success = ""
        
        if successful {
            success = "Successful"
        }else{
            success = "Not Successful"
        }
        
        // Prepare and execute the SQLite query to insert the URL details
        if sqlite3_prepare_v2(database, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (startingURL as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (finalURL as NSString).utf8String, -1, nil)
            sqlite3_bind_double(insertStatement, 3, (interval * 1000))
            sqlite3_bind_text(insertStatement, 4, (success as NSString).utf8String, -1, nil)
            
            if sqlite3_step(insertStatement) != SQLITE_DONE {
                os_log("Error inserting URL", type: .error)
            }
        } else {
            os_log("Error preparing insert statement", type: .error)
        }
        
        sqlite3_finalize(insertStatement)
    }
    
    // Retrieve tracked URLs from the database
    @objc public func retrieveTrackedURLs() -> [[String: Any]] {
        var trackedURLs: [[String: Any]] = []
        
        // SQL query to retrieve tracked URLs from the table
        let queryStatementString = "SELECT startingURL, finalURL, interval, successful FROM URL;"
        var queryStatement: OpaquePointer?
        
        // SQLite query to retrieve tracked URLs from the table
        if sqlite3_prepare_v2(database, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                // Retrieve values from the query result
                let startingURL = String(cString: sqlite3_column_text(queryStatement, 0))
                let finalURL = String(cString: sqlite3_column_text(queryStatement, 1))
                let interval = sqlite3_column_double(queryStatement, 2)
                let successful = String(cString: sqlite3_column_text(queryStatement, 3))
                
                // Create a dictionary representing a tracked URL
                let trackedURL: [String: Any] = [
                    "startingURL": startingURL,
                    "finalURL": finalURL,
                    "interval": interval,
                    "successful": successful
                ]
                
                // Append the tracked URL dictionary to the array
                trackedURLs.append(trackedURL)
            }
        } else {
            os_log("Error preparing query statement", type: .error)
        }
        
        // Finalize the SQL statement
        sqlite3_finalize(queryStatement)
        
        // Return the array of tracked URLs
        return trackedURLs
    }
}
