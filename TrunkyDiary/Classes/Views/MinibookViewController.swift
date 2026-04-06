import UIKit
import UIKit

class MinibookViewController: UIViewController {

    // MARK: - Page Model

    private enum PageContent {
        case cover
        case tableOfContents(items: [(month: Int, firstPage: Int, lastPage: Int)])
        case entryFirst(entry: CDDiaryEntry, textSlice: String, pageNum: Int)
        case entryContinuation(entry: CDDiaryEntry, textSlice: String, pageNum: Int)
        case empty
        case backCover
    }

    // MARK: - Period Filter

    private enum Period: Int, CaseIterable {
        case all = -1
        case months1to12 = 0
        case months13to24 = 1
        case age2 = 2
        case age3 = 3
        case age4plus = 4

        var title: String {
            switch self {
            case .all: return "전체"
            case .months1to12: return "1~12개월"
            case .months13to24: return "13~24개월"
            case .age2: return "만 2세"
            case .age3: return "만 3세"
            case .age4plus: return "만 4세~"
            }
        }

        func contains(monthAge: Int) -> Bool {
            switch self {
            case .all: return true
            case .months1to12: return monthAge >= 0 && monthAge < 12
            case .months13to24: return monthAge >= 12 && monthAge < 24
            case .age2: return monthAge >= 24 && monthAge < 36
            case .age3: return monthAge >= 36 && monthAge < 48
            case .age4plus: return monthAge >= 48
            }
        }
    }

    // MARK: - Properties

    private var allEntries: [CDDiaryEntry] = []
    private var entries: [CDDiaryEntry] = []
    private var pages: [PageContent] = []
    private var currentPage = 0
    private var coverPhotoData: Data?
    private var isExporting = false
    private var selectedPeriod: Period = .all

    private let coverKey = "minibook_cover_photo" // legacy, migrated to Core Data
    private let firstPageWithPhotoChars = 210
    private let firstPageNoPhotoChars = 450
    private let continuationChars = 500

    // UI
    private let pageContainerView = UIView()
    private let pageLabel = UILabel()
    private let firstBtn = UIButton(type: .system)
    private let prevBtn = UIButton(type: .system)
    private let nextBtn = UIButton(type: .system)
    private let lastBtn = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private var exportOverlay: UIView?
    private let periodScrollView = UIScrollView()
    private let periodStack = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupNavBar()
        setupPeriodSelector()
        setupPageContainer()
        setupNavButtons()
        setupSwipeGestures()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    // MARK: - Data

    private func loadData() {
        allEntries = CoreDataStack.shared.fetchEntries(sortAscending: true)
        let baby = CoreDataStack.shared.fetchBaby()
        // Core Data에서 로드, 없으면 레거시 UserDefaults에서 마이그레이션
        if let data = baby?.coverPhotoData {
            coverPhotoData = data
        } else if let legacyData = UserDefaults.standard.data(forKey: coverKey) {
            coverPhotoData = legacyData
            baby?.coverPhotoData = legacyData
            CoreDataStack.shared.save()
            UserDefaults.standard.removeObject(forKey: coverKey)
        }
        filterEntries()
        buildAvailablePeriods()
    }

    private func filterEntries() {
        let baby = CoreDataStack.shared.fetchBaby()
        if selectedPeriod == .all {
            entries = allEntries
        } else {
            entries = allEntries.filter { entry in
                let monthAge = baby.map { monthsBetween(from: $0.birthDate, to: entry.date) } ?? 0
                return selectedPeriod.contains(monthAge: monthAge)
            }
        }
        buildPages()
        currentPage = 0
        renderCurrentPage()
        updateNavButtons()
    }

    private func buildAvailablePeriods() {
        let baby = CoreDataStack.shared.fetchBaby()
        periodStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 데이터가 있는 기간 수 세기
        var availablePeriods: [Period] = []
        for period in Period.allCases where period != .all {
            let hasData = allEntries.contains { entry in
                let monthAge = baby.map { monthsBetween(from: $0.birthDate, to: entry.date) } ?? 0
                return period.contains(monthAge: monthAge) && (!entry.text.isEmpty || entry.photoData != nil)
            }
            if hasData { availablePeriods.append(period) }
        }

        // 기간이 1개 이하면 필터 불필요 → 숨김
        if availablePeriods.count <= 1 {
            periodScrollView.isHidden = true
            selectedPeriod = .all
            return
        }

        periodScrollView.isHidden = false
        let allPeriods: [Period] = [.all] + availablePeriods

        for period in allPeriods {
            let btn = UIButton(type: .system)
            var periodBtnConfig = UIButton.Configuration.plain()
            var periodTitle = AttributedString(period.title)
            periodTitle.font = DS.font(12)
            periodBtnConfig.attributedTitle = periodTitle
            periodBtnConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            btn.configuration = periodBtnConfig
            btn.tag = period.rawValue + 100
            btn.layer.cornerRadius = 14
            btn.addTarget(self, action: #selector(periodTapped(_:)), for: .touchUpInside)

            if period == selectedPeriod {
                btn.backgroundColor = DS.accent
                btn.configuration?.baseForegroundColor = .white
            } else {
                btn.backgroundColor = DS.bgSubtle
                btn.configuration?.baseForegroundColor = DS.fgNeutral
            }

            periodStack.addArrangedSubview(btn)
        }
    }

    @objc private func periodTapped(_ sender: UIButton) {
        let rawValue = sender.tag - 100
        guard let period = Period(rawValue: rawValue) else { return }
        selectedPeriod = period
        filterEntries()
        buildAvailablePeriods()
    }

    private func buildPages() {
        pages = [.cover]

        let validEntries = entries.filter { !$0.text.isEmpty || $0.photoData != nil }

        if validEntries.isEmpty {
            pages.append(.empty)
        } else {
            // 1단계: 엔트리 페이지 빌드 (pageNum 계산)
            var entryPages: [PageContent] = []
            var pageNum = 1
            // 개월수 → 첫/마지막 페이지 번호 매핑
            var monthToFirstPage: [Int: Int] = [:]
            var monthToLastPage: [Int: Int] = [:]
            let baby = CoreDataStack.shared.fetchBaby()

            for entry in validEntries {
                let monthAge = baby.map { monthsBetween(from: $0.birthDate, to: entry.date) } ?? 0

                if monthToFirstPage[monthAge] == nil {
                    monthToFirstPage[monthAge] = pageNum
                }

                let text = entry.text
                let hasPhoto = entry.photoData != nil
                let pageWidth = UIScreen.main.bounds.width * 0.8
                let textWidth = pageWidth - 40 // 좌우 패딩 24씩

                // 줄 수 고정
                let photoLines = 6       // 사진 있는 페이지
                let noPhotoLines = 16    // 사진 없는 첫 페이지
                let contLines = 18       // 이어서 페이지

                let firstText: String
                if hasPhoto {
                    firstText = splitByLines(text, maxLines: photoLines, width: textWidth)
                } else {
                    firstText = splitByLines(text, maxLines: noPhotoLines, width: textWidth)
                }

                if firstText.count >= text.count {
                    entryPages.append(.entryFirst(entry: entry, textSlice: text, pageNum: pageNum))
                    monthToLastPage[monthAge] = pageNum
                    pageNum += 1
                } else {
                    entryPages.append(.entryFirst(entry: entry, textSlice: firstText, pageNum: pageNum))
                    monthToLastPage[monthAge] = pageNum
                    pageNum += 1

                    var remaining = String(text.dropFirst(firstText.count))
                    while !remaining.isEmpty {
                        let chunk = splitByLines(remaining, maxLines: contLines, width: textWidth)
                        entryPages.append(.entryContinuation(entry: entry, textSlice: chunk, pageNum: pageNum))
                        monthToLastPage[monthAge] = pageNum
                        pageNum += 1
                        remaining = String(remaining.dropFirst(chunk.count))
                    }
                }
            }

            // 2단계: 목차 생성
            let tocItems = monthToFirstPage.sorted { $0.key < $1.key }
                .map { (month: $0.key, firstPage: $0.value, lastPage: monthToLastPage[$0.key] ?? $0.value) }
            pages.append(.tableOfContents(items: tocItems))

            // 3단계: 엔트리 페이지 추가
            pages.append(contentsOf: entryPages)
        }

        pages.append(.backCover)
    }

    private func formatMonthAge(_ month: Int) -> String {
        if month == 0 {
            return "신생아"
        } else if month <= 24 {
            return "\(month)개월"
        } else {
            let years = month / 12
            let remainingMonths = month % 12
            if remainingMonths == 0 {
                return "\(years)세"
            } else {
                return "\(years)세 \(remainingMonths)개월"
            }
        }
    }

    private func monthsBetween(from birthDate: Date, to date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.month], from: birthDate, to: date)
        return max(0, comps.month ?? 0)
    }

    private func splitAtWordBoundary(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let endIndex = text.index(text.startIndex, offsetBy: limit)
        let slice = text[text.startIndex..<endIndex]
        if let lastSpace = slice.lastIndex(where: { $0 == " " || $0 == "\n" || $0 == "." || $0 == "," }) {
            return String(text[text.startIndex...lastSpace])
        }
        return String(slice)
    }

    /// 주어진 높이에 몇 줄이 들어가는지 계산
    private func calcMaxLines(height: CGFloat, width: CGFloat) -> Int {
        let font = DS.font(14)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: paragraphStyle]
        let maxSize = CGSize(width: width, height: .greatestFiniteMagnitude)

        let oneLineOnly = NSAttributedString(string: "가", attributes: attrs)
            .boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], context: nil).height
        let twoLineHeight = NSAttributedString(string: "가\n가", attributes: attrs)
            .boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], context: nil).height
        let lineWithSpacing = twoLineHeight - oneLineOnly

        if lineWithSpacing <= 0 { return 1 }
        let lines = Int((height - oneLineOnly) / lineWithSpacing) + 1
        return max(1, lines)
    }

    /// 주어진 너비와 최대 줄 수에 맞는 텍스트를 반환
    private func splitByLines(_ text: String, maxLines: Int, width: CGFloat) -> String {
        guard !text.isEmpty else { return text }

        let font = DS.font(14)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]

        let nsText = text as NSString
        let maxSize = CGSize(width: width, height: .greatestFiniteMagnitude)

        // 정확한 줄 높이 계산 (lineSpacing 포함)
        let twoLineHeight = NSAttributedString(string: "가\n가", attributes: attrs)
            .boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], context: nil).height
        let oneLineOnly = NSAttributedString(string: "가", attributes: attrs)
            .boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], context: nil).height
        let lineWithSpacing = twoLineHeight - oneLineOnly // 한 줄 + lineSpacing
        let maxHeight = oneLineOnly + lineWithSpacing * CGFloat(maxLines - 1)

        // 이진 탐색으로 maxLines에 맞는 글자 수 찾기
        var lo = 0
        var hi = nsText.length
        var result = nsText.length

        while lo <= hi {
            let mid = (lo + hi) / 2
            let sub = nsText.substring(to: mid)
            let attrStr = NSAttributedString(string: sub, attributes: attrs)
            let height = attrStr.boundingRect(with: maxSize, options: [.usesLineFragmentOrigin], context: nil).height

            if height <= maxHeight {
                result = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }

        if result >= nsText.length { return text }

        return nsText.substring(to: result)
    }

    // MARK: - Nav Bar

    private func setupNavBar() {
        let navBar = NavBarView()
        navBar.titleLabel.text = "미니북"

        let exportConfig = UIImage.SymbolConfiguration(pointSize: 16)
        navBar.rightButton.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: exportConfig), for: .normal)
        navBar.rightButton.tintColor = DS.fgMuted
        navBar.rightButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        exportButton.isEnabled = true

        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Period Selector

    private func setupPeriodSelector() {
        periodScrollView.showsHorizontalScrollIndicator = false
        periodScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(periodScrollView)

        periodStack.axis = .horizontal
        periodStack.spacing = 8
        periodStack.translatesAutoresizingMaskIntoConstraints = false
        periodScrollView.addSubview(periodStack)

        NSLayoutConstraint.activate([
            periodScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 58),
            periodScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            periodScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            periodScrollView.heightAnchor.constraint(equalToConstant: 36),

            periodStack.topAnchor.constraint(equalTo: periodScrollView.topAnchor),
            periodStack.leadingAnchor.constraint(equalTo: periodScrollView.leadingAnchor),
            periodStack.trailingAnchor.constraint(equalTo: periodScrollView.trailingAnchor),
            periodStack.bottomAnchor.constraint(equalTo: periodScrollView.bottomAnchor),
            periodStack.heightAnchor.constraint(equalTo: periodScrollView.heightAnchor),
        ])
    }

    // MARK: - Page Container

    private func setupPageContainer() {
        pageContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageContainerView)

        NSLayoutConstraint.activate([
            pageContainerView.topAnchor.constraint(equalTo: periodScrollView.bottomAnchor, constant: 40),
            pageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
        ])
    }

    // MARK: - Navigation Buttons

    private func setupNavButtons() {
        let navRow = UIStackView()
        navRow.axis = .horizontal
        navRow.spacing = 16
        navRow.alignment = .center
        navRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navRow)
        view.bringSubviewToFront(navRow)

        let btnConfig = UIImage.SymbolConfiguration(pointSize: 13)

        for btn in [firstBtn, prevBtn, nextBtn, lastBtn] {
            btn.translatesAutoresizingMaskIntoConstraints = false
            var navBtnConfig = btn.configuration ?? UIButton.Configuration.plain()
            navBtnConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            btn.configuration = navBtnConfig
        }

        firstBtn.setImage(UIImage(systemName: "chevron.backward.2", withConfiguration: btnConfig), for: .normal)
        firstBtn.addTarget(self, action: #selector(goFirst), for: .touchUpInside)

        prevBtn.setImage(UIImage(systemName: "chevron.backward", withConfiguration: btnConfig), for: .normal)
        prevBtn.addTarget(self, action: #selector(goPrev), for: .touchUpInside)

        nextBtn.setImage(UIImage(systemName: "chevron.forward", withConfiguration: btnConfig), for: .normal)
        nextBtn.addTarget(self, action: #selector(goNext), for: .touchUpInside)

        lastBtn.setImage(UIImage(systemName: "chevron.forward.2", withConfiguration: btnConfig), for: .normal)
        lastBtn.addTarget(self, action: #selector(goLast), for: .touchUpInside)

        pageLabel.font = DS.font(11)
        pageLabel.textColor = DS.fgMuted
        pageLabel.textAlignment = .center
        pageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true

        navRow.addArrangedSubview(firstBtn)
        navRow.addArrangedSubview(prevBtn)
        navRow.addArrangedSubview(pageLabel)
        navRow.addArrangedSubview(nextBtn)
        navRow.addArrangedSubview(lastBtn)

        NSLayoutConstraint.activate([
            navRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            navRow.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -45),
        ])
    }

    // MARK: - Swipe Gestures

    private func setupSwipeGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(goNext))
        swipeLeft.direction = .left
        pageContainerView.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(goPrev))
        swipeRight.direction = .right
        pageContainerView.addGestureRecognizer(swipeRight)
    }

    // MARK: - Render Page

    private func renderCurrentPage() {
        pageContainerView.subviews.forEach { $0.removeFromSuperview() }
        guard currentPage < pages.count else { return }

        let pageWidth = view.bounds.width * 0.8
        let pageHeight = pageWidth * 128.0 / 94.0

        let page = pages[currentPage]

        switch page {
        case .cover:
            renderCoverPage(width: pageWidth, height: pageHeight)
        case .tableOfContents(let items):
            renderTocPage(items: items, width: pageWidth, height: pageHeight)
        case .entryFirst(let entry, let text, let num):
            renderEntryFirstPage(entry: entry, textSlice: text, pageNum: num, width: pageWidth, height: pageHeight)
        case .entryContinuation(_, let text, let num):
            renderContinuationPage(textSlice: text, pageNum: num, width: pageWidth, height: pageHeight)
        case .empty:
            renderEmptyPage(width: pageWidth, height: pageHeight)
        case .backCover:
            renderBackCoverPage(width: pageWidth, height: pageHeight)
        }

        updatePageLabel()
        updateNavButtons()
    }

    // MARK: - Table of Contents

    private func renderTocPage(items: [(month: Int, firstPage: Int, lastPage: Int)], width: CGFloat, height: CGFloat) {
        let pageView = makePageView(width: width, height: height)

        let titleLabel = UILabel()
        titleLabel.text = "목차"
        titleLabel.font = DS.font(16)
        titleLabel.textColor = DS.fgStrong
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(titleLabel)

        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(scrollView)

        let tocStack = UIStackView()
        tocStack.axis = .vertical
        tocStack.spacing = 0
        tocStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(tocStack)

        for item in items {
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.isUserInteractionEnabled = true

            let monthLabel = UILabel()
            monthLabel.text = formatMonthAge(item.month)
            monthLabel.font = DS.font(14)
            monthLabel.textColor = DS.fgStrong
            monthLabel.translatesAutoresizingMaskIntoConstraints = false

            let dotLine = UIView()
            dotLine.translatesAutoresizingMaskIntoConstraints = false
            let dotLayer = CAShapeLayer()
            dotLayer.strokeColor = DS.fgPale.cgColor
            dotLayer.lineDashPattern = [2, 3]
            dotLayer.lineWidth = 0.5
            dotLine.layer.addSublayer(dotLayer)

            let pageRangeLabel = UILabel()
            if item.firstPage == item.lastPage {
                pageRangeLabel.text = "\(item.firstPage)"
            } else {
                pageRangeLabel.text = "\(item.firstPage)~\(item.lastPage)"
            }
            pageRangeLabel.font = DS.font(14)
            pageRangeLabel.textColor = DS.fgPale
            pageRangeLabel.textAlignment = .right
            pageRangeLabel.translatesAutoresizingMaskIntoConstraints = false

            row.addSubview(monthLabel)
            row.addSubview(dotLine)
            row.addSubview(pageRangeLabel)

            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: 28),
                monthLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                monthLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

                dotLine.leadingAnchor.constraint(equalTo: monthLabel.trailingAnchor, constant: 6),
                dotLine.trailingAnchor.constraint(equalTo: pageRangeLabel.leadingAnchor, constant: -6),
                dotLine.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                dotLine.heightAnchor.constraint(equalToConstant: 1),

                pageRangeLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                pageRangeLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                pageRangeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
            ])

            DispatchQueue.main.async {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: dotLine.bounds.width, y: 0.5))
                dotLayer.path = path.cgPath
            }

            // 탭하면 해당 페이지로 이동 (겉표지 + 목차 = 2페이지 오프셋)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tocItemTapped(_:)))
            row.tag = item.firstPage + 1 // +1 for 목차 페이지 자체
            row.addGestureRecognizer(tap)

            tocStack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: pageView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: pageView.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor, constant: -16),

            tocStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            tocStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            tocStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            tocStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            tocStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    @objc private func tocItemTapped(_ gesture: UITapGestureRecognizer) {
        guard let row = gesture.view else { return }
        let targetPage = row.tag // 겉표지(0) + 목차(1) + firstPage offset
        if targetPage < pages.count {
            currentPage = targetPage
            renderCurrentPage()
        }
    }

    // MARK: - Page Rendering Helpers

    private func makePageView(width: CGFloat, height: CGFloat) -> UIView {
        let pageView = UIView()
        pageView.backgroundColor = DS.bgBase
        pageView.layer.cornerRadius = 8
        pageView.layer.borderWidth = 0.5
        pageView.layer.borderColor = DS.line.cgColor
        pageView.layer.shadowColor = UIColor.black.cgColor
        pageView.layer.shadowOpacity = 0.15
        pageView.layer.shadowRadius = 8
        pageView.layer.shadowOffset = CGSize(width: 0, height: 4)
        pageView.clipsToBounds = false
        pageView.translatesAutoresizingMaskIntoConstraints = false
        pageContainerView.addSubview(pageView)

        NSLayoutConstraint.activate([
            pageView.centerXAnchor.constraint(equalTo: pageContainerView.centerXAnchor),
            pageView.centerYAnchor.constraint(equalTo: pageContainerView.centerYAnchor, constant: -25),
            pageView.widthAnchor.constraint(equalToConstant: width),
            pageView.heightAnchor.constraint(equalToConstant: height),
        ])
        return pageView
    }

    private func renderCoverPage(width: CGFloat, height: CGFloat) {
        // B7 size label
        let sizeLabel = UILabel()
        sizeLabel.text = "B7  94 x 128 mm"
        sizeLabel.font = DS.font(12)
        sizeLabel.textColor = DS.fgPale
        sizeLabel.textAlignment = .center
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        pageContainerView.addSubview(sizeLabel)

        let pageView = makePageView(width: width, height: height)
        pageView.clipsToBounds = true

        NSLayoutConstraint.activate([
            sizeLabel.bottomAnchor.constraint(equalTo: pageView.topAnchor, constant: -15),
            sizeLabel.centerXAnchor.constraint(equalTo: pageContainerView.centerXAnchor),
        ])

        // Cover photo
        if coverPhotoData == nil {
            pageView.backgroundColor = DS.bgSubtle
        }

        if let data = coverPhotoData, let image = UIImage(data: data) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            pageView.addSubview(imageView)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: pageView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),
            ])

            // Gradient overlay
            let gradientView = GradientView()
            gradientView.translatesAutoresizingMaskIntoConstraints = false
            pageView.addSubview(gradientView)
            NSLayoutConstraint.activate([
                gradientView.topAnchor.constraint(equalTo: pageView.topAnchor),
                gradientView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor),
                gradientView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor),
                gradientView.bottomAnchor.constraint(equalTo: pageView.bottomAnchor),
            ])
        }

        // Baby name title
        let baby = CoreDataStack.shared.fetchBaby()
        let titleLabel = UILabel()
        titleLabel.text = "\(baby?.name ?? "")의 일기"
        titleLabel.font = DS.font(16)
        titleLabel.textColor = DS.fgStrong
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(titleLabel)
        pageView.bringSubviewToFront(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: pageView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: pageView.bottomAnchor, constant: -30),
        ])

        // Change cover buttons
        let buttonsRow = UIStackView()
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 8
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(buttonsRow)

        let photoBtn = makeCircleIconButton(systemName: "photo.on.rectangle")
        photoBtn.addTarget(self, action: #selector(changeCoverTapped), for: .touchUpInside)
        buttonsRow.addArrangedSubview(photoBtn)

        NSLayoutConstraint.activate([
            buttonsRow.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -12),
            buttonsRow.bottomAnchor.constraint(equalTo: pageView.bottomAnchor, constant: -12),
        ])
    }

    private func makeCircleIconButton(systemName: String) -> UIButton {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14)
        btn.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        btn.tintColor = DS.fgMuted
        btn.backgroundColor = DS.bgBase.withAlphaComponent(0.8)
        btn.layer.cornerRadius = 16
        btn.layer.borderWidth = 0.5
        btn.layer.borderColor = DS.line.cgColor
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 32),
            btn.heightAnchor.constraint(equalToConstant: 32),
        ])
        return btn
    }

    private func renderEntryFirstPage(entry: CDDiaryEntry, textSlice: String, pageNum: Int, width: CGFloat, height: CGFloat) {
        let pageView = makePageView(width: width, height: height)
        pageView.clipsToBounds = true

        var topAnchor = pageView.topAnchor
        var topConstant: CGFloat = 16

        // Photo
        if let data = entry.photoData, let image = UIImage(data: data) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 4
            imageView.translatesAutoresizingMaskIntoConstraints = false
            pageView.addSubview(imageView)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: pageView.topAnchor, constant: 20),
                imageView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
                imageView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),
                imageView.heightAnchor.constraint(equalToConstant: width * 0.65),
            ])
            topAnchor = imageView.bottomAnchor
            topConstant = 14
        }

        // Date + D+ row
        let baby = CoreDataStack.shared.fetchBaby()
        let dateBadge = DateBadgeView(text: entry.formattedDate)
        dateBadge.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(dateBadge)

        let dayCountLabel = UILabel()
        dayCountLabel.text = baby?.dayAndMonthAt(date: entry.date) ?? ""
        dayCountLabel.font = DS.font(11)
        dayCountLabel.textColor = DS.fgPale
        dayCountLabel.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(dayCountLabel)

        NSLayoutConstraint.activate([
            dateBadge.topAnchor.constraint(equalTo: topAnchor, constant: topConstant),
            dateBadge.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
            dayCountLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),
            dayCountLabel.centerYAnchor.constraint(equalTo: dateBadge.centerYAnchor),
        ])

        // Text
        if !textSlice.isEmpty {
            let textLabel = UILabel()
            textLabel.font = DS.font(14)
            textLabel.textColor = DS.fgStrong
            textLabel.numberOfLines = 0
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            textLabel.attributedText = NSAttributedString(string: textSlice, attributes: [
                .font: DS.font(14),
                .foregroundColor: DS.fgStrong,
                .paragraphStyle: paragraphStyle,
            ])
            textLabel.translatesAutoresizingMaskIntoConstraints = false
            pageView.addSubview(textLabel)

            NSLayoutConstraint.activate([
                textLabel.topAnchor.constraint(equalTo: dateBadge.bottomAnchor, constant: 14),
                textLabel.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
                textLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),
            ])
        }

        // Page number
        let pageNumLabel = UILabel()
        pageNumLabel.text = "\(pageNum)"
        pageNumLabel.font = DS.font(9)
        pageNumLabel.textColor = DS.fgPale
        pageNumLabel.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(pageNumLabel)

        NSLayoutConstraint.activate([
            pageNumLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),
            pageNumLabel.bottomAnchor.constraint(equalTo: pageView.bottomAnchor, constant: -8),
        ])
    }

    private func renderContinuationPage(textSlice: String, pageNum: Int, width: CGFloat, height: CGFloat) {
        let pageView = makePageView(width: width, height: height)
        pageView.clipsToBounds = true

        let textLabel = UILabel()
        textLabel.font = DS.font(14)
        textLabel.textColor = DS.fgStrong
        textLabel.numberOfLines = 0
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        textLabel.attributedText = NSAttributedString(string: textSlice, attributes: [
            .font: DS.font(14),
            .foregroundColor: DS.fgStrong,
            .paragraphStyle: paragraphStyle,
        ])
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(textLabel)

        let pageNumLabel = UILabel()
        pageNumLabel.text = "\(pageNum)"
        pageNumLabel.font = DS.font(9)
        pageNumLabel.textColor = DS.fgPale
        pageNumLabel.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(pageNumLabel)

        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: pageView.topAnchor, constant: 20),
            textLabel.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
            textLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),

            pageNumLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20),
            pageNumLabel.bottomAnchor.constraint(equalTo: pageView.bottomAnchor, constant: -8),
        ])
    }

    private func renderEmptyPage(width: CGFloat, height: CGFloat) {
        let pageView = makePageView(width: width, height: height)

        let messageStack = UIStackView()
        messageStack.axis = .vertical
        messageStack.spacing = 8
        messageStack.alignment = .center
        messageStack.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(messageStack)

        let line1 = UILabel()
        line1.text = "아직 기록이 없어요."
        line1.font = DS.font(13)
        line1.textColor = DS.fgPale
        messageStack.addArrangedSubview(line1)

        let line2 = UILabel()
        line2.text = "오늘부터 시작해보세요!"
        line2.font = DS.font(13)
        line2.textColor = DS.fgPale
        messageStack.addArrangedSubview(line2)

        NSLayoutConstraint.activate([
            messageStack.centerXAnchor.constraint(equalTo: pageView.centerXAnchor),
            messageStack.centerYAnchor.constraint(equalTo: pageView.centerYAnchor),
        ])
    }

    private func renderBackCoverPage(width: CGFloat, height: CGFloat) {
        let pageView = makePageView(width: width, height: height)
        let baby = CoreDataStack.shared.fetchBaby()

        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 10
        vStack.alignment = .center
        vStack.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(vStack)

        // Baby photo
        if let data = baby?.photoData, let image = UIImage(data: data) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 30
            imageView.layer.borderWidth = 1
            imageView.layer.borderColor = DS.line.cgColor
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 60),
                imageView.heightAnchor.constraint(equalToConstant: 60),
            ])
            vStack.addArrangedSubview(imageView)
        }

        let titleLabel = UILabel()
        titleLabel.text = "\(baby?.name ?? "")의 일기"
        titleLabel.font = DS.font(13)
        titleLabel.textColor = DS.fgMuted
        vStack.addArrangedSubview(titleLabel)

        let innerPages = pages.count - 3 // 겉표지, 목차, 뒷표지 제외
        if innerPages > 0 {
            let countLabel = UILabel()
            countLabel.text = "총 \(innerPages)쪽"
            countLabel.font = DS.font(11)
            countLabel.textColor = DS.fgPale
            vStack.addArrangedSubview(countLabel)
        }

        NSLayoutConstraint.activate([
            vStack.centerXAnchor.constraint(equalTo: pageView.centerXAnchor),
            vStack.centerYAnchor.constraint(equalTo: pageView.centerYAnchor, constant: 10),
        ])
    }

    // MARK: - Page Label & Nav

    private func updatePageLabel() {
        if currentPage == 0 {
            pageLabel.text = "겉표지"
        } else if currentPage == pages.count - 1 {
            pageLabel.text = "뒷표지"
        } else if case .tableOfContents = pages[currentPage] {
            pageLabel.text = "목차"
        } else {
            let totalInner = pages.count - 3 // 겉표지, 목차, 뒷표지 제외
            let innerPage = currentPage - 2 // 겉표지, 목차 이후
            pageLabel.text = "\(max(1, innerPage)) / \(max(1, totalInner))"
        }
    }

    private func updateNavButtons() {
        let atStart = currentPage == 0
        let atEnd = currentPage >= pages.count - 1

        firstBtn.tintColor = atStart ? DS.fgPale : DS.fgMuted
        firstBtn.isEnabled = !atStart
        prevBtn.tintColor = atStart ? DS.fgPale : DS.fgMuted
        prevBtn.isEnabled = !atStart
        nextBtn.tintColor = atEnd ? DS.fgPale : DS.fgMuted
        nextBtn.isEnabled = !atEnd
        lastBtn.tintColor = atEnd ? DS.fgPale : DS.fgMuted
        lastBtn.isEnabled = !atEnd
    }

    // MARK: - Actions

    @objc private func goFirst() {
        guard currentPage > 0 else { return }
        currentPage = 0
        renderCurrentPage()
    }

    @objc private func goPrev() {
        guard currentPage > 0 else { return }
        currentPage -= 1
        renderCurrentPage()
    }

    @objc private func goNext() {
        guard currentPage < pages.count - 1 else { return }
        currentPage += 1
        renderCurrentPage()
    }

    @objc private func goLast() {
        guard currentPage < pages.count - 1 else { return }
        currentPage = pages.count - 1
        renderCurrentPage()
    }

    @objc private func changeCoverTapped() {
        let picker = CustomPhotoPickerViewController()
        picker.delegate = self
        picker.cropAspectRatio = 94.0 / 128.0
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true)
    }

    @objc private func exportTapped() {
        guard !isExporting else { return }

        let hasContent = entries.contains { !$0.text.isEmpty || $0.photoData != nil }
        if !hasContent {
            let alert = CustomAlertView(title: "내보낼 기록이 없어요", message: "일기를 작성하면 미니북을 내보낼 수 있어요.", buttonText: "확인")
            alert.show(in: view)
            return
        }

        exportPDF()
    }

    // MARK: - PDF Export

    private func exportPDF() {
        isExporting = true
        showExportOverlay()

        let baby = CoreDataStack.shared.fetchBaby()
        let babyName = baby?.name ?? "아기"
        let allPages = pages

        // 미리보기와 동일한 크기로 렌더링 → 고해상도 비트맵 → PDF
        let renderW = UIScreen.main.bounds.width * 0.8
        let renderH = renderW * 128.0 / 94.0
        let renderSize = CGSize(width: renderW, height: renderH)
        let pdfW: CGFloat = 94 * 4
        let pdfH: CGFloat = 128 * 4
        let pageRect = CGRect(x: 0, y: 0, width: pdfW, height: pdfH)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            let data = renderer.pdfData { context in
                for page in allPages {
                    context.beginPage()
                    // 미리보기 크기로 4x 해상도 렌더링 (레이아웃 완벽 일치)
                    if let image = self.renderPageToImage(page: page, size: renderSize, renderScale: 4.0) {
                        image.draw(in: pageRect)
                    }
                }
            }

            let fileName = "\(babyName)의 일기.pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try? data.write(to: url)

            DispatchQueue.main.async {
                self.isExporting = false
                self.hideExportOverlay()

                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                self.present(activityVC, animated: true)
            }
        }
    }

    /// PDF 컨텍스트에 직접 벡터로 그리기 (텍스트/뱃지 선명)
    private func drawPageDirectly(page: PageContent, size: CGSize, context: CGContext) {
        let rect = CGRect(origin: .zero, size: size)

        // Background
        context.setFillColor(DS.bgBase.cgColor)
        context.fill(rect)

        let baby = CoreDataStack.shared.fetchBaby()
        let margin: CGFloat = size.width * 20.0 / (UIScreen.main.bounds.width * 0.8)
        let textRect = rect.insetBy(dx: margin, dy: margin)

        // 미리보기 대비 스케일 계산 (폰트 크기 등에 적용)
        let previewW = UIScreen.main.bounds.width * 0.8
        let scale = size.width / previewW

        switch page {
        case .cover:
            if let data = coverPhotoData, let image = UIImage(data: data) {
                // aspectFill 크롭 이미지 생성
                let filledImage = Self.aspectFillImage(image, targetSize: size)
                filledImage.draw(in: rect)
                // 하단 그라디언트
                let gradientColors = [UIColor.clear.cgColor, UIColor(hex: "FFFBF0").withAlphaComponent(0.6).cgColor]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors as CFArray, locations: [0.0, 1.0])!
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height * 0.5), end: CGPoint(x: 0, y: size.height), options: [])
            } else {
                context.setFillColor(DS.bgSubtle.cgColor)
                context.fill(rect)
            }
            let title = "\(baby?.name ?? "")의 일기"
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(16 * scale),
                .foregroundColor: DS.fgStrong,
            ]
            let titleSize = (title as NSString).size(withAttributes: titleAttrs)
            let titlePoint = CGPoint(x: (size.width - titleSize.width) / 2, y: size.height - 30 * scale)
            (title as NSString).draw(at: titlePoint, withAttributes: titleAttrs)

        case .tableOfContents(let items):
            let tocTitle = "목차"
            let tocTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(16 * scale),
                .foregroundColor: DS.fgStrong,
            ]
            let tocTitleSize = (tocTitle as NSString).size(withAttributes: tocTitleAttrs)
            (tocTitle as NSString).draw(at: CGPoint(x: (size.width - tocTitleSize.width) / 2, y: margin + 4 * scale), withAttributes: tocTitleAttrs)

            var tocY: CGFloat = margin + tocTitleSize.height + 16 * scale
            let itemAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(14 * scale),
                .foregroundColor: DS.fgStrong,
            ]
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(14 * scale),
                .foregroundColor: DS.fgPale,
            ]
            for item in items {
                let label = formatMonthAge(item.month)
                let labelSize = (label as NSString).size(withAttributes: itemAttrs)
                (label as NSString).draw(at: CGPoint(x: margin + 4 * scale, y: tocY), withAttributes: itemAttrs)

                let numStr = item.firstPage == item.lastPage ? "\(item.firstPage)" : "\(item.firstPage)~\(item.lastPage)"
                let numSize = (numStr as NSString).size(withAttributes: numAttrs)
                (numStr as NSString).draw(at: CGPoint(x: size.width - margin - 4 * scale - numSize.width, y: tocY + 2 * scale), withAttributes: numAttrs)

                let dotStartX = margin + 4 * scale + labelSize.width + 4 * scale
                let dotEndX = size.width - margin - 4 * scale - numSize.width - 4 * scale
                let dotY = tocY + labelSize.height / 2
                if dotEndX > dotStartX {
                    context.saveGState()
                    context.setStrokeColor(DS.fgPale.cgColor)
                    context.setLineWidth(0.5 * scale)
                    context.setLineDash(phase: 0, lengths: [2 * scale, 3 * scale])
                    context.move(to: CGPoint(x: dotStartX, y: dotY))
                    context.addLine(to: CGPoint(x: dotEndX, y: dotY))
                    context.strokePath()
                    context.restoreGState()
                }

                tocY += 22 * scale
            }

        case .entryFirst(let entry, let textSlice, let num):
            var yOffset: CGFloat = margin

            if let data = entry.photoData, let image = UIImage(data: data) {
                let photoHeight = (size.width - margin * 2) * 0.65
                let photoRect = CGRect(x: margin, y: yOffset, width: size.width - margin * 2, height: photoHeight)
                image.draw(in: photoRect)
                yOffset += photoHeight + 10 * scale
            }

            // 날짜 뱃지
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(11 * scale),
                .foregroundColor: DS.fgNeutral,
            ]
            let dateText = entry.formattedDate
            let dateSize = (dateText as NSString).size(withAttributes: dateAttrs)
            let badgePadH: CGFloat = 10 * scale
            let badgePadV: CGFloat = 4 * scale
            let badgeRect = CGRect(x: margin, y: yOffset, width: dateSize.width + badgePadH * 2, height: dateSize.height + badgePadV * 2)
            let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 4 * scale)
            context.saveGState()
            DS.yellow.setFill()
            badgePath.fill()
            DS.yellowBorder.setStroke()
            badgePath.lineWidth = 0.5 * scale
            badgePath.stroke()
            context.restoreGState()
            (dateText as NSString).draw(at: CGPoint(x: margin + badgePadH, y: yOffset + badgePadV), withAttributes: dateAttrs)

            let dText = baby?.dayAndMonthAt(date: entry.date) ?? ""
            let dAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(11 * scale),
                .foregroundColor: DS.fgPale,
            ]
            let dSize = (dText as NSString).size(withAttributes: dAttrs)
            (dText as NSString).draw(at: CGPoint(x: size.width - margin - dSize.width, y: yOffset + badgePadV), withAttributes: dAttrs)
            yOffset += badgeRect.height + 10 * scale

            if !textSlice.isEmpty {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 6 * scale
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(14 * scale),
                    .foregroundColor: DS.fgStrong,
                    .paragraphStyle: paragraphStyle,
                ]
                let textDrawRect = CGRect(x: margin, y: yOffset, width: textRect.width, height: size.height - yOffset - 20 * scale)
                (textSlice as NSString).draw(in: textDrawRect, withAttributes: textAttrs)
            }

            let pnAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(11 * scale),
                .foregroundColor: DS.fgPale,
            ]
            let numText = "\(num)"
            let numSize = (numText as NSString).size(withAttributes: pnAttrs)
            (numText as NSString).draw(at: CGPoint(x: size.width - margin - numSize.width, y: size.height - margin), withAttributes: pnAttrs)

        case .entryContinuation(_, let textSlice, let num):
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6 * scale
            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(14 * scale),
                .foregroundColor: DS.fgStrong,
                .paragraphStyle: paragraphStyle,
            ]
            let textDrawRect = CGRect(x: margin, y: margin, width: textRect.width, height: size.height - margin * 2 - 30 * scale)
            (textSlice as NSString).draw(in: textDrawRect, withAttributes: textAttrs)

            let pnAttrs2: [NSAttributedString.Key: Any] = [
                .font: DS.font(11 * scale),
                .foregroundColor: DS.fgPale,
            ]
            let numText = "\(num)"
            let numSize = (numText as NSString).size(withAttributes: pnAttrs2)
            (numText as NSString).draw(at: CGPoint(x: size.width - margin - numSize.width, y: size.height - margin), withAttributes: pnAttrs2)

        case .empty:
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(13 * scale),
                .foregroundColor: DS.fgPale,
            ]
            let text1 = "아직 기록이 없어요."
            let text2 = "오늘부터 시작해보세요!"
            let text1Size = (text1 as NSString).size(withAttributes: emptyAttrs)
            let text2Size = (text2 as NSString).size(withAttributes: emptyAttrs)
            (text1 as NSString).draw(at: CGPoint(x: (size.width - text1Size.width) / 2, y: size.height / 2 - 15 * scale), withAttributes: emptyAttrs)
            (text2 as NSString).draw(at: CGPoint(x: (size.width - text2Size.width) / 2, y: size.height / 2 + 10 * scale), withAttributes: emptyAttrs)

        case .backCover:
            if let data = baby?.photoData, let image = UIImage(data: data) {
                let photoSize: CGFloat = 60 * scale
                let photoRect = CGRect(x: (size.width - photoSize) / 2, y: size.height / 2 - 50 * scale, width: photoSize, height: photoSize)
                context.saveGState()
                let path = UIBezierPath(roundedRect: photoRect, cornerRadius: photoSize / 2)
                path.addClip()
                image.draw(in: photoRect)
                context.restoreGState()
            }
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: DS.font(13 * scale),
                .foregroundColor: DS.fgMuted,
            ]
            let title = "\(baby?.name ?? "")의 일기"
            let titleSize = (title as NSString).size(withAttributes: titleAttrs)
            (title as NSString).draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: size.height / 2 + 30 * scale), withAttributes: titleAttrs)

            let innerPages = pages.count - 3
            if innerPages > 0 {
                let countAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(11 * scale),
                    .foregroundColor: DS.fgPale,
                ]
                let countText = "총 \(innerPages)쪽"
                let countSize = (countText as NSString).size(withAttributes: countAttrs)
                (countText as NSString).draw(at: CGPoint(x: (size.width - countSize.width) / 2, y: size.height / 2 + 50 * scale), withAttributes: countAttrs)
            }
        }
    }

    private func renderPageToImage(page: PageContent, size: CGSize, renderScale: CGFloat = 0) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        if renderScale > 0 { format.scale = renderScale }
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let context = ctx.cgContext

            // Background
            context.setFillColor(DS.bgBase.cgColor)
            context.fill(rect)

            let baby = CoreDataStack.shared.fetchBaby()
            let margin: CGFloat = 20
            let textRect = rect.insetBy(dx: margin, dy: margin)

            switch page {
            case .cover:
                if let data = coverPhotoData, let image = UIImage(data: data) {
                    image.draw(in: rect)
                    // 하단 그라디언트
                    let gradientColors = [UIColor.clear.cgColor, UIColor(hex: "FFFBF0").withAlphaComponent(0.6).cgColor]
                    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors as CFArray, locations: [0.0, 1.0])!
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height * 0.5), end: CGPoint(x: 0, y: size.height), options: [])
                } else {
                    context.setFillColor(DS.bgSubtle.cgColor)
                    context.fill(rect)
                }
                let title = "\(baby?.name ?? "")의 일기"
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(16),
                    .foregroundColor: DS.fgStrong,
                ]
                let titleSize = (title as NSString).size(withAttributes: titleAttrs)
                let titlePoint = CGPoint(x: (size.width - titleSize.width) / 2, y: size.height - 30)
                (title as NSString).draw(at: titlePoint, withAttributes: titleAttrs)

            case .tableOfContents(let items):
                let tocTitle = "목차"
                let tocTitleAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(16),
                    .foregroundColor: DS.fgStrong,
                ]
                let tocTitleSize = (tocTitle as NSString).size(withAttributes: tocTitleAttrs)
                (tocTitle as NSString).draw(at: CGPoint(x: (size.width - tocTitleSize.width) / 2, y: margin + 4), withAttributes: tocTitleAttrs)

                var tocY: CGFloat = margin + tocTitleSize.height + 16
                let itemAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(14),
                    .foregroundColor: DS.fgStrong,
                ]
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(14),
                    .foregroundColor: DS.fgPale,
                ]
                for item in items {
                    let label = formatMonthAge(item.month)
                    let labelSize = (label as NSString).size(withAttributes: itemAttrs)
                    (label as NSString).draw(at: CGPoint(x: margin + 4, y: tocY), withAttributes: itemAttrs)

                    let numStr = item.firstPage == item.lastPage ? "\(item.firstPage)" : "\(item.firstPage)~\(item.lastPage)"
                    let numSize = (numStr as NSString).size(withAttributes: numAttrs)
                    (numStr as NSString).draw(at: CGPoint(x: size.width - margin - 4 - numSize.width, y: tocY + 2), withAttributes: numAttrs)

                    // 점선
                    let dotStartX = margin + 4 + labelSize.width + 4
                    let dotEndX = size.width - margin - 4 - numSize.width - 4
                    let dotY = tocY + labelSize.height / 2
                    if dotEndX > dotStartX {
                        context.saveGState()
                        context.setStrokeColor(DS.fgPale.cgColor)
                        context.setLineWidth(0.5)
                        context.setLineDash(phase: 0, lengths: [2, 3])
                        context.move(to: CGPoint(x: dotStartX, y: dotY))
                        context.addLine(to: CGPoint(x: dotEndX, y: dotY))
                        context.strokePath()
                        context.restoreGState()
                    }

                    tocY += 22
                }

            case .entryFirst(let entry, let textSlice, let num):
                var yOffset: CGFloat = margin

                if let data = entry.photoData, let image = UIImage(data: data) {
                    let photoHeight = (size.width - margin * 2) * 0.65
                    let photoRect = CGRect(x: margin, y: yOffset, width: size.width - margin * 2, height: photoHeight)
                    image.draw(in: photoRect)
                    yOffset += photoHeight + 10
                }

                // 날짜 뱃지 (배경 포함)
                let dateAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(11),
                    .foregroundColor: DS.fgNeutral,
                ]
                let dateText = entry.formattedDate
                let dateSize = (dateText as NSString).size(withAttributes: dateAttrs)
                let badgePadH: CGFloat = 10
                let badgePadV: CGFloat = 4
                let badgeRect = CGRect(x: margin, y: yOffset, width: dateSize.width + badgePadH * 2, height: dateSize.height + badgePadV * 2)
                let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 4)
                context.saveGState()
                DS.yellow.setFill()
                badgePath.fill()
                DS.yellowBorder.setStroke()
                badgePath.lineWidth = 0.5
                badgePath.stroke()
                context.restoreGState()
                (dateText as NSString).draw(at: CGPoint(x: margin + badgePadH, y: yOffset + badgePadV), withAttributes: dateAttrs)

                let dText = baby?.dayAndMonthAt(date: entry.date) ?? ""
                let dAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(11),
                    .foregroundColor: DS.fgPale,
                ]
                let dSize = (dText as NSString).size(withAttributes: dAttrs)
                (dText as NSString).draw(at: CGPoint(x: size.width - margin - dSize.width, y: yOffset + badgePadV), withAttributes: dAttrs)
                yOffset += badgeRect.height + 10

                if !textSlice.isEmpty {
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.lineSpacing = 6
                    let textAttrs: [NSAttributedString.Key: Any] = [
                        .font: DS.font(14),
                        .foregroundColor: DS.fgStrong,
                        .paragraphStyle: paragraphStyle,
                    ]
                    let textDrawRect = CGRect(x: margin, y: yOffset, width: textRect.width, height: size.height - yOffset - 20)
                    (textSlice as NSString).draw(in: textDrawRect, withAttributes: textAttrs)
                }

                let pnAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(11),
                    .foregroundColor: DS.fgPale,
                ]
                let numText = "\(num)"
                let numSize = (numText as NSString).size(withAttributes: pnAttrs)
                (numText as NSString).draw(at: CGPoint(x: size.width - margin - numSize.width, y: size.height - margin), withAttributes: pnAttrs)

            case .entryContinuation(_, let textSlice, let num):
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 6
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(14),
                    .foregroundColor: DS.fgStrong,
                    .paragraphStyle: paragraphStyle,
                ]
                let textDrawRect = CGRect(x: margin, y: margin, width: textRect.width, height: size.height - margin * 2 - 30)
                (textSlice as NSString).draw(in: textDrawRect, withAttributes: textAttrs)

                let pnAttrs2: [NSAttributedString.Key: Any] = [
                    .font: DS.font(11),
                    .foregroundColor: DS.fgPale,
                ]
                let numText = "\(num)"
                let numSize = (numText as NSString).size(withAttributes: pnAttrs2)
                (numText as NSString).draw(at: CGPoint(x: size.width - margin - numSize.width, y: size.height - margin), withAttributes: pnAttrs2)

            case .empty:
                let emptyAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(13),
                    .foregroundColor: DS.fgPale,
                ]
                let text1 = "아직 기록이 없어요."
                let text2 = "오늘부터 시작해보세요!"
                let text1Size = (text1 as NSString).size(withAttributes: emptyAttrs)
                let text2Size = (text2 as NSString).size(withAttributes: emptyAttrs)
                (text1 as NSString).draw(at: CGPoint(x: (size.width - text1Size.width) / 2, y: size.height / 2 - 15), withAttributes: emptyAttrs)
                (text2 as NSString).draw(at: CGPoint(x: (size.width - text2Size.width) / 2, y: size.height / 2 + 10), withAttributes: emptyAttrs)

            case .backCover:
                if let data = baby?.photoData, let image = UIImage(data: data) {
                    let photoSize: CGFloat = 60
                    let photoRect = CGRect(x: (size.width - photoSize) / 2, y: size.height / 2 - 50, width: photoSize, height: photoSize)
                    context.saveGState()
                    let path = UIBezierPath(roundedRect: photoRect, cornerRadius: photoSize / 2)
                    path.addClip()
                    image.draw(in: photoRect)
                    context.restoreGState()
                }
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(13),
                    .foregroundColor: DS.fgMuted,
                ]
                let title = "\(baby?.name ?? "")의 일기"
                let titleSize = (title as NSString).size(withAttributes: titleAttrs)
                (title as NSString).draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: size.height / 2 + 30), withAttributes: titleAttrs)

                let innerPages = pages.count - 3
                if innerPages > 0 {
                    let countAttrs: [NSAttributedString.Key: Any] = [
                        .font: DS.font(11),
                        .foregroundColor: DS.fgPale,
                    ]
                    let countText = "총 \(innerPages)쪽"
                    let countSize = (countText as NSString).size(withAttributes: countAttrs)
                    (countText as NSString).draw(at: CGPoint(x: (size.width - countSize.width) / 2, y: size.height / 2 + 50), withAttributes: countAttrs)
                }
            }
        }
    }

    private static func aspectFillImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let imgSize = image.size
        let widthRatio = targetSize.width / imgSize.width
        let heightRatio = targetSize.height / imgSize.height
        let fillScale = max(widthRatio, heightRatio)
        let drawSize = CGSize(width: imgSize.width * fillScale, height: imgSize.height * fillScale)
        let origin = CGPoint(x: (targetSize.width - drawSize.width) / 2, y: (targetSize.height - drawSize.height) / 2)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    private func showExportOverlay() {
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.2)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = DS.fgMuted
        spinner.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(spinner)
        spinner.startAnimating()

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])

        view.addSubview(overlay)
        exportOverlay = overlay
    }

    private func hideExportOverlay() {
        exportOverlay?.removeFromSuperview()
        exportOverlay = nil
    }
}

// MARK: - CustomPhotoPickerDelegate

extension MinibookViewController: CustomPhotoPickerDelegate {
    func photoPicker(_ picker: CustomPhotoPickerViewController, didSelect image: UIImage) {
        // orientation 정규화 후 저장
        let normalized = Self.normalizeOrientation(image)
        let data = normalized.jpegData(compressionQuality: 0.8)
        coverPhotoData = data
        if let baby = CoreDataStack.shared.fetchBaby() {
            baby.coverPhotoData = data
            CoreDataStack.shared.save()
        }
        renderCurrentPage()
    }

    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(at: .zero)
        }
    }
}

// MARK: - Gradient View

private class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        guard let gradient = layer as? CAGradientLayer else { return }
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor(hex: "FFFBF0").withAlphaComponent(0.6).cgColor,
        ]
        gradient.locations = [0.5, 1.0]
    }

    required init?(coder: NSCoder) { fatalError() }
}
