//
//  URLTracker.swift
//  CalculatorFramework
//
//  Created by Naveen Vijay on 2024-04-05.
//

import Foundation

@objc public class URLTracker: NSObject {
    @objc public static let shared = URLTracker()
    
    private var trackedURLs: [URL] = []
    private var taskStartTimes: [URLSessionTask: Date] = [:]
    
    // Closure property to notify about new URL and its time interval
    @objc public var newURLCallback: ((URL, TimeInterval) -> Void)?
    
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

    
    // Notify about new URL and its time interval
    @objc fileprivate func trackURL(_ url: URL, withInterval interval: TimeInterval) {
        newURLCallback?(url, interval)
        trackedURLs.append(url)
    }
    
    @objc public func getTrackedURLs() -> [URL] {
        return trackedURLs
    }
}

extension URLSession {
    @objc func swizzledDataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let startTime = Date()
        let task = self.swizzledDataTask(with: url, completionHandler: { (data, response, error) in
            // Calculate time interval
            let endTime = Date()
            let interval = endTime.timeIntervalSince(startTime)
            // Track URL here or perform any other logic
            print("Swizzled URLSession data task: \(url.absoluteString)")
            // Track URL and its time interval
            URLTracker.shared.trackURL(url, withInterval: interval)
            
            // Call the original completion handler
            completionHandler(data, response, error)
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
                URLTracker.shared.trackURL(url, withInterval: interval)
            }
        }
    }
}
