//
//  Calculator.swift
//  CalculatorFramework
//
//  Created by Naveen Vijay on 2024-04-05.
//

import Foundation

@objc public class Calculator: NSObject {
    @objc public override init() {}

    @objc public func add(_ a: Int, _ b: Int) -> Int {
        return a + b
    }
}
