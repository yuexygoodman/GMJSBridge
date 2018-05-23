//
//  CommandHandler.swift
//  GMJSBridge
//
//  Created by Good Man on 2018/5/11.
//  Copyright © 2018年 Good Man. All rights reserved.
//

import Foundation

/// Process completely.
public typealias CommandHandlerCompleteBlock = (_ data:Any?,_ context:String,_ error:Error?)->Void;

/// For 'CommandBlockHandler' class.
public typealias CommandHandlerBlock = (_ params:[Any]?,_ context:String,_ complete:@escaping CommandHandlerCompleteBlock)->Void;

/// After sending a command,we can wait for a callback from h5.
public typealias CommandCallBack = (_ data:Any?,_ error:Error?)->Void

/// Designed to process commands from h5.
public protocol CommandHandler {
    var name:String{get} // the name of a command.
    func exec(with params:[Any]?,context:String,complete:@escaping CommandHandlerCompleteBlock) -> Void // handler
}


/// To support the form of name-block API.
class CommandBlockHandler: CommandHandler {
    let name: String
    
    var block:CommandHandlerBlock
    
    init(name:String,block:@escaping CommandHandlerBlock) {
        self.name=name
        self.block=block
    }
    
    func exec(with params: [Any]?, context: String, complete:@escaping CommandHandlerCompleteBlock) {
        block(params, context, complete)
    }
}
