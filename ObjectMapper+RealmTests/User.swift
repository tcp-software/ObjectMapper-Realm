//
//  User.swift
//  ObjectMapper+Realm
//
//  Created by Jake Peterson on 9/13/17.
//  Copyright 2017 Jake Peterson. All rights reserved.
//

import Foundation
import ObjectMapper
import RealmSwift
import ObjectMapper_Realm

class Storage {
    static let shared = Storage()

    var realm: Realm {
        get {
            let config = Realm.Configuration(inMemoryIdentifier: "test")
            return try! Realm.init(configuration: config)
        }
    }
}

class User: Object, Mappable {
    @Persisted(primaryKey: true) var username: String = ""
    var friends: List<User>?

    required convenience init?(map: ObjectMapper.Map) {
        self.init()
    }

    func mapping(map: ObjectMapper.Map) {
        username              <- map["username"]
        friends               <- (map["friends"], ListTransform<User>(onSerialize: onSerialize))
    }

    private func onSerialize(users: List<User>) {
        let realm = Storage.shared.realm
        try! realm.write {
            realm.add(users, update: .modified)
        }
    }
}
