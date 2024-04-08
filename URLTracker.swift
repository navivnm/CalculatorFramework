//
//  URLTracker.swift
//  CalculatorFramework
//
//  Created by Naveen Vijay on 2024-04-05.
//

import Foundation

@objc public class URLTracker: NSObject {
    
    @objc public static let shared = URLTracker()
    // Closure property to notify about new URL, final URL, and its time interval
    @objc public var newURLCallback: ((URL, URL, TimeInterval) -> Void)?
   
    private var trackedURLs: [URL] = []
    @objc public static let database = URLTrackerDatabase()
    
    private override init() {
        super.init()
        
        swizzleNSURLSessionMethods()
        swizzleNSURLSessionTaskMethods()
    }
    
    private func swizzleNSURLSessionMethods() {
        let _ = URLSession.shared
        let originalSelector = NSSelectorFromString("dataTaskWithURL:completionHandler:")
        let swizzledSelector = #selector(URLSession.swizzledDataTask(with:completionHandler:))
        
        let originalMethod = class_getInstanceMethod(URLSession.self, originalSelector)!
        let swizzledMethod = class_getInstanceMethod(URLSession.self, swizzledSelector)!
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    
    private func swizzleNSURLSessionTaskMethods() {
        let _ = URLSessionTask.self
        
        let originalSelector = NSSelectorFromString("resume")
        let swizzledSelector = #selector(URLSessionTask.swizzledResume)
        
        let originalMethod = class_getInstanceMethod(URLSessionTask.self, originalSelector)!
        let swizzledMethod = class_getInstanceMethod(URLSessionTask.self, swizzledSelector)!
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    
    // Track starting URL, final URL, and its time interval
    @objc public func trackURL(startingURL: URL, finalURL: URL, withInterval interval: TimeInterval, successful: Bool) {
        newURLCallback?(startingURL, finalURL, (interval * 1000))
        URLTracker.database.insertURL(startingURL: startingURL.absoluteString, finalURL: finalURL.absoluteString, interval: interval, successful: successful)
        trackedURLs.append(finalURL)
        // You can store or use the final URL as needed
    }
    
    @objc public func getTrackedURLs() -> [URL] {
        return trackedURLs
    }
    
    @objc public func getDBTrackedURLs() -> [[String: Any]] {
        let abcd = URLTracker.database.retrieveTrackedURLs()
        return abcd
    }
}

extension URLSession {
    @objc func swizzledDataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
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
                }else if let error = error {
                    successful = false
                    print("===s Swizzled URLSession data task: \(url.absoluteString) - Final URL: \(finalURL.absoluteString) - Connection failed with error: \(error.localizedDescription)")
                } else {
                    successful = false
                    print("===s unknown error Swizzled URLSession data task: \(url.absoluteString) - Final URL: \(finalURL.absoluteString) - Connection successful")
                }
                
                /*if let error = error {
                    successful = false
                    print("===s Swizzled URLSession data task: \(url.absoluteString) - Final URL: \(finalURL.absoluteString) - Connection failed with error: \(error.localizedDescription)")
                } else {
                    print("Swizzled URLSession data task: \(url.absoluteString) - Final URL: \(finalURL.absoluteString) - Connection successful")
                }*/
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
        let startTime = Date()
        
        // Call the original implementation
        self.swizzledResume()
        
        if let originalRequest = self.originalRequest, let url = originalRequest.url {
            // Track URL and its time interval
            DispatchQueue.main.async {
                let endTime = Date()
                let interval = endTime.timeIntervalSince(startTime)
                print("Swizzled URLSessionTask resume: \(url.absoluteString)")
                // Determine if the connection was successful or not
                var successful = true
                // Determine if the connection was successful or not
                                
                if let httpResponse = self.response as? HTTPURLResponse {
                    print("===s HTTP status code: \(String(httpResponse.statusCode) + "URL: " + url.absoluteString))")
                    successful = (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300)
                } else if let error = self.error {
                    successful = false
                    print("===s Error: \(error.localizedDescription + "URL: " + url.absoluteString)")
                } 
                URLTracker.shared.trackURL(startingURL: url, finalURL: url, withInterval: interval, successful: successful)
            }
        }
    }
}
