//
//  LoginManager.swift
//  SwiftSample
//
//  Created by Iuliia Zhelem on 01.08.16.
//  Copyright © 2016 Akvelon. All rights reserved.
//

import Foundation

class CustomIdentityProviderManager: NSObject, AWSIdentityProviderManager{
    var tokens : [NSObject : AnyObject]?
    
    init(tokens: [NSObject : AnyObject]) {
        self.tokens = tokens
    }
    
    @objc func logins() -> AWSTask {
        return AWSTask(result: tokens)
    }
}

class LoginManager {

    var credentialsProvider : AWSCognitoCredentialsProvider?
    
    init() {
        let poolId = NSBundle.mainBundle().objectForInfoDictionaryKey(kCognitoPoolId) as! String
        AWSLogger.defaultLogger().logLevel = AWSLogLevel.Verbose
        self.credentialsProvider = AWSCognitoCredentialsProvider(regionType:AWSRegionType.USWest2, identityPoolId:poolId)
        let configuration = AWSServiceConfiguration(region:AWSRegionType.USWest2, credentialsProvider:self.credentialsProvider)
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration
    }
    
    func completeLogin(token : A0Token, _ profile: A0UserProfile, _ success : () -> (), _ failure : (NSError) -> ()) {
        
        doAmazonLogin(token.idToken, success: success, failure)
        MyApplication.sharedInstance.storeToken(token, profile: profile)
    }
    
    func doAmazonLogin(idToken: String, success : () -> (), _ failure : (NSError) -> ()) {
        var task: AWSTask?
        
        if self.credentialsProvider?.identityProvider.identityProviderManager == nil || idToken != MyApplication.sharedInstance.retrieveIdToken() {
            let IDPUrl = NSBundle.mainBundle().objectForInfoDictionaryKey(kCognitoIDPUrl) as! String
            let logins = [IDPUrl: idToken]
            task = self.initializeClients(logins)
        } else {
            self.credentialsProvider?.invalidateCachedTemporaryCredentials()
            task = self.credentialsProvider?.getIdentityId()
        }
        task!.continueWithBlock { (task: AWSTask!) -> AnyObject! in
            if (task.error != nil) {
                failure(task.error!)
            } else {
                // the task result will contain the identity id
                let cognitoId:String? = task.result as? String
                MyApplication.sharedInstance.storeCognitoToken(cognitoId)
                success()
            }
            return nil
        }
    }
    
    func initializeClients(logins: [NSObject : AnyObject]?) -> AWSTask? {
        print("Initializing Clients with logins")
        
        let manager = CustomIdentityProviderManager(tokens: logins!)
        self.credentialsProvider?.setIdentityProviderManagerOnce(manager)

        return self.credentialsProvider?.getIdentityId()
    }

    
    func resumeLogin(success : () -> (), _ failure : (NSError) -> ()) {
        let idToken = MyApplication.sharedInstance.retrieveIdToken()
        if (idToken != nil) {
            doAmazonLogin(idToken!, success: success, failure)
        } else {
            let error = NSError(domain: "com.auth0", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Something went wrong", comment: "This is an error")])
            failure(error)
        }
    }
}