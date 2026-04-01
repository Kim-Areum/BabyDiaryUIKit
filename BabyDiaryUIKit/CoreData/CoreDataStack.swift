import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BabyDiary")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data 로드 실패: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Core Data 저장 실패: \(error)")
        }
    }

    // MARK: - Baby CRUD

    func fetchBaby() -> CDBaby? {
        let request: NSFetchRequest<CDBaby> = CDBaby.fetchRequest()
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    func createBaby(name: String, birthDate: Date, photoData: Data?) -> CDBaby {
        let baby = CDBaby(context: viewContext)
        baby.name = name
        baby.birthDate = birthDate
        baby.photoData = photoData
        baby.createdAt = Date()
        save()
        return baby
    }

    // MARK: - DiaryEntry CRUD

    func fetchEntries(sortAscending: Bool = true) -> [CDDiaryEntry] {
        let request: NSFetchRequest<CDDiaryEntry> = CDDiaryEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: sortAscending)]
        return (try? viewContext.fetch(request)) ?? []
    }

    func fetchEntry(for date: Date) -> CDDiaryEntry? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let request: NSFetchRequest<CDDiaryEntry> = CDDiaryEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    func createEntry(date: Date, text: String, photoData: Data?, audioFileNames: [String], audioTimestamps: [Date]) -> CDDiaryEntry {
        let entry = CDDiaryEntry(context: viewContext)
        entry.date = date
        entry.text = text
        entry.photoData = photoData
        entry.audioFileNames = audioFileNames as NSArray
        entry.audioTimestamps = audioTimestamps as NSArray
        entry.stickerDataList = [] as NSArray
        entry.createdAt = Date()
        save()
        return entry
    }

    func deleteEntry(_ entry: CDDiaryEntry) {
        viewContext.delete(entry)
        save()
    }
}
