import WidgetKit
import SwiftUI

// MARK: - Entry

struct TrunkyDiaryEntry: TimelineEntry {
    let date: Date
    let babyName: String
    let dayCount: Int
    let monthAndDays: String
    let image: UIImage?
}

// MARK: - Provider

struct TrunkyDiaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrunkyDiaryEntry {
        TrunkyDiaryEntry(date: .now, babyName: "아기", dayCount: 1, monthAndDays: "", image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrunkyDiaryEntry) -> Void) {
        completion(makeEntry(displaySize: context.displaySize))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrunkyDiaryEntry>) -> Void) {
        let entry = makeEntry(displaySize: context.displaySize)
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private let appGroupID = "group.io.analoglab.TrunkyDiary"

    private func makeEntry(displaySize: CGSize) -> TrunkyDiaryEntry {
        let stack = WidgetCoreDataStack.shared
        let baby = stack.fetchBaby()

        // App Group에서 위젯용 사진 로드
        var image: UIImage? = nil
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let photoURL = groupURL.appendingPathComponent("widget_photo.jpg")
            if let original = UIImage(contentsOfFile: photoURL.path) {
                image = resizedToFill(original, targetSize: displaySize)
            }
        }

        return TrunkyDiaryEntry(
            date: .now,
            babyName: baby?.name ?? "",
            dayCount: baby?.dayCount ?? 1,
            monthAndDays: baby?.monthAndDays ?? "",
            image: image
        )
    }

    /// 위젯 표시 크기에 맞게 scaledToFill + center crop 리사이즈
    private func resizedToFill(_ image: UIImage, targetSize: CGSize) -> UIImage {
        guard targetSize.width > 0, targetSize.height > 0 else { return image }

        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let scale = max(widthRatio, heightRatio)
        let scaledSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            let origin = CGPoint(
                x: (targetSize.width - scaledSize.width) / 2,
                y: (targetSize.height - scaledSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}

// MARK: - View

struct TrunkyDiaryWidgetView: View {
    let entry: TrunkyDiaryEntry

    var hasPhoto: Bool { entry.image != nil }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let uiImage = entry.image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    WDS.bgBase
                }

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("D+\(entry.dayCount)")
                                .font(WDS.font(16))
                                .foregroundColor(hasPhoto ? .white : WDS.fgStrong)
                                .shadow(color: hasPhoto ? .black.opacity(0.5) : .clear, radius: 2)

                            if !entry.monthAndDays.isEmpty {
                                Text(entry.monthAndDays)
                                    .font(WDS.font(12))
                                    .foregroundColor(hasPhoto ? .white.opacity(0.85) : WDS.fgNeutral)
                                    .shadow(color: hasPhoto ? .black.opacity(0.5) : .clear, radius: 1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.leading, 14)

                    Spacer()

                    if !entry.babyName.isEmpty {
                        HStack {
                            Spacer()
                            Text(entry.babyName)
                                .font(WDS.font(12))
                                .foregroundColor(hasPhoto ? .white.opacity(0.8) : WDS.fgPale)
                                .shadow(color: hasPhoto ? .black.opacity(0.5) : .clear, radius: 1)
                                .padding(.trailing, 14)
                                .padding(.bottom, 10)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Widget

@main
struct TrunkyDiaryWidgetBundle: Widget {
    let kind = "TrunkyDiaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrunkyDiaryProvider()) { entry in
            if #available(iOS 17.0, *) {
                TrunkyDiaryWidgetView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                TrunkyDiaryWidgetView(entry: entry)
            }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Trunky Diary")
        .description("아기의 D+ 일수를 확인하세요")
        .supportedFamilies([.systemSmall])
    }
}
