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
    public var newURLCallback: ((URL) -> Void)?
    
    private override init() {
        super.init()
        
        swizzleNSURLSessionMethods()
    }
    
    private func swizzleNSURLSessionMethods() {
        let _ = URLSession.self
        //let originalSelector = NSSelectorFromString("dataTaskWithURL:completionHandler:")
        let originalSelector = NSSelectorFromString("dataTaskWithURL:completionHandler:")
        let swizzledSelector = #selector(URLSession.swizzledDataTask(with:completionHandler:))
        
        let originalMethod = class_getInstanceMethod(URLSession.self, originalSelector)!
        let swizzledMethod = class_getInstanceMethod(URLSession.self, swizzledSelector)!
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    /*@objc func swizzledDataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        trackURL(url)
        return self.swizzledDataTask(with: url, completionHandler: completionHandler)
    }*/
    
    fileprivate func trackURL(_ url: URL) {
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
        print("Swizzled data task: \(url.absoluteString)")
        URLTracker.shared.trackURL(url)
        // Call the original implementation
        return self.swizzledDataTask(with: url, completionHandler: completionHandler)
    }
}
