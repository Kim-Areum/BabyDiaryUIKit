import UIKit

class AllEntriesViewController: UIViewController {

    // MARK: - Properties

    private var currentYear: Int
    private var currentMonth: Int
    private var entries: [CDDiaryEntry] = []
    private var monthEntries: [Int: CDDiaryEntry] = [:]

    private let monthLabel = UILabel()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private var collectionView: UICollectionView!

    // MARK: - Init

    init() {
        let now = Date()
        let cal = Calendar.current
        currentYear = cal.component(.year, from: now)
        currentMonth = cal.component(.month, from: now)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupMonthNavigation()
        setupCollectionView()
        reloadEntries()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadEntries()
    }

    // MARK: - Month Navigation

    private func setupMonthNavigation() {
        let navRow = UIView()
        navRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navRow)

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 14)

        prevButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: chevronConfig), for: .normal)
        prevButton.tintColor = DS.fgStrong
        prevButton.addTarget(self, action: #selector(prevMonth), for: .touchUpInside)
        prevButton.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setImage(UIImage(systemName: "chevron.right", withConfiguration: chevronConfig), for: .normal)
        nextButton.tintColor = DS.fgStrong
        nextButton.addTarget(self, action: #selector(nextMonth), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false

        monthLabel.font = DS.font(16)
        monthLabel.textColor = DS.fgStrong
        monthLabel.textAlignment = .center
        monthLabel.translatesAutoresizingMaskIntoConstraints = false

        navRow.addSubview(prevButton)
        navRow.addSubview(monthLabel)
        navRow.addSubview(nextButton)

        NSLayoutConstraint.activate([
            navRow.topAnchor.constraint(equalTo: view.topAnchor),
            navRow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navRow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navRow.heightAnchor.constraint(equalToConstant: 44),

            prevButton.leadingAnchor.constraint(equalTo: navRow.leadingAnchor, constant: 24),
            prevButton.centerYAnchor.constraint(equalTo: navRow.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 24),
            prevButton.heightAnchor.constraint(equalToConstant: 24),

            monthLabel.centerXAnchor.constraint(equalTo: navRow.centerXAnchor),
            monthLabel.centerYAnchor.constraint(equalTo: navRow.centerYAnchor),

            nextButton.trailingAnchor.constraint(equalTo: navRow.trailingAnchor, constant: -24),
            nextButton.centerYAnchor.constraint(equalTo: navRow.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 24),
            nextButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    // MARK: - Collection View

    private func setupCollectionView() {
        let spacing: CGFloat = 8
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 20, right: 12)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = DS.bgBase
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(DayCellView.self, forCellWithReuseIdentifier: DayCellView.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 44),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Data

    private func reloadEntries() {
        entries = CoreDataStack.shared.fetchEntries(sortAscending: true)
        buildMonthEntries()
        updateMonthLabel()
        updateNavigationButtons()
        collectionView.reloadData()
    }

    private func buildMonthEntries() {
        let cal = Calendar.current
        monthEntries = [:]
        for entry in entries {
            let comps = cal.dateComponents([.year, .month, .day], from: entry.date)
            if comps.year == currentYear && comps.month == currentMonth, let day = comps.day {
                monthEntries[day] = entry
            }
        }
    }

    private var daysInMonth: Int {
        let cal = Calendar.current
        guard let date = cal.date(from: DateComponents(year: currentYear, month: currentMonth)),
              let range = cal.range(of: .day, in: .month, for: date) else { return 31 }
        return range.count
    }

    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        let now = Date()
        return currentYear == cal.component(.year, from: now) && currentMonth == cal.component(.month, from: now)
    }

    private var canGoBack: Bool {
        guard let baby = CoreDataStack.shared.fetchBaby() else { return false }
        let cal = Calendar.current
        let birthYear = cal.component(.year, from: baby.birthDate)
        let birthMonth = cal.component(.month, from: baby.birthDate)
        return currentYear > birthYear || (currentYear == birthYear && currentMonth > birthMonth)
    }

    private func makeDate(day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) ?? Date()
    }

    private func updateMonthLabel() {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        guard let date = Calendar.current.date(from: DateComponents(year: currentYear, month: currentMonth)) else { return }
        monthLabel.text = formatter.string(from: date)
    }

    private func updateNavigationButtons() {
        prevButton.tintColor = canGoBack ? DS.fgStrong : DS.fgPale
        prevButton.isEnabled = canGoBack
        nextButton.tintColor = isCurrentMonth ? DS.fgPale : DS.fgStrong
        nextButton.isEnabled = !isCurrentMonth
    }

    // MARK: - Actions

    @objc private func prevMonth() {
        guard canGoBack else { return }
        if currentMonth == 1 {
            currentYear -= 1
            currentMonth = 12
        } else {
            currentMonth -= 1
        }
        buildMonthEntries()
        updateMonthLabel()
        updateNavigationButtons()
        collectionView.reloadData()
    }

    @objc private func nextMonth() {
        guard !isCurrentMonth else { return }
        if currentMonth == 12 {
            currentYear += 1
            currentMonth = 1
        } else {
            currentMonth += 1
        }
        buildMonthEntries()
        updateMonthLabel()
        updateNavigationButtons()
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource

extension AllEntriesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        daysInMonth
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DayCellView.reuseID, for: indexPath) as! DayCellView
        let day = indexPath.item + 1
        let entry = monthEntries[day]
        let date = makeDate(day: day)
        let isFuture = date > Date()
        cell.configure(day: day, entry: entry, isFuture: isFuture)
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension AllEntriesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 8
        let inset: CGFloat = 12
        let totalSpacing = spacing * 2 + inset * 2
        let width = (collectionView.bounds.width - totalSpacing) / 3
        let cellHeight = width + 24 // square photo area + day label
        return CGSize(width: width, height: cellHeight)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let day = indexPath.item + 1
        let date = makeDate(day: day)
        guard date <= Date() else { return }

        // 해당 월의 컨텐츠 있는 엔트리들을 모아서 피드 뷰로 이동
        let monthEntriesList = (1...daysInMonth).compactMap { monthEntries[$0] }
            .filter { !$0.text.isEmpty || $0.photoData != nil }

        if !monthEntriesList.isEmpty {
            let feedVC = MonthFeedViewController(entries: monthEntriesList, selectedDate: date)
            feedVC.modalPresentationStyle = .fullScreen
            feedVC.onDismiss = { [weak self] in
                self?.reloadEntries()
            }
            present(feedVC, animated: true)
        } else {
            // 컨텐츠 없으면 작성화면
            guard let baby = CoreDataStack.shared.fetchBaby() else { return }
            let editorVC = DiaryEditorViewController(date: date, baby: baby)
            editorVC.modalPresentationStyle = .fullScreen
            editorVC.onDismiss = { [weak self] in
                self?.reloadEntries()
            }
            present(editorVC, animated: true)
        }
    }
}

// MARK: - Day Cell

private class DayCellView: UICollectionViewCell {
    static let reuseID = "DayCellView"

    private let thumbnailContainer = UIView()
    private let thumbnailImageView = UIImageView()
    private let textPreview = UILabel()
    private let dayLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        contentView.backgroundColor = .clear

        // Thumbnail container (square)
        thumbnailContainer.layer.cornerRadius = 8
        thumbnailContainer.clipsToBounds = true
        thumbnailContainer.backgroundColor = DS.bgSubtle
        thumbnailContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbnailContainer)

        // Photo
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailContainer.addSubview(thumbnailImageView)

        // Text preview
        textPreview.font = DS.font(8)
        textPreview.textColor = DS.fgMuted
        textPreview.numberOfLines = 4
        textPreview.translatesAutoresizingMaskIntoConstraints = false
        thumbnailContainer.addSubview(textPreview)

        // Day label
        dayLabel.font = DS.font(11)
        dayLabel.textAlignment = .center
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayLabel)

        NSLayoutConstraint.activate([
            thumbnailContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailContainer.heightAnchor.constraint(equalTo: thumbnailContainer.widthAnchor),

            thumbnailImageView.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor),

            textPreview.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor, constant: 6),
            textPreview.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor, constant: 6),
            textPreview.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor, constant: -6),
            textPreview.bottomAnchor.constraint(lessThanOrEqualTo: thumbnailContainer.bottomAnchor, constant: -6),

            dayLabel.topAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor),
            dayLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dayLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dayLabel.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    func configure(day: Int, entry: CDDiaryEntry?, isFuture: Bool) {
        dayLabel.text = "\(day)"

        // Reset
        thumbnailImageView.image = nil
        thumbnailImageView.isHidden = true
        textPreview.text = nil
        textPreview.isHidden = true

        thumbnailContainer.backgroundColor = DS.bgSubtle

        if let entry = entry, let data = entry.photoData, let image = UIImage(data: data) {
            thumbnailImageView.image = image
            thumbnailImageView.isHidden = false
        } else if let entry = entry, !entry.text.isEmpty {
            textPreview.text = entry.text
            textPreview.isHidden = false
        }

        if isFuture {
            dayLabel.textColor = DS.fgPale
            contentView.alpha = 0.4
        } else {
            dayLabel.textColor = entry != nil ? DS.fgStrong : DS.fgMuted
            contentView.alpha = 1.0
        }
    }
}
