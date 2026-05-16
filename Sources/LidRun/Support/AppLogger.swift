import Foundation
import LidRunShared
import os

enum AppLog {
    static let app = Logger(subsystem: LidRunConstants.bundleIdentifier, category: "app")
    static let power = Logger(subsystem: LidRunConstants.bundleIdentifier, category: "power")
    static let helper = Logger(subsystem: LidRunConstants.bundleIdentifier, category: "helper")
    static let ui = Logger(subsystem: LidRunConstants.bundleIdentifier, category: "ui")
}
