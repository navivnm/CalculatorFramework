//
//  URLTracker.swift
//  CalculatorFramework
//
//  Created by Naveen Vijay on 2024-04-05.
//

import Foundation
import OSLog

// This class tracks URLs and their time intervals, with the ability to notify about new URLs and store them in a database.
@objc public class URLTracker: NSObject {
    
    @objc public static let shared = URLTracker()
    @objc public static let database = URLTrackerDatabase()
    private var trackedURLs: [URL] = []
    fileprivate var invalidURLs: [URL] = []
    
    // Closure property to notify about new URL, final URL, and its time interval
    @objc public var newURLCallback: ((URL, URL, TimeInterval) -> Void)?
   
    private override init() {
        super.init()
        
        swizzleNSURLSessionMethods()
        swizzleNSURLSessionTaskMethods()
    }
    
    // Method to swizzle URLSession methods for tracking
    private func swizzleNSURLSessionMethods() {
        let _ = URLSession.shared
        let originalSelector = NSSelectorFromString("dataTaskWithURL:completionHandler:")
        let swizzledSelector = #selector(URLSession.swizzledDataTask(with:completionHandler:))
        
        let originalMethod = class_getInstanceMethod(URLSession.self, originalSelector)!
        let swizzledMethod = class_getInstanceMethod(URLSession.self, swizzledSelector)!
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    // Method to swizzle URLSessionTask methods for tracking
    private func swizzleNSURLSessionTaskMethods() {
        let _ = URLSessionTask.self
        
        let originalSelector = NSSelectorFromString("resume")
        let swizzledSelector = #selector(URLSessionTask.swizzledResume)
        
        let originalMethod = class_getInstanceMethod(URLSessionTask.self, originalSelector)!
        let swizzledMethod = class_getInstanceMethod(URLSessionTask.self, swizzledSelector)!
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    // Track starting URL, final URL, time interval and it's status
    @objc public func trackURL(startingURL: URL, finalURL: URL, withInterval interval: TimeInterval, successful: Bool) {
        // Notify about the new URL
        newURLCallback?(startingURL, finalURL, (interval * 1000))
        
        // Insert tracked URL into the database
        URLTracker.database.insertURL(startingURL: startingURL.absoluteString, finalURL: finalURL.absoluteString, interval: interval, successful: successful)
        trackedURLs.append(finalURL)
    }
    
    // Get tracked URLs
    @objc public func getTrackedURLs() -> [URL] {
        return trackedURLs
    }
    
    //Get invalid URLs
    @objc public func getInvalidURLs() -> [URL] {
        return invalidURLs
    }
    
    // Get tracked URLs from database
    @objc public func getDBTrackedURLs() -> [[String: Any]] {
        let urlDB = URLTracker.database.retrieveTrackedURLs()
        return urlDB
    }
}

extension URLSession {
    @objc func swizzledDataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        
        guard let scheme = url.scheme, scheme.hasPrefix("http") else {
            // Skip tracking if the URL scheme is not HTTP(S)
            return self.swizzledDataTask(with: url, completionHandler: completionHandler)
        }
        
        let startTime = Date()
        let task = self.swizzledDataTask(with: url, completionHandler: { (data, response, error) in
            // Track URL and its time interval
            DispatchQueue.main.async {
                let endTime = Date()
                let interval = endTime.timeIntervalSince(startTime)
                var finalURL = url
                var successful = true
                
                if let httpResponse = response as? HTTPURLResponse, let redirectedURL = httpResponse.url {
                    finalURL = redirectedURL
                    os_log("Swizzled URLSession Success: %@", type: .info, url.absoluteString)
                }else if let error = error {
                    successful = false
                    os_log("Swizzled URLSession Data Task: %@ - Final URL: %@ - Connection Failed With Error: %@", type: .error, url.absoluteString, finalURL.absoluteString, error.localizedDescription)
                    URLTracker.shared.invalidURLs.append(finalURL)
                } else {
                    successful = false
                    os_log("Swizzled URLSession Data Task Unknown Error: %@ - Final URL: %@ - Connection failed with error", type: .error, url.absoluteString, finalURL.absoluteString)
                    URLTracker.shared.invalidURLs.append(finalURL)
                }
                
                URLTracker.shared.trackURL(startingURL: url, finalURL: finalURL, withInterval: interval, successful: successful)
                
                // Call the original completion handler
                completionHandler(data, response, error)
            }
        })
        return task
    }
}

extension URLSessionTask {
    @objc func swizzledResume() {
        
        guard let originalRequest = self.originalRequest, let url = originalRequest.url, let scheme = url.scheme, scheme.hasPrefix("http")
        else {
            // Skip tracking if the URL scheme is not HTTP(S)
            return self.swizzledResume()
        }
        
        let startTime = Date()
        
        // Call the original implementation
        self.swizzledResume()
        
        if let originalRequest = self.originalRequest, let url = originalRequest.url {
            // Track URL and its time interval
            DispatchQueue.main.async {
                let endTime = Date()
                let interval = endTime.timeIntervalSince(startTime)
                os_log("Swizzled URLSessionTask Resume: %@", type: .info, url.absoluteString)
                
                // Determine if the connection was successful or not
                var successful = true
                                
                if let httpResponse = self.response as? HTTPURLResponse {
                    os_log("Swizzled URLSessionTask HTTP Status Code: %@ URL: %@", type: .info, String(httpResponse.statusCode), url.absoluteString)
                    successful = (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300)
                } else if let error = self.error {
                    successful = false
                    os_log("Swizzled URLSessionTask Error: %@ URL: %@", type: .error, error.localizedDescription, url.absoluteString)
                }
                
                //Check URL is vaild before saving
                let invalidURLs = URLTracker.shared.invalidURLs
                for invalidURL in invalidURLs{
                    if invalidURL != url{
                        URLTracker.shared.trackURL(startingURL: url, finalURL: url, withInterval: interval, successful: successful)
                    }
                }
            }
        }
    }
}
