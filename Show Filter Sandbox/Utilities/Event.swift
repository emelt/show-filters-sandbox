//
//  Event.swift
//  MavFarm
//
//  Created by Colin Duffy on 8/15/19.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation

/**
 * Based on: https://blog.scottlogic.com/2015/02/05/swift-events.html
 */
class Event<T> {

    typealias EventHandler = (T) -> ()

    private var eventHandlers = [EventHandler]()

    func listen(handler: @escaping EventHandler) {
        eventHandlers.append(handler)
    }

    func dispatch(data: T) {
        for handler in eventHandlers {
            handler(data)
        }
    }
}
