//
//  DDLogProvider.swift
//  Data
//
//  Created by Amisha Italiya on 22/02/24.
//

import CocoaLumberjack
import SSZipArchive

public class DDLoggerProvider {

    public init() { }

    public func provideLogger() -> DDFileLogger {
        return DDFileLogger()
    }
}

public func LogD(_ message: @autoclosure () -> DDLogMessageFormat) {
    return DDLogVerbose(message())
}

public func LogE(_ message: @autoclosure () -> DDLogMessageFormat) {
    return DDLogError(message())
}

public func LogW(_ message: @autoclosure () -> DDLogMessageFormat) {
    return DDLogWarn(message())
}

public func LogI(_ message: @autoclosure () -> DDLogMessageFormat) {
    return DDLogInfo(message())
}

public func addDDLoggers() {
#if DEBUG
    DDLog.add(DDOSLogger.sharedInstance)            // console logger
#else
    let fileLogger: DDFileLogger = DDFileLogger()   // File Logger
    fileLogger.rollingFrequency = 0
    fileLogger.maximumFileSize = 3 * 1024 * 1024
    fileLogger.logFileManager.maximumNumberOfLogFiles = 2
    DDLog.add(fileLogger)
#endif
}

public extension DDFileLogger {

    func zipLogs() -> URL {
        removeAllZipLogs()
        createZipDirectory()

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-hh-mm a"

        let now = df.string(from: Date())
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Logs/\(now).zip")
        SSZipArchive.createZipFile(atPath: destination.path, withContentsOfDirectory: self.logFileManager.logsDirectory)
        return destination
    }

    func createZipDirectory() {
        let path = NSTemporaryDirectory() + "/Logs"
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                LogE("DDFileLogger: Unable to create directory at:\(path), error:\(error)")
            }
        }
    }

    func removeAllZipLogs() {
        let fileManager = FileManager.default

        let logsDir = fileManager.temporaryDirectory.appendingPathComponent("Logs")
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: logsDir,
                                                               includingPropertiesForKeys: nil,
                                                               options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            for fileURL in fileURLs where fileURL.pathExtension == "zip" {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            LogE("DDFileLogger: remove all zip error \(error)")
        }
    }
}
