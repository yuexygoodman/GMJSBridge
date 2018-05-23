//
//  H5Loader.swift
//  GMJSBridge
//
//  Created by Good Man on 2018/5/11.
//  Copyright © 2018年 Good Man. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import JavaScriptCore

public enum InjectTime:Int {
    case InjectAtDocStart=0,InjectAtDocEnd
}

/// A loader to load h5 webpage,both 'UIWebView' and 'WKWebView' comform to this protocal.
public protocol H5Loader:class{
    func loadH5(url:String) -> Void
    func loadH5(html:String) -> Void
    func evalJavaScript(js:String,handler:((_ data:Any?,_ err:Error?)->Void)?) -> Void
    func injectJavaScript(js:String,at time:InjectTime ,handler:((_ data:Any?,_ err:Error?)->Void)?)->Void
    func link(bridge:JSBridge) -> Void
}

private var kUIWebView_DelegatesKey:Void?
private let kJSContextKeyPath = "documentView.webView.mainFrame.javaScriptContext"
private let kJSContextRootOBJ = "_gm_jsbridge" as NSString

extension UIWebView:H5Loader{
    var delegates:[WeakDelegate<UIWebViewDelegate>]{
        get {
            var delegates=objc_getAssociatedObject(self, &kUIWebView_DelegatesKey)
            if delegates == nil {
                delegates=[WeakDelegate<UIWebViewDelegate>]()
                objc_setAssociatedObject(self, &kUIWebView_DelegatesKey, delegates, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            return delegates as! [WeakDelegate<UIWebViewDelegate>]
        }
        set {
            objc_setAssociatedObject(self, &kUIWebView_DelegatesKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public func addDelegate(delegate:UIWebViewDelegate){
        if self.delegate == nil {
            self.delegate=self
        }
        let wD=WeakDelegate(delegate: delegate)
        if !self.delegates.contains(wD) {
            self.delegates.append(wD)
        }
    }
    
    public func loadH5(url: String) {
        if let uRL=URL(string: url) {
            let request=URLRequest(url:uRL)
            loadRequest(request)
        }
    }
    
    public func loadH5(html: String) {
        loadHTMLString(html, baseURL: nil)
    }
    
    public func evalJavaScript(js: String, handler: ((Any?, Error?) -> Void)?) {
        let rst=stringByEvaluatingJavaScript(from: js)
        if let handler=handler {
            handler(rst,nil)
        }
    }
    
    public func injectJavaScript(js: String, at time: InjectTime, handler: ((Any?, Error?) -> Void)?) {
        let rst=stringByEvaluatingJavaScript(from: js)
        if let handler=handler {
            handler(rst,nil)
        }
    }
    
    public func link(bridge: JSBridge) {
        if let jsContext = value(forKeyPath: kJSContextKeyPath) as? JSContext {
            jsContext.setObject(bridge, forKeyedSubscript: kJSContextRootOBJ)
        }
    }
}

extension UIWebView:UIWebViewDelegate {
    public func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        for wkDelegate in delegates {
            if wkDelegate.delegate?.responds(to: #selector(UIWebViewDelegate.webView(_:shouldStartLoadWith:navigationType:))) ?? false {
                return wkDelegate.delegate!.webView!(webView, shouldStartLoadWith: request, navigationType: navigationType)
            }
        }
        return true
    }
    
    public func webViewDidStartLoad(_ webView: UIWebView) {
        delegates.forEach { (wkDelegate) in
            wkDelegate.delegate?.webViewDidStartLoad?(webView)
        }
    }
    
    public func webViewDidFinishLoad(_ webView: UIWebView) {
        delegates.forEach { (wkDelegate) in
            wkDelegate.delegate?.webViewDidFinishLoad?(webView)
        }
    }
    
    public func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        delegates.forEach { (wkDelegate) in
            wkDelegate.delegate?.webView?(webView, didFailLoadWithError: error)
        }
    }
}

fileprivate var kWKWebView_DelegatesKey:Void?
fileprivate let kWebKitRootMsgHandlerName = "getCommand"

extension WKWebView:H5Loader {
    var delegates:[WeakDelegate<WKNavigationDelegate>]{
        get {
            var delegates = objc_getAssociatedObject(self, &kWKWebView_DelegatesKey)
            if delegates == nil {
                delegates = [WeakDelegate<WKNavigationDelegate>]()
                objc_setAssociatedObject(self, &kWKWebView_DelegatesKey, delegates, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            return delegates as! [WeakDelegate<WKNavigationDelegate>]
        }
        set {}
    }
    
    public func addDelegate(delegate:WKNavigationDelegate){
        if navigationDelegate == nil {
            navigationDelegate=self
        }
        let wD=WeakDelegate(delegate: delegate)
        if !self.delegates.contains(wD) {
            self.delegates.append(wD)
        }
    }
    
    public func loadH5(html: String) {
        loadHTMLString(html, baseURL: nil)
    }
    
    public func loadH5(url: String) {
        if let uRL=URL(string:url) {
            load(URLRequest(url: uRL))
        }
    }
    
    public func evalJavaScript(js: String, handler: ((Any?, Error?) -> Void)?) {
        evaluateJavaScript(js, completionHandler: handler)
    }
    
    public func injectJavaScript(js: String, at time: InjectTime, handler: ((Any?, Error?) -> Void)?) {
        let userScript = WKUserScript(source: js, injectionTime:WKUserScriptInjectionTime(rawValue: time.rawValue)! , forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)
    }
    
    public func link(bridge: JSBridge) {
        if let bridge = bridge as? WKScriptMessageHandler {
            configuration.userContentController.add(bridge, name: kWebKitRootMsgHandlerName)
        }
    }
}

extension WKWebView:WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        for wkDelegate in delegates {
            guard wkDelegate.delegate?.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler) == nil else {
                return
            }
        }
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        delegates.forEach { (wkDelegate) in
            wkDelegate.delegate?.webView?(webView, didStartProvisionalNavigation: navigation)
        }
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        for wkDelegate in delegates {
            if wkDelegate.delegate?.responds(to: #selector(WKNavigationDelegate.webView(_:didReceive:completionHandler:))) ?? false {
                wkDelegate.delegate!.webView!(webView, didReceive: challenge, completionHandler: completionHandler)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        delegates.forEach { (wkDelegate) in
            wkDelegate.delegate?.webView?(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
        }
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        delegates.forEach { (wkDelegate) in
            wkDelegate.delegate?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
        }
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        delegates.forEach { (wkDelegate) in
            wkDelegate.delegate?.webView?(webView, didCommit: navigation)
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        delegates.forEach { (wkDelegate) in
            wkDelegate.delegate?.webView?(webView, didFinish: navigation)
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        delegates.forEach { (wkDelegate) in
            wkDelegate.delegate?.webView?(webView, didFail: navigation, withError: error)
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        for wkDelegate in delegates {
            guard wkDelegate.delegate?.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler) == nil else {
                return
            }
        }
        decisionHandler(.allow)
    }
    
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if #available(iOS 9.0, *) {
            delegates.forEach { (wkDelegate) in
                wkDelegate.delegate?.webViewWebContentProcessDidTerminate?(webView)
            }
        }
    }
}

class WeakDelegate<T:NSObjectProtocol>: Hashable {
    static func ==(lhs: WeakDelegate<T>, rhs: WeakDelegate<T>) -> Bool {
        return lhs === rhs && lhs.hashValue==rhs.hashValue
    }
    
    var hashValue: Int {
        return delegate?.hash ?? 0
    }
    
    weak var delegate:T?
    
    init(delegate:T) {
        self.delegate=delegate
    }
}
