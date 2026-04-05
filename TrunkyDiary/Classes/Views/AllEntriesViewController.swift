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

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

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
        setupWeekdayHeader()
        setupCollectionView()
        setupSwipeGestures()
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

        monthLabel.font = DS.font(14)
        monthLabel.textColor = DS.fgStrong
        monthLabel.textAlignment = .center
        monthLabel.isUserInteractionEnabled = true
        monthLabel.translatesAutoresizingMaskIntoConstraints = false

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(goToCurrentMonth))
        doubleTap.numberOfTapsRequired = 2
        monthLabel.addGestureRecognizer(doubleTap)

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

    // MARK: - Weekday Header

    private func setupWeekdayHeader() {
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.distribution = .fillEqually
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)

        for (index, day) in weekdays.enumerated() {
            let label = UILabel()
            label.text = day
            label.font = DS.font(11)
            label.textAlignment = .center
            if index == 0 {
                label.textColor = UIColor(hex: "D05050") // 일요일 빨간색
            } else if index == 6 {
                label.textColor = DS.accentCalendar // 토요일
            } else {
                label.textColor = DS.fgMuted
            }
            headerStack.addArrangedSubview(label)
        }

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 44),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            headerStack.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    // MARK: - Collection View

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 4

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = DS.bgBase
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: CalendarDayCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 78),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
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

    /// 해당 월 1일의 요일 (0=일, 1=월, ... 6=토)
    private var firstWeekday: Int {
        let cal = Calendar.current
        guard let date = cal.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)) else { return 0 }
        let weekday = cal.component(.weekday, from: date) // 1=일, 2=월, ...
        return weekday - 1
    }

    private var totalCells: Int {
        firstWeekday + daysInMonth
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

    @objc private func goToCurrentMonth() {
        let cal = Calendar.current
        let now = Date()
        currentYear = cal.component(.year, from: now)
        currentMonth = cal.component(.month, from: now)
        buildMonthEntries()
        updateMonthLabel()
        updateNavigationButtons()
        collectionView.reloadData()
    }

    // MARK: - Swipe Gestures

    private func setupSwipeGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(nextMonth))
        swipeLeft.direction = .left
        collectionView.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(prevMonth))
        swipeRight.direction = .right
        collectionView.addGestureRecognizer(swipeRight)
    }
}

// MARK: - UICollectionViewDataSource

extension AllEntriesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        totalCells
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDayCell.reuseID, for: indexPath) as! CalendarDayCell

        let index = indexPath.item
        if index < firstWeekday {
            // 빈 셀
            cell.configure(day: nil, entry: nil, isFuture: false, isToday: false, weekdayIndex: index)
        } else {
            let day = index - firstWeekday + 1
            let entry = monthEntries[day]
            let date = makeDate(day: day)
            let cal = Calendar.current
            let baby = CoreDataStack.shared.fetchBaby()
            let minDate = baby.flatMap { cal.date(byAdding: .year, value: -1, to: $0.birthDate) }
            let isTooEarly = minDate != nil && date < cal.startOfDay(for: minDate!)
            let isFuture = date > Date() || isTooEarly

            let isToday = cal.isDateInToday(date)
            let weekdayIndex = index % 7
            var isBirthday = false
            if let bd = baby?.birthDate {
                let bdMonth = cal.component(.month, from: bd)
                let bdDay = cal.component(.day, from: bd)
                isBirthday = (currentMonth == bdMonth && day == bdDay)
            }

            cell.configure(day: day, entry: entry, isFuture: isFuture, isToday: isToday, weekdayIndex: weekdayIndex, isBirthday: isBirthday)
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension AllEntriesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width / 7
        return CGSize(width: width, height: width + 8)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let index = indexPath.item
        guard index >= firstWeekday else { return }

        let day = index - firstWeekday + 1
        let date = makeDate(day: day)
        guard date <= Date() else { return }

        // 아기 생일 1년 전부터만 작성 가능
        if let baby = CoreDataStack.shared.fetchBaby() {
            let minDate = Calendar.current.date(byAdding: .year, value: -1, to: baby.birthDate) ?? baby.birthDate
            guard date >= Calendar.current.startOfDay(for: minDate) else { return }
        }

        let entry = monthEntries[day]
        let hasContent = entry != nil && (!entry!.text.isEmpty || entry!.photoData != nil)

        if hasContent {
            let monthEntriesList = (1...daysInMonth).compactMap { monthEntries[$0] }
                .filter { !$0.text.isEmpty || $0.photoData != nil }
            let feedVC = MonthFeedViewController(entries: monthEntriesList, selectedDate: date)
            feedVC.modalPresentationStyle = .fullScreen
            feedVC.transitioningDelegate = PushTransitionManager.shared
            feedVC.onDismiss = { [weak self] in
                self?.reloadEntries()
            }
            present(feedVC, animated: true)
        } else {
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

// MARK: - Calendar Day Cell

private class CalendarDayCell: UICollectionViewCell {
    static let reuseID = "CalendarDayCell"

    private let dayLabel = UILabel()
    private let dotView = UIView()
    private let thumbnailImageView = UIImageView()
    private let todayCircle = UIView()
    private let birthdayCircle = UIView()
    private let hbdLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        contentView.backgroundColor = .clear

        // 오늘 동그라미 (손그림 느낌)
        todayCircle.backgroundColor = .clear
        todayCircle.isHidden = true
        todayCircle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(todayCircle)
        drawHandDrawnCircle()

        // 날짜 숫자
        dayLabel.font = DS.font(13)
        dayLabel.textAlignment = .center
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayLabel)

        // 사진 섬네일 (작은 원)
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 4
        thumbnailImageView.isHidden = true
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbnailImageView)

        // 텍스트 기록 dot
        dotView.backgroundColor = DS.accentCalendar
        dotView.layer.cornerRadius = 3
        dotView.isHidden = true
        dotView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dotView)

        // 생일 동그라미
        birthdayCircle.backgroundColor = .clear
        birthdayCircle.isHidden = true
        birthdayCircle.translatesAutoresizingMaskIntoConstraints = false
        contentView.insertSubview(birthdayCircle, belowSubview: dayLabel)
        drawBirthdayCircle()

        // HBD 라벨
        hbdLabel.text = "HBD"
        hbdLabel.font = DS.font(7)
        hbdLabel.textColor = UIColor(hex: "D05050")
        hbdLabel.isHidden = true
        hbdLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hbdLabel)

        NSLayoutConstraint.activate([
            birthdayCircle.centerXAnchor.constraint(equalTo: dayLabel.centerXAnchor),
            birthdayCircle.centerYAnchor.constraint(equalTo: dayLabel.centerYAnchor),
            birthdayCircle.widthAnchor.constraint(equalToConstant: 20),
            birthdayCircle.heightAnchor.constraint(equalToConstant: 20),

            hbdLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 1),
            hbdLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),

            todayCircle.centerXAnchor.constraint(equalTo: dayLabel.centerXAnchor),
            todayCircle.centerYAnchor.constraint(equalTo: dayLabel.centerYAnchor),
            todayCircle.widthAnchor.constraint(equalToConstant: 20),
            todayCircle.heightAnchor.constraint(equalToConstant: 20),

            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),

            thumbnailImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            thumbnailImageView.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 4),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 32),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 22),

            dotView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dotView.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 6),
            dotView.widthAnchor.constraint(equalToConstant: 6),
            dotView.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    private static let handDrawnCirclePath: CGPath = {
        let size: CGFloat = 20
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius: CGFloat = size / 2 - 1.5

        let path = UIBezierPath()
        let offsets: [CGFloat] = [0.2, -0.15, 0.2, -0.2, 0.15, -0.2, 0.2, -0.15, 0.15, -0.2, 0.2, -0.15]
        let segments = offsets.count
        let angleStep = (2 * CGFloat.pi) / CGFloat(segments)

        let startR = radius + offsets[0]
        path.move(to: CGPoint(x: center.x + startR, y: center.y))

        for i in 1...segments {
            let angle = angleStep * CGFloat(i)
            let wobble = offsets[i % segments]
            let r = radius + wobble
            let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))

            let midAngle = angleStep * (CGFloat(i) - 0.5)
            let ctrlR = radius + wobble * 0.3
            let ctrl = CGPoint(x: center.x + ctrlR * cos(midAngle), y: center.y + ctrlR * sin(midAngle))

            path.addQuadCurve(to: point, controlPoint: ctrl)
        }
        path.close()
        return path.cgPath
    }()

    private func drawHandDrawnCircle() {
        todayCircle.layer.sublayers?.removeAll()

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = Self.handDrawnCirclePath
        shapeLayer.strokeColor = DS.accentCalendar.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 1.3
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round

        todayCircle.layer.addSublayer(shapeLayer)
    }

    private static let birthdayCirclePath: CGPath = {
        let size: CGFloat = 20
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius: CGFloat = size / 2 - 1.5

        let path = UIBezierPath()
        let offsets: [CGFloat] = [0.15, -0.1, 0.12, -0.15, 0.1, -0.12, 0.15, -0.1, 0.12, -0.15, 0.1, -0.12]
        let segments = offsets.count
        let angleStep = (2 * CGFloat.pi) / CGFloat(segments)

        let startR = radius + offsets[0]
        path.move(to: CGPoint(x: center.x + startR, y: center.y))

        for i in 1...segments {
            let angle = angleStep * CGFloat(i)
            let wobble = offsets[i % segments]
            let r = radius + wobble
            let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))

            let midAngle = angleStep * (CGFloat(i) - 0.5)
            let ctrlR = radius + wobble * 0.3
            let ctrl = CGPoint(x: center.x + ctrlR * cos(midAngle), y: center.y + ctrlR * sin(midAngle))

            path.addQuadCurve(to: point, controlPoint: ctrl)
        }
        path.close()
        return path.cgPath
    }()

    private func drawBirthdayCircle() {
        birthdayCircle.layer.sublayers?.removeAll()
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = Self.birthdayCirclePath
        shapeLayer.strokeColor = UIColor(hex: "D05050").cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 1.3
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        birthdayCircle.layer.addSublayer(shapeLayer)
    }

    func configure(day: Int?, entry: CDDiaryEntry?, isFuture: Bool, isToday: Bool, weekdayIndex: Int, isBirthday: Bool = false) {
        // Reset
        dayLabel.text = nil
        thumbnailImageView.image = nil
        thumbnailImageView.isHidden = true
        dotView.isHidden = true
        todayCircle.isHidden = true
        birthdayCircle.isHidden = true
        hbdLabel.isHidden = true
        contentView.alpha = 1.0

        guard let day = day else { return }

        dayLabel.text = "\(day)"

        // 요일 색상
        if isFuture {
            dayLabel.textColor = DS.fgPale
            contentView.alpha = 0.4
        } else if weekdayIndex == 0 {
            dayLabel.textColor = UIColor(hex: "D05050")
        } else if weekdayIndex == 6 {
            dayLabel.textColor = DS.accentCalendar
        } else if entry != nil {
            dayLabel.textColor = DS.fgStrong
        } else {
            dayLabel.textColor = DS.fgMuted
        }

        // 생일 표시 (오늘보다 우선)
        if isBirthday {
            birthdayCircle.isHidden = false
            hbdLabel.isHidden = false
        } else if isToday {
            todayCircle.isHidden = false
        }

        // 컨텐츠 표시
        if let entry = entry, !isFuture {
            if let data = entry.photoData, let image = UIImage(data: data) {
                thumbnailImageView.image = image
                thumbnailImageView.isHidden = false
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        dayLabel.text = nil
        thumbnailImageView.image = nil
        thumbnailImageView.isHidden = true
        dotView.isHidden = true
        todayCircle.isHidden = true
        birthdayCircle.isHidden = true
        hbdLabel.isHidden = true
        contentView.alpha = 1.0
    }
}
