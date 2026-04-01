import UIKit

class MonthFeedViewController: UIViewController {

    // MARK: - Properties

    private var allEntries: [CDDiaryEntry] = []
    private var groupedEntries: [(month: String, entries: [CDDiaryEntry])] = []
    private let selectedDate: Date
    var onDismiss: (() -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)

    // MARK: - Init

    init(entries: [CDDiaryEntry], selectedDate: Date) {
        self.selectedDate = selectedDate
        super.init(nibName: nil, bundle: nil)
        // 전체 컨텐츠 있는 엔트리를 날짜 내림차순으로
        self.allEntries = CoreDataStack.shared.fetchEntries(sortAscending: false)
            .filter { !$0.text.isEmpty || $0.photoData != nil }
        groupByMonth()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupNavBar()
        setupTableView()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scrollToSelectedDate()
        }
    }

    // MARK: - Setup

    private func setupNavBar() {
        let navBar = NavBarView()
        navBar.titleLabel.text = "전체 기록"
        navBar.leftButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        navBar.leftButton.tintColor = DS.fgStrong
        navBar.leftButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupTableView() {
        tableView.backgroundColor = DS.bgBase
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FeedEntryCell.self, forCellReuseIdentifier: FeedEntryCell.reuseID)
        tableView.register(FeedMonthHeader.self, forHeaderFooterViewReuseIdentifier: FeedMonthHeader.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Data

    private func groupByMonth() {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")

        var dict: [String: [CDDiaryEntry]] = [:]
        var order: [String] = []

        for entry in allEntries {
            let comps = cal.dateComponents([.year, .month], from: entry.date)
            guard let monthDate = cal.date(from: comps) else { continue }
            let key = formatter.string(from: monthDate)
            if dict[key] == nil {
                dict[key] = []
                order.append(key)
            }
            dict[key]?.append(entry)
        }

        groupedEntries = order.map { (month: $0, entries: dict[$0] ?? []) }
    }

    private func reloadAllEntries() {
        allEntries = CoreDataStack.shared.fetchEntries(sortAscending: false)
            .filter { !$0.text.isEmpty || $0.photoData != nil }
        groupByMonth()
        tableView.reloadData()
    }

    private func scrollToSelectedDate() {
        let cal = Calendar.current
        let selectedComps = cal.dateComponents([.year, .month, .day], from: selectedDate)

        for (section, group) in groupedEntries.enumerated() {
            for (row, entry) in group.entries.enumerated() {
                let entryComps = cal.dateComponents([.year, .month, .day], from: entry.date)
                if entryComps.year == selectedComps.year &&
                   entryComps.month == selectedComps.month &&
                   entryComps.day == selectedComps.day {
                    tableView.scrollToRow(at: IndexPath(row: row, section: section), at: .top, animated: false)
                    return
                }
            }
        }

        // 정확한 날짜 못 찾으면 해당 월 섹션 첫번째로
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        let selectedMonthKey = formatter.string(from: selectedDate)

        for (section, group) in groupedEntries.enumerated() {
            if group.month == selectedMonthKey {
                tableView.scrollToRow(at: IndexPath(row: 0, section: section), at: .top, animated: false)
                return
            }
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
}

// MARK: - UITableViewDataSource

extension MonthFeedViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        groupedEntries.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groupedEntries[section].entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FeedEntryCell.reuseID, for: indexPath) as! FeedEntryCell
        let entry = groupedEntries[indexPath.section].entries[indexPath.row]
        let baby = CoreDataStack.shared.fetchBaby()
        cell.configure(entry: entry, baby: baby)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MonthFeedViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: FeedMonthHeader.reuseID) as! FeedMonthHeader
        header.configure(title: groupedEntries[section].month)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        40
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = groupedEntries[indexPath.section].entries[indexPath.row]
        guard let baby = CoreDataStack.shared.fetchBaby() else { return }
        let editorVC = DiaryEditorViewController(date: entry.date, baby: baby)
        editorVC.modalPresentationStyle = .fullScreen
        editorVC.onDismiss = { [weak self] in
            self?.reloadAllEntries()
        }
        present(editorVC, animated: true)
    }
}

// MARK: - Feed Month Header

private class FeedMonthHeader: UITableViewHeaderFooterView {
    static let reuseID = "FeedMonthHeader"

    private let titleLabel = UILabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = DS.bgBase

        titleLabel.font = DS.font(14)
        titleLabel.textColor = DS.fgMuted
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) {
        titleLabel.text = title
    }
}

// MARK: - Feed Entry Cell

private class FeedEntryCell: UITableViewCell {
    static let reuseID = "FeedEntryCell"

    private let cardView = UIView()
    private let innerClip = UIView()
    private let photoImageView = UIImageView()
    private let dateBadge = DateBadgeView(text: "")
    private let dayCountLabel = UILabel()
    private let bodyTextLabel = UILabel()
    private let audioIcon = UIImageView()

    private var photoHeightConstraint: NSLayoutConstraint?
    private var bodyTopToPhoto: NSLayoutConstraint?
    private var bodyTopToCard: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        let cardWidth = UIScreen.main.bounds.width - 40

        cardView.backgroundColor = DS.bgBase
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius = 6
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        innerClip.clipsToBounds = true
        innerClip.layer.cornerRadius = 12
        innerClip.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(innerClip)

        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        innerClip.addSubview(photoImageView)

        let bodyView = UIView()
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        bodyView.tag = 500
        innerClip.addSubview(bodyView)

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(topRow)

        dateBadge.translatesAutoresizingMaskIntoConstraints = false
        topRow.addArrangedSubview(dateBadge)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        topRow.addArrangedSubview(spacer)

        dayCountLabel.font = DS.font(11)
        dayCountLabel.textColor = DS.fgPale
        topRow.addArrangedSubview(dayCountLabel)

        bodyTextLabel.font = DS.font(14)
        bodyTextLabel.textColor = DS.fgStrong
        bodyTextLabel.numberOfLines = 6
        bodyTextLabel.lineBreakMode = .byTruncatingTail
        bodyTextLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(bodyTextLabel)

        audioIcon.image = UIImage(systemName: "waveform")
        audioIcon.tintColor = DS.fgPale
        audioIcon.contentMode = .scaleAspectFit
        audioIcon.isHidden = true
        audioIcon.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(audioIcon)

        photoHeightConstraint = photoImageView.heightAnchor.constraint(equalToConstant: cardWidth * 0.5)
        bodyTopToPhoto = bodyView.topAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: 10)
        bodyTopToCard = bodyView.topAnchor.constraint(equalTo: innerClip.topAnchor, constant: 14)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            cardView.widthAnchor.constraint(equalToConstant: cardWidth),

            innerClip.topAnchor.constraint(equalTo: cardView.topAnchor),
            innerClip.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            innerClip.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            innerClip.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            photoImageView.topAnchor.constraint(equalTo: innerClip.topAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: innerClip.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: innerClip.trailingAnchor),

            bodyView.leadingAnchor.constraint(equalTo: innerClip.leadingAnchor, constant: 14),
            bodyView.trailingAnchor.constraint(equalTo: innerClip.trailingAnchor, constant: -14),
            bodyView.bottomAnchor.constraint(equalTo: innerClip.bottomAnchor, constant: -14),

            topRow.topAnchor.constraint(equalTo: bodyView.topAnchor),
            topRow.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
            topRow.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),

            bodyTextLabel.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            bodyTextLabel.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
            bodyTextLabel.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),

            audioIcon.topAnchor.constraint(equalTo: bodyTextLabel.bottomAnchor, constant: 6),
            audioIcon.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),
            audioIcon.widthAnchor.constraint(equalToConstant: 16),
            audioIcon.heightAnchor.constraint(equalToConstant: 16),
            audioIcon.bottomAnchor.constraint(lessThanOrEqualTo: bodyView.bottomAnchor),
        ])
    }

    func configure(entry: CDDiaryEntry, baby: CDBaby?) {
        if let data = entry.photoData, let image = UIImage(data: data) {
            photoImageView.image = image
            photoImageView.isHidden = false
            photoHeightConstraint?.isActive = true
            bodyTopToPhoto?.isActive = true
            bodyTopToCard?.isActive = false
        } else {
            photoImageView.image = nil
            photoImageView.isHidden = true
            photoHeightConstraint?.isActive = false
            bodyTopToPhoto?.isActive = false
            bodyTopToCard?.isActive = true
        }

        dateBadge.update(text: entry.formattedDate)

        if let baby = baby {
            dayCountLabel.text = "D+\(baby.dayCountAt(date: entry.date))"
        }

        bodyTextLabel.text = entry.text
        bodyTextLabel.isHidden = entry.text.isEmpty

        audioIcon.isHidden = entry.audioFileNamesArray.isEmpty
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoImageView.image = nil
        photoImageView.isHidden = true
        bodyTextLabel.text = nil
        audioIcon.isHidden = true
        photoHeightConstraint?.isActive = false
        bodyTopToPhoto?.isActive = false
        bodyTopToCard?.isActive = true
    }
}
