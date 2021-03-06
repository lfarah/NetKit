//
//  ServiceController.swift
//  NetKitExample
//
//  Created by Aziz Uysal on 2/17/16.
//  Copyright © 2016 Aziz Uysal. All rights reserved.
//

import Foundation
import NetKit

struct ServiceResult {
  static let Success = "Success"
  static let Error = "Error"
}

class ServiceController {
  
  private static let jsonService = JsonService()
  private static let serviceWithDelegate = ServiceWithDelegate()
  private static let weatherService = GlobalWeatherService()
  
  private static var pollerAuthCounter = 0
  
  private static let networkQueue = dispatch_queue_create("networkQueue", DISPATCH_QUEUE_SERIAL)
  
  // MARK: ExampleService
  
  class func getPosts() {
    dispatch_sync(networkQueue) {
      jsonService.getPosts()
        .responseJSON { json in
          print(json)
          notifyUser(JsonService.PostsDownloaded)
          return .Success
        }
        .responseError { error in
          print(error)
          notifyUser(JsonService.PostsDownloaded, error: error)
        }
        .resumeAndWait()
    }
  }
  
  class func addPost(post: Post) {
    dispatch_sync(networkQueue) {
      jsonService.addPost()
        .setJSON(post.toJson())
        .responseJSON { json in
          print(json)
          notifyUser(JsonService.PostsCreated)
          return .Success
        }
        .responseError { error in
          print(error)
          notifyUser(JsonService.PostsCreated, error: error)
        }
        .resumeAndWait()
    }
  }
  
  class func updatePost(post: Post) {
    dispatch_sync(networkQueue) {
      jsonService.updatePost()
        .setPath(String(post.id))
        .setJSON(post.toJson())
        .responseJSON { json in
          print(json)
          notifyUser(JsonService.PostsUpdated)
          return .Success
        }
        .responseError { error in
          print(error)
          notifyUser(JsonService.PostsUpdated, error: error)
        }
        .resumeAndWait()
    }
  }
  
  // MARK: ServiceWithDelegate
  
  class func getComments() {
    serviceWithDelegate.getComments()
      .responseJSON { json in
        print(json)
        return .Success
      }
      .responseError { error in
        print(error)
      }
      .resume()
  }
  
  // MARK: GlobalWeatherService
  
  class func getCities(country: String)  {
    weatherService.getCitiesByCountry()
      .setURLParameters(["op":"GetCitiesByCountry"])
      .setSOAP("<GetCitiesByCountry xmlns=\"http://www.webserviceX.NET\"><CountryName>\(country)</CountryName></GetCitiesByCountry>")
      .response { data, response in
        print(String(data: data!, encoding: NSUTF8StringEncoding))
        notifyUser(GlobalWeatherService.ReceivedCities)
        return .Success
      }
      .responseError { error in
        print(error)
        notifyUser(GlobalWeatherService.ReceivedCities, error: error)
      }
      .resume()
  }
  
  // MARK: Private methods
  
  private class func notifyUser(event: String, error: ErrorType? = nil) {
    let userInfo: [String:AnyObject]
    if let error = error {
      userInfo = [ServiceResult.Success:false, ServiceResult.Error: error as NSError]
    } else {
      userInfo = [ServiceResult.Success:true]
    }
    NSNotificationCenter.defaultCenter().postNotificationName(event, object: nil, userInfo: userInfo)
  }
}