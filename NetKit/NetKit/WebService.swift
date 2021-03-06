//
//  WebService.swift
//  NetKit
//
//  Created by Aziz Uysal on 2/12/16.
//  Copyright © 2016 Aziz Uysal. All rights reserved.
//

import Foundation

@objc public protocol SessionTaskSource {
  optional func dataTaskWithRequest(request: NSURLRequest, completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) -> NSURLSessionDataTask
  optional func downloadTaskWithRequest(request: NSURLRequest, completionHandler: (NSURL?, NSURLResponse?, NSError?) -> Void) -> NSURLSessionDownloadTask
  optional func uploadTaskWithRequest(request: NSURLRequest, fromData: NSData?, completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) -> NSURLSessionUploadTask
  optional func invalidateAndCancel()
}
extension NSURLSession: SessionTaskSource {}

public class WebService {
  
  public typealias AuthenticationHandler = (ChallengeMethod, ChallengeCompletionHandler) -> WebTaskResult
  public typealias ChallengeCompletionHandler = (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void
  public enum ChallengeMethod: String {
    case Default, HTTPBasic, HTTPDigest, HTMLForm, Negotiate, NTLM, ClientCertificate, ServerTrust
    init?(method: String) {
      switch method {
      case NSURLAuthenticationMethodDefault: self = .Default
      case NSURLAuthenticationMethodHTTPBasic: self = .HTTPBasic
      case NSURLAuthenticationMethodHTTPDigest: self = .HTTPDigest
      case NSURLAuthenticationMethodHTMLForm: self = .HTMLForm
      case NSURLAuthenticationMethodNegotiate: self = .Negotiate
      case NSURLAuthenticationMethodNTLM: self = .NTLM
      case NSURLAuthenticationMethodClientCertificate: self = .ClientCertificate
      case NSURLAuthenticationMethodServerTrust: self = .ServerTrust
      default: return nil
      }
    }
  }
  
  public var taskSource: SessionTaskSource
  
  private let urlString: String
  private let webQueue = NSOperationQueue()
  
  private(set) var webDelegate: WebDelegate?
  internal(set) var authenticationHandler: AuthenticationHandler?
  
  deinit {
    taskSource.invalidateAndCancel?()
  }
  
  public init(urlString: String) {
    self.urlString = urlString
    webDelegate = WebDelegate()
    taskSource = NSURLSession(configuration: .defaultSessionConfiguration(), delegate: webDelegate, delegateQueue: webQueue)
  }
}

extension WebService {
  
  public func HEAD(path: String) -> WebTask {
    return WebTask(webRequest: WebRequest(method: .HEAD, url: urlString.stringByAppendingPathComponent(path)), webService: self)
  }
  public func GET(path: String) -> WebTask {
    return WebTask(webRequest: WebRequest(method: .GET, url: urlString.stringByAppendingPathComponent(path)), webService: self)
  }
  public func POST(path: String) -> WebTask {
    return WebTask(webRequest: WebRequest(method: .POST, url: urlString.stringByAppendingPathComponent(path)), webService: self)
  }
  public func PUT(path: String) -> WebTask {
    return WebTask(webRequest: WebRequest(method: .PUT, url: urlString.stringByAppendingPathComponent(path)), webService: self)
  }
  public func DELETE(path: String) -> WebTask {
    return WebTask(webRequest: WebRequest(method: .DELETE, url: urlString.stringByAppendingPathComponent(path)), webService: self)
  }
}

extension String {
  func stringByAppendingPathComponent(str: String) -> String {
    let ns = self as NSString
    return ns.stringByAppendingPathComponent(str)
  }
}