import UIKit
import PhotosUI

class MinibookViewController: UIViewController {

    // MARK: - Page Model

    private enum PageContent {
        case cover
        case entryFirst(entry: CDDiaryEntry, textSlice: String, pageNum: Int)
        case entryContinuation(entry: CDDiaryEntry, textSlice: String, pageNum: Int)
        case empty
        case backCover
    }

    // MARK: - Properties

    private var entries: [CDDiaryEntry] = []
    private var pages: [PageContent] = []
    private var currentPage = 0
    private var coverPhotoData: Data?
    private var isExporting = false

    private let coverKey = "minibook_cover_photo"
    private let firstPageWithPhotoChars = 350
    private let firstPageNoPhotoChars = 600
    private let continuationChars = 650

    // UI
    private let pageContainerView = UIView()
    private let pageLabel = UILabel()
    private let firstBtn = UIButton(type: .system)
    private let prevBtn = UIButton(type: .system)
    private let nextBtn = UIButton(type: .system)
    private let lastBtn = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private var exportOverlay: UIView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupNavBar()
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
        entries = CoreDataStack.shared.fetchEntries(sortAscending: true)
        coverPhotoData = UserDefaults.standard.data(forKey: coverKey)
        buildPages()
        currentPage = min(currentPage, max(pages.count - 1, 0))
        renderCurrentPage()
        updateNavButtons()
    }

    private func buildPages() {
        pages = [.cover]

        if entries.isEmpty {
            pages.append(.empty)
        } else {
            var pageNum = 1
            for entry in entries {
                guard !entry.text.isEmpty || entry.photoData != nil else { continue }
                let text = entry.text
                let hasPhoto = entry.photoData != nil
                let maxFirst = hasPhoto ? firstPageWithPhotoChars : firstPageNoPhotoChars

                if text.count <= maxFirst {
                    pages.append(.entryFirst(entry: entry, textSlice: text, pageNum: pageNum))
                    pageNum += 1
                } else {
                    let firstText = splitAtWordBoundary(text, limit: maxFirst)
                    pages.append(.entryFirst(entry: entry, textSlice: firstText, pageNum: pageNum))
                    pageNum += 1

                    var remaining = String(text.dropFirst(firstText.count))
                    while !remaining.isEmpty {
                        let chunk = splitAtWordBoundary(remaining, limit: continuationChars)
                        pages.append(.entryContinuation(entry: entry, textSlice: chunk, pageNum: pageNum))
                        pageNum += 1
                        remaining = String(remaining.dropFirst(chunk.count))
                    }
                }
            }
        }

        pages.append(.backCover)
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

    // MARK: - Page Container

    private func setupPageContainer() {
        pageContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageContainerView)

        NSLayoutConstraint.activate([
            pageContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            pageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
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

        let btnConfig = UIImage.SymbolConfiguration(pointSize: 13)

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
            navRow.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
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

    // MARK: - Page Rendering Helpers

    private func makePageView(width: CGFloat, height: CGFloat) -> UIView {
        let pageView = UIView()
        pageView.backgroundColor = DS.bgBase
        pageView.layer.cornerRadius = 8
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
        sizeLabel.font = DS.font(13)
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
        titleLabel.font = DS.font(18)
        titleLabel.textColor = DS.fgStrong
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(titleLabel)

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

        if coverPhotoData != nil {
            let cropBtn = makeCircleIconButton(systemName: "crop")
            cropBtn.addTarget(self, action: #selector(cropCoverTapped), for: .touchUpInside)
            buttonsRow.addArrangedSubview(cropBtn)
        }

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
                imageView.topAnchor.constraint(equalTo: pageView.topAnchor, constant: 16),
                imageView.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 16),
                imageView.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -16),
                imageView.heightAnchor.constraint(equalToConstant: width * 0.56),
            ])
            topAnchor = imageView.bottomAnchor
            topConstant = 10
        }

        // Date + D+ row
        let baby = CoreDataStack.shared.fetchBaby()
        let dateBadge = DateBadgeView(text: entry.formattedDate)
        dateBadge.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(dateBadge)

        let dayCountLabel = UILabel()
        dayCountLabel.text = "D+\(baby?.dayCountAt(date: entry.date) ?? 0)"
        dayCountLabel.font = DS.font(9)
        dayCountLabel.textColor = DS.fgPale
        dayCountLabel.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(dayCountLabel)

        NSLayoutConstraint.activate([
            dateBadge.topAnchor.constraint(equalTo: topAnchor, constant: topConstant),
            dateBadge.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 16),
            dayCountLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -16),
            dayCountLabel.centerYAnchor.constraint(equalTo: dateBadge.centerYAnchor),
        ])

        // Text
        if !textSlice.isEmpty {
            let textLabel = UILabel()
            textLabel.font = DS.font(11)
            textLabel.textColor = DS.fgStrong
            textLabel.numberOfLines = 0
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            textLabel.attributedText = NSAttributedString(string: textSlice, attributes: [
                .font: DS.font(11),
                .foregroundColor: DS.fgStrong,
                .paragraphStyle: paragraphStyle,
            ])
            textLabel.translatesAutoresizingMaskIntoConstraints = false
            pageView.addSubview(textLabel)

            NSLayoutConstraint.activate([
                textLabel.topAnchor.constraint(equalTo: dateBadge.bottomAnchor, constant: 10),
                textLabel.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 16),
                textLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -16),
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
            pageNumLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -16),
            pageNumLabel.bottomAnchor.constraint(equalTo: pageView.bottomAnchor, constant: -8),
        ])
    }

    private func renderContinuationPage(textSlice: String, pageNum: Int, width: CGFloat, height: CGFloat) {
        let pageView = makePageView(width: width, height: height)
        pageView.clipsToBounds = true

        let textLabel = UILabel()
        textLabel.font = DS.font(11)
        textLabel.textColor = DS.fgStrong
        textLabel.numberOfLines = 0
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        textLabel.attributedText = NSAttributedString(string: textSlice, attributes: [
            .font: DS.font(11),
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
            textLabel.topAnchor.constraint(equalTo: pageView.topAnchor, constant: 16),
            textLabel.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -16),

            pageNumLabel.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -16),
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
        line1.font = DS.font(14)
        line1.textColor = DS.fgPale
        messageStack.addArrangedSubview(line1)

        let line2 = UILabel()
        line2.text = "오늘부터 시작해보세요!"
        line2.font = DS.font(14)
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
        titleLabel.font = DS.font(14)
        titleLabel.textColor = DS.fgMuted
        vStack.addArrangedSubview(titleLabel)

        let innerPages = pages.count - 2
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
        } else {
            let totalInner = pages.count - 2
            pageLabel.text = "\(currentPage) / \(totalInner)"
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
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func cropCoverTapped() {
        // Crop placeholder - could present a crop VC
        // For now, just re-pick
        changeCoverTapped()
    }

    @objc private func exportTapped() {
        guard !entries.isEmpty, !isExporting else { return }
        exportPDF()
    }

    // MARK: - PDF Export

    private func exportPDF() {
        isExporting = true
        showExportOverlay()

        let baby = CoreDataStack.shared.fetchBaby()
        let babyName = baby?.name ?? "아기"
        let allPages = pages

        let pdfW: CGFloat = 94 * 3
        let pdfH: CGFloat = 128 * 3
        let pageRect = CGRect(x: 0, y: 0, width: pdfW, height: pdfH)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            let data = renderer.pdfData { context in
                for page in allPages {
                    context.beginPage()

                    let image = self.renderPageToImage(page: page, size: CGSize(width: pdfW, height: pdfH))
                    image?.draw(in: pageRect)
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

    private func renderPageToImage(page: PageContent, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let context = ctx.cgContext

            // Background
            context.setFillColor(DS.bgBase.cgColor)
            context.fill(rect)

            let baby = CoreDataStack.shared.fetchBaby()
            let margin: CGFloat = 48
            let textRect = rect.insetBy(dx: margin, dy: margin)

            switch page {
            case .cover:
                if let data = coverPhotoData, let image = UIImage(data: data) {
                    image.draw(in: rect)
                }
                let title = "\(baby?.name ?? "")의 일기"
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(54),
                    .foregroundColor: DS.fgStrong,
                ]
                let titleSize = (title as NSString).size(withAttributes: titleAttrs)
                let titlePoint = CGPoint(x: (size.width - titleSize.width) / 2, y: size.height - 90)
                (title as NSString).draw(at: titlePoint, withAttributes: titleAttrs)

            case .entryFirst(let entry, let textSlice, let num):
                var yOffset: CGFloat = margin

                if let data = entry.photoData, let image = UIImage(data: data) {
                    let photoHeight = size.width * 0.56
                    let photoRect = CGRect(x: margin, y: yOffset, width: size.width - margin * 2, height: photoHeight)
                    image.draw(in: photoRect)
                    yOffset += photoHeight + 30
                }

                let dateAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(33),
                    .foregroundColor: DS.fgNeutral,
                ]
                (entry.formattedDate as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: dateAttrs)

                let dText = "D+\(baby?.dayCountAt(date: entry.date) ?? 0)"
                let dAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(27),
                    .foregroundColor: DS.fgPale,
                ]
                let dSize = (dText as NSString).size(withAttributes: dAttrs)
                (dText as NSString).draw(at: CGPoint(x: size.width - margin - dSize.width, y: yOffset), withAttributes: dAttrs)
                yOffset += 50

                if !textSlice.isEmpty {
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.lineSpacing = 18
                    let textAttrs: [NSAttributedString.Key: Any] = [
                        .font: DS.font(33),
                        .foregroundColor: DS.fgStrong,
                        .paragraphStyle: paragraphStyle,
                    ]
                    let textDrawRect = CGRect(x: margin, y: yOffset, width: textRect.width, height: size.height - yOffset - 50)
                    (textSlice as NSString).draw(in: textDrawRect, withAttributes: textAttrs)
                }

                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(27),
                    .foregroundColor: DS.fgPale,
                ]
                let numText = "\(num)"
                let numSize = (numText as NSString).size(withAttributes: numAttrs)
                (numText as NSString).draw(at: CGPoint(x: size.width - margin - numSize.width, y: size.height - margin), withAttributes: numAttrs)

            case .entryContinuation(_, let textSlice, let num):
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 18
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(33),
                    .foregroundColor: DS.fgStrong,
                    .paragraphStyle: paragraphStyle,
                ]
                let textDrawRect = CGRect(x: margin, y: margin, width: textRect.width, height: size.height - margin * 2 - 30)
                (textSlice as NSString).draw(in: textDrawRect, withAttributes: textAttrs)

                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(27),
                    .foregroundColor: DS.fgPale,
                ]
                let numText = "\(num)"
                let numSize = (numText as NSString).size(withAttributes: numAttrs)
                (numText as NSString).draw(at: CGPoint(x: size.width - margin - numSize.width, y: size.height - margin), withAttributes: numAttrs)

            case .empty:
                let emptyAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(42),
                    .foregroundColor: DS.fgPale,
                ]
                let text1 = "아직 기록이 없어요."
                let text2 = "오늘부터 시작해보세요!"
                let text1Size = (text1 as NSString).size(withAttributes: emptyAttrs)
                let text2Size = (text2 as NSString).size(withAttributes: emptyAttrs)
                (text1 as NSString).draw(at: CGPoint(x: (size.width - text1Size.width) / 2, y: size.height / 2 - 30), withAttributes: emptyAttrs)
                (text2 as NSString).draw(at: CGPoint(x: (size.width - text2Size.width) / 2, y: size.height / 2 + 20), withAttributes: emptyAttrs)

            case .backCover:
                if let data = baby?.photoData, let image = UIImage(data: data) {
                    let photoSize: CGFloat = 180
                    let photoRect = CGRect(x: (size.width - photoSize) / 2, y: size.height / 2 - 100, width: photoSize, height: photoSize)
                    let path = UIBezierPath(roundedRect: photoRect, cornerRadius: photoSize / 2)
                    path.addClip()
                    image.draw(in: photoRect)
                }
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: DS.font(42),
                    .foregroundColor: DS.fgMuted,
                ]
                let title = "\(baby?.name ?? "")의 일기"
                let titleSize = (title as NSString).size(withAttributes: titleAttrs)
                (title as NSString).draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: size.height / 2 + 100), withAttributes: titleAttrs)

                let innerPages = pages.count - 2
                if innerPages > 0 {
                    let countAttrs: [NSAttributedString.Key: Any] = [
                        .font: DS.font(33),
                        .foregroundColor: DS.fgPale,
                    ]
                    let countText = "총 \(innerPages)쪽"
                    let countSize = (countText as NSString).size(withAttributes: countAttrs)
                    (countText as NSString).draw(at: CGPoint(x: (size.width - countSize.width) / 2, y: size.height / 2 + 150), withAttributes: countAttrs)
                }
            }
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

// MARK: - PHPickerViewControllerDelegate

extension MinibookViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            let data = image.jpegData(compressionQuality: 0.8)
            DispatchQueue.main.async {
                self?.coverPhotoData = data
                if let data = data {
                    UserDefaults.standard.set(data, forKey: self?.coverKey ?? "")
                }
                self?.renderCurrentPage()
            }
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
