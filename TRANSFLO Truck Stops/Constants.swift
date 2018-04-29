//
//  Constants.swift
//  TRANSFLO Truck Stops
//
//  Created by Kristopher Sandrick on 4/25/18.
//  Copyright © 2018 Kristopher Sandrick. All rights reserved.
//

import Foundation

struct Services {
    static let apiURL = "http://webapp.transflodev.com/svc1.transflomobile.com/api/v3/stations/"
    static let apiKey = "amNhdGFsYW5AdHJhbnNmbG8uY29tOnJMVGR6WmdVTVBYbytNaUp6RlIxTStjNmI1VUI4MnFYcEVKQzlhVnFWOEF5bUhaQzdIcjVZc3lUMitPTS9paU8="
}

struct Distances {
    static let metersInAMile: Double = 1609.344
    static let milesInAMeter: Double = 0.000621371192
    static let defaultRadius: Double = 100.0
}
