import Foundation
import CoreData

@objc(CDBaby)
public class CDBaby: NSManagedObject {
    @NSManaged public var name: String
    @NSManaged public var birthDate: Date
    @NSManaged public var photoData: Data?
    @NSManaged public var createdAt: Date

    var dayCount: Int {
        let days = Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0
        return days + 1
    }

    var monthCount: Int {
        let months = Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0
        return max(0, months)
    }

    var monthAndDays: String {
        let comps = Calendar.current.dateComponents([.month, .day], from: birthDate, to: Date())
        let months = max(0, comps.month ?? 0)
        let days = max(0, comps.day ?? 0)
        if months == 0 { return "\(days)일" }
        return days > 0 ? "\(months)개월 \(days)일" : "\(months)개월"
    }

    var ageYears: Int {
        let years = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return max(0, years)
    }

    func dayCountAt(date: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: birthDate, to: date).day ?? 0
        return days + 1
    }
}

extension CDBaby {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDBaby> {
        NSFetchRequest<CDBaby>(entityName: "CDBaby")
    }
}
