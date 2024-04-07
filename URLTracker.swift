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
    
    // Closure property to notify about new URL
    @objc public var newURLCallback: ((URL) -> Void)?
    
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

    
    @objc fileprivate func trackURL(_ url: URL) {
        // You can implement additional logic here, such as measuring timing or handling redirections.
        // Notify about new URL
        newURLCallback?(url)
        trackedURLs.append(url)
    }
    
    @objc public func getTrackedURLs() -> [URL] {
        return trackedURLs
    }
}

extension URLSession {
    @objc func swizzledDataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        // Track URL here or perform any other logic
        print("Swizzled URLSession data task: \(url.absoluteString)")
        URLTracker.shared.trackURL(url)
        // Call the original implementation
        return self.swizzledDataTask(with: url, completionHandler: completionHandler)
    }
}

extension URLSessionTask {
    @objc func swizzledResume() {
        if let originalRequest = self.originalRequest,
           let url = originalRequest.url {
            // Track URL here or perform any other logic
            print("Swizzled URLSessionTask resume: \(url.absoluteString)")
            URLTracker.shared.trackURL(url)
        }
        // Call the original implementation
        self.swizzledResume()
    }
}
