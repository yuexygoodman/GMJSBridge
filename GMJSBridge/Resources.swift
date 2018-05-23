//
//  Resources.swift
//  GMJSBridge
//
//  Created by Good Man on 2018/5/21.
//  Copyright © 2018年 Good Man. All rights reserved.
//

import Foundation

fileprivate let _bridgeBundle:Bundle? = {
    let path=Bundle(for: Bridge.self).path(forResource: "Assets", ofType: "bundle")
    if let path = path {
        let bundle:Bundle? = Bundle(path: path)
        bundle?.load()
        return bundle
    }
    return nil
}()

extension Bundle {
    static var assets:Bundle?{
        return _bridgeBundle
    }
    
    var jsForWebKit:String?{
        return try? String(contentsOfFile: self.path(forResource: "gmbridge", ofType: "js") ?? "")
    }
    
    var jsForJsCore:String?{
        return try? String(contentsOfFile:self.path(forResource: "gmbridge2", ofType: "js") ?? "")
    }
}
