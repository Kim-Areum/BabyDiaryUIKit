import CoreData
import WidgetKit

final class CoreDataStack {
    static let shared = CoreDataStack()

    private static let appGroupID = "group.io.analoglab.TrunkyDiary"

    private static var appGroupStoreURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
            .appendingPathComponent("BabyDiary.sqlite")
    }

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "BabyDiary")

        // 기존 데이터를 App Group으로 마이그레이션
        migrateStoreIfNeeded(to: Self.appGroupStoreURL)

        let description = NSPersistentStoreDescription(url: Self.appGroupStoreURL)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // iCloud 동기화 설정 (기본 켜짐, 명시적으로 끈 경우만 비활성화)
        let iCloudDisabled = UserDefaults.standard.object(forKey: "iCloudSyncDisabled") as? Bool ?? false
        if !iCloudDisabled {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.io.analoglab.TrunkyDiary"
            )
        } else {
            description.cloudKitContainerOptions = nil
        }

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data 로드 실패: \(error)")
                // CloudKit 실패 시 iCloud 끄고 로컬로 재시도
                if description.cloudKitContainerOptions != nil {
                    print("iCloud 동기화 비활성화 후 로컬로 재시도")
                    description.cloudKitContainerOptions = nil
                    container.persistentStoreDescriptions = [description]
                    container.loadPersistentStores { _, retryError in
                        if let retryError = retryError {
                            print("로컬 Core Data도 실패: \(retryError)")
                        }
                    }
                }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    private func migrateStoreIfNeeded(to targetURL: URL) {
        let defaultURL = NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("BabyDiary.sqlite")
        let fm = FileManager.default
        guard fm.fileExists(atPath: defaultURL.path),
              !fm.fileExists(atPath: targetURL.path) else { return }

        for ext in ["", "-wal", "-shm"] {
            let src = defaultURL.deletingPathExtension()
                .appendingPathExtension("sqlite\(ext)")
            let dst = targetURL.deletingPathExtension()
                .appendingPathExtension("sqlite\(ext)")
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }

        // External binary storage 디렉토리 복사
        let storesDir = NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent(".BabyDiary_SUPPORT")
        let targetDir = targetURL.deletingLastPathComponent()
            .appendingPathComponent(".BabyDiary_SUPPORT")
        if fm.fileExists(atPath: storesDir.path), !fm.fileExists(atPath: targetDir.path) {
            try? fm.copyItem(at: storesDir, to: targetDir)
        }
    }

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
            updateWidgetPhoto()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Core Data 저장 실패: \(error)")
        }
    }

    /// 최신 사진을 App Group에 위젯용으로 저장
    func exportWidgetPhoto() {
        updateWidgetPhoto()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func updateWidgetPhoto() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        ) else { return }

        let photoURL = groupURL.appendingPathComponent("widget_photo.jpg")

        // 최신 사진/동영상 썸네일이 있는 일기 찾기
        let req: NSFetchRequest<CDDiaryEntry> = CDDiaryEntry.fetchRequest()
        req.predicate = NSPredicate(format: "photoData != nil OR videoThumbnailData != nil")
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        req.fetchLimit = 1

        if let entry = try? viewContext.fetch(req).first {
            let data = entry.photoData ?? entry.videoThumbnailData
            try? data?.write(to: photoURL)
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

    func createEntry(date: Date, text: String, photoData: Data?, videoData: Data? = nil, videoThumbnailData: Data? = nil, audioFileNames: [String], audioTimestamps: [Date]) -> CDDiaryEntry {
        let entry = CDDiaryEntry(context: viewContext)
        entry.date = date
        entry.text = text
        entry.photoData = photoData
        entry.videoData = videoData
        entry.videoThumbnailData = videoThumbnailData
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
