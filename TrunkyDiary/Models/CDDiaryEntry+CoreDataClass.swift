import Foundation
import CoreData

@objc(CDDiaryEntry)
public class CDDiaryEntry: NSManagedObject {
    @NSManaged public var date: Date
    @NSManaged public var text: String
    @NSManaged public var photoData: Data?
    @NSManaged public var videoData: Data?
    @NSManaged public var videoThumbnailData: Data?
    @NSManaged public var audioFileNames: NSArray  // [String]
    @NSManaged public var audioTimestamps: NSArray // [Date]
    @NSManaged public var stickerDataList: NSArray // [Data]
    @NSManaged public var createdAt: Date

    var hasVideo: Bool { videoData != nil }
    var hasMedia: Bool { photoData != nil || videoData != nil }

    var audioFileNamesArray: [String] {
        get { (audioFileNames as? [String]) ?? [] }
        set { audioFileNames = newValue as NSArray }
    }

    var audioTimestampsArray: [Date] {
        get { (audioTimestamps as? [Date]) ?? [] }
        set { audioTimestamps = newValue as NSArray }
    }

    var stickerDataListArray: [Data] {
        get { (stickerDataList as? [Data]) ?? [] }
        set { stickerDataList = newValue as NSArray }
    }

    var dateKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateStyle = .long
        return f.string(from: date)
    }

    var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

extension CDDiaryEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDDiaryEntry> {
        NSFetchRequest<CDDiaryEntry>(entityName: "CDDiaryEntry")
    }
}
