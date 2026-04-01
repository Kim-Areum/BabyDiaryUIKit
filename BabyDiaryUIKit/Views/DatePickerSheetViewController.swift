import UIKit

protocol DatePickerSheetDelegate: AnyObject {
    func datePickerSheet(_ sheet: DatePickerSheetViewController, didSelectDate date: Date)
}

class DatePickerSheetViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    weak var delegate: DatePickerSheetDelegate?
    var selectedDate: Date
    var maxDate: Date

    private let pickerView = UIPickerView()
    private let calendar = Calendar.current
    private let years: [Int]
    private let months = Array(1...12)
    private let customFont = UIFont(name: "Ownglyph_PDH-Rg", size: 19) ?? .systemFont(ofSize: 19, weight: .medium)

    init(selectedDate: Date, maxDate: Date = Date()) {
        self.selectedDate = selectedDate
        self.maxDate = maxDate
        let currentYear = Calendar.current.component(.year, from: Date())
        self.years = Array((currentYear - 30)...currentYear)
        super.init(nibName: nil, bundle: nil)

        if let sheet = sheetPresentationController {
            sheet.detents = [.custom { _ in 300 }]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 24
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase

        // Nav bar
        let navBar = NavBarView()
        navBar.titleLabel.text = "날짜 선택"
        navBar.leftButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        navBar.leftButton.tintColor = DS.fgStrong
        navBar.leftButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let doneButton = UIButton(type: .system)
        doneButton.setTitle("완료", for: .normal)
        doneButton.titleLabel?.font = DS.font(13)
        doneButton.setTitleColor(DS.fgStrong, for: .normal)
        doneButton.backgroundColor = DS.blue
        doneButton.layer.cornerRadius = 15
        doneButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(doneButton)

        NSLayoutConstraint.activate([
            doneButton.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -20),
            doneButton.centerYAnchor.constraint(equalTo: navBar.titleLabel.centerYAnchor),
        ])

        navBar.rightButton.isHidden = true
        navBar.translatesAutoresizingMaskIntoConstraints = false

        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(navBar)
        view.addSubview(pickerView)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            pickerView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 8),
            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            pickerView.heightAnchor.constraint(equalToConstant: 200),
        ])

        setInitialSelection()
    }

    // MARK: - UIPickerView

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0: return years.count
        case 1: return months.count
        case 2: return daysInCurrentMonth()
        default: return 0
        }
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? UILabel()
        label.textAlignment = .center
        label.font = customFont
        label.textColor = DS.fgStrong

        switch component {
        case 0: label.text = "\(years[row])"
        case 1: label.text = "\(months[row])월"
        case 2: label.text = "\(row + 1)일"
        default: break
        }
        return label
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if component == 0 || component == 1 {
            pickerView.reloadComponent(2)
            let maxDay = daysInCurrentMonth()
            let currentDay = pickerView.selectedRow(inComponent: 2) + 1
            if currentDay > maxDay {
                pickerView.selectRow(maxDay - 1, inComponent: 2, animated: false)
            }
        }
        updateSelection()
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 40 }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        switch component {
        case 0: return 90
        case 1: return 70
        case 2: return 70
        default: return 60
        }
    }

    private func daysInCurrentMonth() -> Int {
        let yearIdx = pickerView.selectedRow(inComponent: 0)
        let monthIdx = pickerView.selectedRow(inComponent: 1)
        let year = years[yearIdx]
        let month = months[monthIdx]
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        guard let date = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 31 }
        return range.count
    }

    private func updateSelection() {
        let year = years[pickerView.selectedRow(inComponent: 0)]
        let month = months[pickerView.selectedRow(inComponent: 1)]
        let day = pickerView.selectedRow(inComponent: 2) + 1
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        if let date = calendar.date(from: comps) {
            selectedDate = min(date, maxDate)
        }
    }

    private func setInitialSelection() {
        let comps = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        if let yearIdx = years.firstIndex(of: comps.year ?? 2026) {
            pickerView.selectRow(yearIdx, inComponent: 0, animated: false)
        }
        if let month = comps.month {
            pickerView.selectRow(month - 1, inComponent: 1, animated: false)
        }
        pickerView.reloadComponent(2)
        if let day = comps.day {
            pickerView.selectRow(day - 1, inComponent: 2, animated: false)
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        delegate?.datePickerSheet(self, didSelectDate: selectedDate)
        dismiss(animated: true)
    }
}
