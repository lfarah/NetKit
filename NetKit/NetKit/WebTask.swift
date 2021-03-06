//
//  WebTask.swift
//  NetKit
//
//  Created by Aziz Uysal on 2/12/16.
//  Copyright © 2016 Aziz Uysal. All rights reserved.
//

import Foundation

public enum WebTaskResult {
  case Success, Failure(ErrorType)
}

public enum WebTaskError: ErrorType {
  case JSONSerializationFailedNilResponseBody
}

public class WebTask {
  
  public enum TaskType {
    case Data, Download, Upload
  }
  
  public typealias ResponseHandler = (NSData?, NSURLResponse?) -> WebTaskResult
  public typealias JSONHandler = (AnyObject) -> WebTaskResult
  public typealias ErrorHandler = (ErrorType) -> Void
  
  private let handlerQueue: NSOperationQueue = {
    let queue = NSOperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.suspended = true
    return queue
  }()
  
  private var webRequest: WebRequest
  private weak var webService: WebService?
  private let taskType: TaskType
  private var urlTask: NSURLSessionTask?
  
  private var urlResponse: NSURLResponse?
  private var responseData: NSData?
  private var responseURL: NSURL?
  private var taskResult: WebTaskResult?
  
  private var semaphore: dispatch_semaphore_t?
  
  deinit {
    handlerQueue.cancelAllOperations()
  }
  
  public init(webRequest: WebRequest, webService: WebService, taskType: TaskType = .Data) {
    self.webRequest = webRequest
    self.webService = webService
    self.taskType = taskType
  }
}

extension WebTask {
  
  public func resume() -> Self {
    
    if urlTask == nil {
      switch taskType {
      case .Data:
        urlTask = webService?.taskSource.dataTaskWithRequest?(webRequest.urlRequest) { data, response, error in
          self.handleResponse(data, response: response, error: error)
        }
      case .Download:
        urlTask = webService?.taskSource.downloadTaskWithRequest?(webRequest.urlRequest) { location, response, error in
          self.handleResponse(location: location, response: response, error: error)
        }
      case .Upload:
        urlTask = webService?.taskSource.uploadTaskWithRequest?(webRequest.urlRequest, fromData: webRequest.body) { data, response, error in
          self.handleResponse(data, response: response, error: error)
        }
      }
    }
    
    webService?.webDelegate?.tasks[urlTask!.taskIdentifier] = self
    urlTask?.resume()
    
    if let semaphore = semaphore {
      dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    }
    return self
  }
  
  public func resumeAndWait() -> Self {
    semaphore = dispatch_semaphore_create(0)
    return resume()
  }
  
  public func suspend() {
    urlTask?.suspend()
  }
  
  public func cancel() {
    urlTask?.cancel()
  }
  
  private func handleResponse(data: NSData? = nil, location: NSURL? = nil, response: NSURLResponse?, error: NSError?) {
    urlResponse = response
    responseData = data
    responseURL = location
    if let error = error {
      taskResult = WebTaskResult.Failure(error)
    }
    handlerQueue.suspended = false
    if let semaphore = semaphore {
      dispatch_semaphore_signal(semaphore)
    }
    if let urlTask = urlTask {
      webService?.webDelegate?.tasks.removeValueForKey(urlTask.taskIdentifier)
    }
  }
}

extension WebTask {
  
  public func setURLParameters(parameters: [String:AnyObject]) -> Self {
    webRequest.urlParameters = parameters
    return self
  }
  
  public func setBodyParameters(parameters: [String:AnyObject], encoding: WebRequest.ParameterEncoding? = nil) -> Self {
    webRequest.bodyParameters = parameters
    webRequest.parameterEncoding = encoding ?? .Percent
    if encoding == .JSON {
      webRequest.contentType = WebRequest.Headers.ContentType.json
    }
    return self
  }
  
  public func setBody(data: NSData) -> Self {
    webRequest.body = data
    return self
  }
  
  public func setPath(path: String) -> Self {
    webRequest.restPath = path
    return self
  }
  
  public func setJSON(json: AnyObject) -> Self {
    webRequest.contentType = WebRequest.Headers.ContentType.json
    webRequest.body = try? NSJSONSerialization.dataWithJSONObject(json, options: [])
    return self
  }
  
  public func setSOAP(soap: String) -> Self {
    webRequest.contentType = WebRequest.Headers.ContentType.xml
    webRequest.body = soap.placedInSoapEnvelope().dataUsingEncoding(NSUTF8StringEncoding)
    return self
  }
  
  public func setHeaders(headers: [String:String]) -> Self {
    webRequest.headers = headers
    return self
  }
  
  public func setHeaderValue(value: String, forName name: String) -> Self {
    webRequest.headers[name] = value
    return self
  }
  
  public func setParameterEncoding(encoding: WebRequest.ParameterEncoding) -> Self {
    webRequest.parameterEncoding = encoding
    return self
  }
  
  public func setCachePolicy(cachePolicy: NSURLRequestCachePolicy) -> Self {
    webRequest.cachePolicy = cachePolicy
    return self
  }
}

extension WebTask {
  
  func authenticate(authenticationMethod: String, completionHandler: WebService.ChallengeCompletionHandler) {
    if let authenticationHandler = webService?.authenticationHandler {
      taskResult = authenticationHandler(WebService.ChallengeMethod(method: authenticationMethod)!, completionHandler)
    } else {
      completionHandler(.PerformDefaultHandling, nil)
    }
  }
}

extension WebTask {
  
  public func authenticate(handler: WebService.AuthenticationHandler) -> Self {
    webService?.authenticationHandler = handler
    return self
  }
  
  public func response(handler: ResponseHandler) -> Self {
    handlerQueue.addOperationWithBlock {
      if let taskResult = self.taskResult {
        switch taskResult {
        case .Failure(_): return
        case .Success: break
        }
      }
      self.taskResult = handler(self.responseData, self.urlResponse)
    }
    
    return self
  }
  
  public func responseJSON(handler: JSONHandler) -> Self {
    return response { data, response in
      if let data = data {
        do {
          let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
          return handler(json)
        } catch let jsonError as NSError {
          return .Failure(jsonError)
        } catch {
          fatalError()
        }
      } else {
        return .Failure(WebTaskError.JSONSerializationFailedNilResponseBody)
      }
    }
  }
  
  public func responseError(handler: ErrorHandler) -> Self {
    handlerQueue.addOperationWithBlock {
      if let taskResult = self.taskResult {
        switch taskResult {
        case .Failure(let error): handler(error)
        case .Success: break
        }
      }
    }
    
    return self
  }
}

extension String {
  public func placedInSoapEnvelope() -> String {
    let xmlHeader = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    let soapStart = "<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">"
    let bodyStart = "<soap:Body>"
    let bodyEnd = "</soap:Body>"
    let soapEnd = "</soap:Envelope>"
    return xmlHeader+soapStart+bodyStart+self+bodyEnd+soapEnd
  }
}