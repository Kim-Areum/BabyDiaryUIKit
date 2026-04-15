import UIKit

class MonthFeedViewController: UIViewController {

    // MARK: - Properties

    private var allEntries: [CDDiaryEntry] = []
    private var groupedEntries: [(month: String, entries: [CDDiaryEntry])] = []
    private let selectedDate: Date
    var onDismiss: (() -> Void)?

    private let tableView = UITableView(frame: .zero, style: .grouped)

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

    private let swipeBack = SwipeBackInteractionController()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        transitioningDelegate = PushTransitionManager.shared
        setupNavBar()
        setupTableView()
        swipeBack.attach(to: self)

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

    private var lastPopupEntry: CDDiaryEntry?

    // MARK: - Correction

    private let speechManagerForCorrection = SpeechManager()

    private func showCorrectionResultPopup(original: String, corrected: String, entry: CDDiaryEntry) {
        guard let window = view.window else { return }

        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.alpha = 0
        window.addSubview(overlay)

        let popup = UIView()
        popup.backgroundColor = DS.bgBase
        popup.layer.cornerRadius = 16
        popup.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(popup)

        let titleLabel = UILabel()
        titleLabel.text = "문장 교정 결과"
        titleLabel.font = DS.font(16)
        titleLabel.textColor = DS.fgStrong
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(titleLabel)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // 원본 텍스트
        let origHeader = UILabel()
        origHeader.text = "원본"
        origHeader.font = DS.font(12)
        origHeader.textColor = DS.fgMuted
        contentStack.addArrangedSubview(origHeader)

        let origLabel = UILabel()
        origLabel.numberOfLines = 0
        origLabel.attributedText = buildDiffAttributedString(original: original, corrected: corrected, showOriginal: true)
        contentStack.addArrangedSubview(origLabel)

        let divider = UIView()
        divider.backgroundColor = DS.fgPale.withAlphaComponent(0.3)
        divider.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(divider)

        // 교정 텍스트
        let corrHeader = UILabel()
        corrHeader.text = "교정"
        corrHeader.font = DS.font(12)
        corrHeader.textColor = DS.fgMuted
        contentStack.addArrangedSubview(corrHeader)

        let corrLabel = UILabel()
        corrLabel.numberOfLines = 0
        corrLabel.attributedText = buildDiffAttributedString(original: original, corrected: corrected, showOriginal: false)
        contentStack.addArrangedSubview(corrLabel)

        // 버튼 영역
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        popup.addSubview(buttonStack)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("취소", for: .normal)
        cancelBtn.titleLabel?.font = DS.font(14)
        cancelBtn.setTitleColor(DS.fgMuted, for: .normal)
        cancelBtn.backgroundColor = DS.bgSubtle
        cancelBtn.layer.cornerRadius = 10
        buttonStack.addArrangedSubview(cancelBtn)

        let applyBtn = UIButton(type: .system)
        applyBtn.setTitle("적용", for: .normal)
        applyBtn.titleLabel?.font = DS.font(14)
        applyBtn.setTitleColor(.white, for: .normal)
        applyBtn.backgroundColor = DS.accent
        applyBtn.layer.cornerRadius = 10
        buttonStack.addArrangedSubview(applyBtn)

        NSLayoutConstraint.activate([
            popup.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            popup.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            popup.widthAnchor.constraint(equalTo: overlay.widthAnchor, multiplier: 0.85),
            popup.heightAnchor.constraint(lessThanOrEqualTo: overlay.heightAnchor, multiplier: 0.6),

            titleLabel.topAnchor.constraint(equalTo: popup.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -16),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            divider.heightAnchor.constraint(equalToConstant: 1),

            buttonStack.leadingAnchor.constraint(equalTo: popup.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: popup.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: popup.bottomAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),
        ])

        // Actions
        cancelBtn.addAction(UIAction { _ in
            UIView.animate(withDuration: 0.2) { overlay.alpha = 0 } completion: { _ in overlay.removeFromSuperview() }
        }, for: .touchUpInside)

        applyBtn.addAction(UIAction { [weak self] _ in
            entry.text = corrected
            CoreDataStack.shared.save()
            self?.reloadAllEntries()
            UIView.animate(withDuration: 0.2) { overlay.alpha = 0 } completion: { _ in overlay.removeFromSuperview() }
        }, for: .touchUpInside)

        UIView.animate(withDuration: 0.25) { overlay.alpha = 1 }
    }

    /// 단어 단위 diff를 NSAttributedString으로 생성
    private func buildDiffAttributedString(original: String, corrected: String, showOriginal: Bool) -> NSAttributedString {
        let origWords = original.components(separatedBy: " ")
        let corrWords = corrected.components(separatedBy: " ")
        let result = NSMutableAttributedString()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        if showOriginal {
            // 원본: 변경/삭제된 단어에 빨간 취소선
            let lcs = longestCommonSubsequence(origWords, corrWords)
            var lcsIdx = 0
            for word in origWords {
                let isKept = lcsIdx < lcs.count && word == lcs[lcsIdx]
                if isKept {
                    lcsIdx += 1
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: DS.font(14), .foregroundColor: DS.fgStrong, .paragraphStyle: paragraphStyle
                    ]
                    result.append(NSAttributedString(string: word + " ", attributes: attrs))
                } else {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: DS.font(14),
                        .foregroundColor: UIColor.systemRed.withAlphaComponent(0.7),
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: UIColor.systemRed.withAlphaComponent(0.7),
                        .paragraphStyle: paragraphStyle
                    ]
                    result.append(NSAttributedString(string: word + " ", attributes: attrs))
                }
            }
        } else {
            // 교정: 새로 추가/변경된 단어를 accent 색으로 표시
            let lcs = longestCommonSubsequence(origWords, corrWords)
            var lcsIdx = 0
            for word in corrWords {
                let isKept = lcsIdx < lcs.count && word == lcs[lcsIdx]
                if isKept {
                    lcsIdx += 1
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: DS.font(14), .foregroundColor: DS.fgStrong, .paragraphStyle: paragraphStyle
                    ]
                    result.append(NSAttributedString(string: word + " ", attributes: attrs))
                } else {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: DS.font(14),
                        .foregroundColor: DS.accent,
                        .backgroundColor: DS.accent.withAlphaComponent(0.1),
                        .paragraphStyle: paragraphStyle
                    ]
                    result.append(NSAttributedString(string: word + " ", attributes: attrs))
                }
            }
        }

        return result
    }

    /// 단어 배열의 최장 공통 부분 수열 (LCS)
    private func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count, n = b.count
        guard m > 0, n > 0 else { return [] }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        var result: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append(a[i - 1])
                i -= 1; j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return result.reversed()
    }

    private func showPlaybackPopup(entry: CDDiaryEntry) {
        lastPopupEntry = entry
        guard let window = view.window else { return }
        let popup = PlaybackPopupView(fileNames: entry.audioFileNamesArray, timestamps: entry.audioTimestampsArray)
        popup.delegate = self
        popup.show(in: window)
    }
}

// MARK: - PlaybackPopupDelegate

extension MonthFeedViewController: PlaybackPopupDelegate {
    func playbackPopupDidDelete(at index: Int) {
        // 현재 재생 중인 엔트리 찾기 — 가장 최근에 팝업을 연 엔트리
        guard let entry = lastPopupEntry else {
            reloadAllEntries()
            return
        }

        var names = entry.audioFileNamesArray
        var stamps = entry.audioTimestampsArray

        if index < names.count {
            let fileName = names[index]
            let url = SpeechManager.recordingsDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
            names.remove(at: index)
        }
        if index < stamps.count {
            stamps.remove(at: index)
        }
        entry.audioFileNamesArray = names
        entry.audioTimestampsArray = stamps
        CoreDataStack.shared.save()
        reloadAllEntries()
    }

    func playbackPopupDidDismiss() {}
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
        cell.onAudioTapped = { [weak self] entry in
            self?.showPlaybackPopup(entry: entry)
        }
        cell.onCorrectTapped = { [weak self] entry in
            guard let self else { return }
            cell.correctionState = .processing
            self.speechManagerForCorrection.correctTextAsync(entry.text) { corrected in
                cell.correctedText = corrected
                cell.originalText = entry.text
                cell.correctionState = .done
            }
        }
        cell.onCorrectionResultTapped = { [weak self] original, corrected in
            guard let self else { return }
            self.showCorrectionResultPopup(original: original, corrected: corrected, entry: entry)
        }
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
    private let audioButton = UIButton(type: .system)
    private let correctButton = UIButton(type: .system)
    private let correctSpinner = UIActivityIndicatorView(style: .medium)
    var onAudioTapped: ((CDDiaryEntry) -> Void)?
    var onCorrectTapped: ((CDDiaryEntry) -> Void)?
    var onCorrectionResultTapped: ((String, String) -> Void)?
    private var currentEntry: CDDiaryEntry?
    var originalText: String?
    var correctedText: String?

    enum CorrectionState { case idle, processing, done }
    var correctionState: CorrectionState = .idle {
        didSet { updateCorrectButton() }
    }

    private var photoHeightConstraint: NSLayoutConstraint?
    private var bodyTopToPhoto: NSLayoutConstraint?
    private var bodyTopToCard: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bodyWidth = UIScreen.main.bounds.width * 0.85 - 32 // 카드 0.85 - 패딩 16*2
        bodyTextLabel.preferredMaxLayoutWidth = bodyWidth
    }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        let cardWidth = UIScreen.main.bounds.width * 0.85

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

        bodyTextLabel.font = DS.font(15)
        bodyTextLabel.textColor = DS.fgStrong
        bodyTextLabel.numberOfLines = 0
        bodyTextLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(bodyTextLabel)

        let waveConfig = UIImage.SymbolConfiguration(pointSize: 12)
        audioButton.setImage(UIImage(systemName: "waveform", withConfiguration: waveConfig), for: .normal)
        audioButton.tintColor = DS.fgMuted
        audioButton.backgroundColor = DS.bgSubtle
        audioButton.layer.cornerRadius = 12
        var audioBtnConfig = UIButton.Configuration.plain()
        audioBtnConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        audioBtnConfig.baseForegroundColor = DS.fgMuted
        audioButton.configuration = audioBtnConfig
        audioButton.isHidden = true
        audioButton.addTarget(self, action: #selector(audioTapped), for: .touchUpInside)
        audioButton.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(audioButton)

        correctButton.setTitle("문장 교정", for: .normal)
        correctButton.titleLabel?.font = DS.font(11)
        correctButton.setTitleColor(DS.fgPale, for: .normal)
        correctButton.isHidden = true
        correctButton.addTarget(self, action: #selector(correctTapped), for: .touchUpInside)
        correctButton.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(correctButton)

        correctSpinner.color = DS.fgPale
        correctSpinner.hidesWhenStopped = true
        correctSpinner.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        correctSpinner.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(correctSpinner)

        photoHeightConstraint = photoImageView.heightAnchor.constraint(equalToConstant: cardWidth * 0.65)
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

            bodyView.leadingAnchor.constraint(equalTo: innerClip.leadingAnchor, constant: 16),
            bodyView.trailingAnchor.constraint(equalTo: innerClip.trailingAnchor, constant: -16),
            bodyView.bottomAnchor.constraint(equalTo: innerClip.bottomAnchor, constant: -14),

            topRow.topAnchor.constraint(equalTo: bodyView.topAnchor),
            topRow.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
            topRow.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),

            bodyTextLabel.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            bodyTextLabel.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
            bodyTextLabel.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),

            audioButton.topAnchor.constraint(equalTo: bodyTextLabel.bottomAnchor, constant: 6),
            audioButton.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),
            audioButton.bottomAnchor.constraint(lessThanOrEqualTo: bodyView.bottomAnchor),

            correctButton.topAnchor.constraint(equalTo: bodyTextLabel.bottomAnchor, constant: 6),
            correctButton.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
            correctButton.bottomAnchor.constraint(lessThanOrEqualTo: bodyView.bottomAnchor),

            correctSpinner.centerYAnchor.constraint(equalTo: correctButton.centerYAnchor),
            correctSpinner.leadingAnchor.constraint(equalTo: correctButton.trailingAnchor, constant: 4),
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
            dayCountLabel.text = baby.dayAndMonthAt(date: entry.date)
        }

        if !entry.text.isEmpty {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            paragraphStyle.lineBreakMode = .byWordWrapping
            bodyTextLabel.attributedText = NSAttributedString(
                string: entry.text,
                attributes: [
                    .font: DS.font(15),
                    .foregroundColor: DS.fgStrong,
                    .paragraphStyle: paragraphStyle,
                ]
            )
        } else {
            bodyTextLabel.attributedText = nil
        }
        bodyTextLabel.isHidden = entry.text.isEmpty

        currentEntry = entry
        correctionState = .idle
        originalText = nil
        correctedText = nil
        correctButton.isHidden = entry.text.isEmpty

        let audioNames = entry.audioFileNamesArray
        audioButton.isHidden = audioNames.isEmpty
        if !audioNames.isEmpty {
            var countTitle = AttributedString(" \(audioNames.count)")
            countTitle.font = DS.font(11)
            audioButton.configuration?.attributedTitle = countTitle
        }
    }

    @objc private func audioTapped() {
        guard let entry = currentEntry else { return }
        onAudioTapped?(entry)
    }

    @objc private func correctTapped() {
        guard let entry = currentEntry else { return }
        switch correctionState {
        case .idle:
            onCorrectTapped?(entry)
        case .processing:
            break
        case .done:
            if let orig = originalText, let corr = correctedText {
                onCorrectionResultTapped?(orig, corr)
            }
        }
    }

    private func updateCorrectButton() {
        switch correctionState {
        case .idle:
            correctButton.setTitle("문장 교정", for: .normal)
            correctButton.setTitleColor(DS.fgPale, for: .normal)
            correctSpinner.stopAnimating()
        case .processing:
            correctButton.setTitle("교정 중...", for: .normal)
            correctButton.setTitleColor(DS.fgPale, for: .normal)
            correctSpinner.startAnimating()
        case .done:
            correctButton.setTitle("교정 완료", for: .normal)
            correctButton.setTitleColor(DS.accent, for: .normal)
            correctSpinner.stopAnimating()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoImageView.image = nil
        photoImageView.isHidden = true
        bodyTextLabel.text = nil
        audioButton.isHidden = true
        correctButton.isHidden = true
        correctionState = .idle
        originalText = nil
        correctedText = nil
        onCorrectTapped = nil
        onCorrectionResultTapped = nil
        currentEntry = nil
        photoHeightConstraint?.isActive = false
        bodyTopToPhoto?.isActive = false
        bodyTopToCard?.isActive = true
    }
}
