//
//  JSBridge.swift
//  GMJSBridge
//
//  Created by Good Man on 2018/5/11.
//  Copyright © 2018年 Good Man. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import JavaScriptCore

/// To send or receive command.
public protocol JSBridge {
    weak var loader:H5Loader?{get}
    func addHandler(_ handler:CommandHandler) -> Void;
    func addHandler(with name:String,block:@escaping CommandHandlerBlock) -> Void;
    func sendCommand(with name:String,params:[Any]?,callBack:CommandCallBack?) -> Void
    func link(loader:H5Loader) -> Void
    init?(with loader:H5Loader)
}

/// virtual class.
@objc open class Bridge:NSObject,JSBridge {
    public weak var loader: H5Loader?
    
    var handlers:[String:CommandHandler]=[:]
    
    public func addHandler(_ handler:CommandHandler){
        if handler.name.count>0 {
            handlers[handler.name]=handler;
        }
    }
    
    public func addHandler(with name:String,block:@escaping CommandHandlerBlock){
        if name.count>0 {
            let handler=CommandBlockHandler(name: name, block: block)
            handlers[name]=handler
        }
    }
    
    public func sendCommand(with name:String,params:[Any]?=nil,callBack:CommandCallBack?=nil) -> Void {
        if name.count>0 {
            var script:String="window.GMJSBridge._getCommand('\(name)'"
            if let params=params {
                for param in params {
                    script+="\(param)"
                }
            }
            script+=")"
            loader?.evalJavaScript(js: script, handler:callBack)
        }
    }
    
    public required init?(with loader: H5Loader) {
        self.loader=loader
    }
    
    public func link(loader: H5Loader) {}
}

@objc protocol JSCoreDelegate:JSExport {
    func getCommand(_ name:String)
}

@objc open class JSCoreBridge:Bridge {
    public required init?(with loader: H5Loader) {
        if !(loader is UIWebView) {
            return nil
        }
        super.init(with: loader)
        let webView=loader as! UIWebView
        webView.delegate=webView
        webView.addDelegate(delegate: self)
    }
    
    public convenience init(with webView:UIWebView){
        self.init(with: webView)
    }
    
    public override func link(loader: H5Loader) {
        let js=Bundle.assets?.jsForJsCore
        if var js = js {
            for (name,_) in handlers {
                js += "window.GMJSBridge.\(name)=function(){this._postMsg('\(name)',arguments);};"
            }
            loader.injectJavaScript(js: js, at: .InjectAtDocStart, handler: nil)
        }
    }
}

extension JSCoreBridge:UIWebViewDelegate {
    public func webViewDidStartLoad(_ webView: UIWebView) {
        if let loader=loader {
            loader.link(bridge: self)
            self.link(loader: loader)
        }
    }
    
    public func webViewDidFinishLoad(_ webView: UIWebView) {
        if let loader=loader {
            loader.link(bridge: self)
            self.link(loader: loader)
        }
    }
}

@objc extension JSCoreBridge:JSCoreDelegate {
    func getCommand(_ name:String) {
        let args=JSContext.currentArguments()
        if var args = args,args.count>2 {
            let context="\(args[1])"
            let handler=handlers[name]
            if let handler = handler {
                let params = args.count>3 ? Array<Any>(args[3...(args.count-1)]) : nil
                handler.exec(with: params, context: context, complete: { (data, context, err) in
                    if err == nil {
                        let funStr = "\(args[2])"
                        let objs = funStr.components(separatedBy: ".")
                        var shareCallBack = JSContext.current().evaluateScript(objs[0])
                        for i in 0..<objs.count-1 {
                            shareCallBack=shareCallBack?.forProperty(objs[i+1])
                        }
                        var args:[Any] = [context]
                        if let data=data {
                            if (data is [Any] || data is [String:Any]),let json=try? JSONSerialization.data(withJSONObject: data),let jsonstr = String(data: json, encoding: .utf8) {
                                args.append(jsonstr)
                            }
                            else {
                                args.append("\(data)")
                            }
                        }
                        let _=shareCallBack?.call(withArguments: args)
                    }
                })
            }
        }
    }
}

open class WKBridge:Bridge {
    
    public required init?(with loader: H5Loader) {
        if !(loader is WKWebView) {
            return nil
        }
        super.init(with: loader)
        let webView=loader as! WKWebView
        webView.navigationDelegate=webView
        loader .link(bridge: self)
        self.link(loader: loader)
    }
    
    public convenience init(with webView:WKWebView){
        self.init(with: webView)
    }
    
    public override func link(loader: H5Loader) {
        let js = Bundle.assets?.jsForWebKit
        if let js = js {
            loader.injectJavaScript(js: js, at: .InjectAtDocStart, handler: nil)
        }
    }
    
    public override func addHandler(_ handler: CommandHandler) {
        super.addHandler(handler)
        loader?.injectJavaScript(js:"window.GMJSBridge.\(handler.name)=function(){this._postMsg('\(handler.name)',arguments);};" , at: .InjectAtDocStart, handler: nil)
    }
    
    public override func addHandler(with name: String, block: @escaping CommandHandlerBlock) {
        super.addHandler(with: name, block: block)
        loader?.injectJavaScript(js: "window.GMJSBridge.\(name)=function(){this._postMsg('\(name)',arguments);};", at: .InjectAtDocStart, handler: nil)
    }
}

extension WKBridge:WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let dict = message.body as? [String:Any] {
            let params = dict["params"] as? [Any]
            if let handler=handlers["\(dict["commandName"] ?? "")"],let context = dict["context"] as? String {
                let callBack=dict["callBack"] as? String
                handler.exec(with: params, context: context, complete: {[weak self] (data, context, err) in
                    if let sSelf=self {
                        if err == nil,let callBack=callBack {
                            var js:String
                            if let data = data {
                                if (data is [Any] || data is [String:Any]),let json=try? JSONSerialization.data(withJSONObject: data),let jsonstr = String(data: json, encoding: .utf8) {
                                    js = "\(callBack)('\(context)','\(jsonstr)')"
                                }
                                else {
                                    js = "\(callBack)('\(context)','\(data)')"
                                }
                            }
                            else{
                                js = "\(callBack)('\(context)')"
                            }
                            sSelf.loader?.evalJavaScript(js: js, handler: nil)
                        }
                    }
                })
            }
        }
    }
}
