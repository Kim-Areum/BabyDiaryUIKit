import UIKit

// MARK: - 디자인 시스템 (UIKit)

enum DS {
    // Colors (Greige 팔레트)
    static let bgBase = UIColor(hex: "FFFBF0")
    static let bgSub = UIColor(hex: "FAF6EB")
    static let bgSubtle = UIColor(hex: "F4EFE3")
    static let bgNeutral = UIColor(hex: "DED7C7")

    static let fgIntense = UIColor(hex: "0C0B08")
    static let fgStrong = UIColor(hex: "322E26")
    static let fgNeutral = UIColor(hex: "6C6557")
    static let fgMuted = UIColor(hex: "928A79")
    static let fgPale = UIColor(hex: "C3BAA7")

    static let line = UIColor(hex: "E7E0D1")
    static let stitch = UIColor(hex: "D6CFBF")

    static let yellow = UIColor(hex: "FCF1D3")
    static let yellowBorder = UIColor(hex: "D4BD7F")
    static let blue = UIColor(hex: "B1C3D7")
    static let pink = UIColor(hex: "DBB9B2")
    static let green = UIColor(hex: "C3E3CD")
    static let purple = UIColor(hex: "DECEF0")

    // Font
    static let fontName = "Ownglyph_PDH-Rg"

    static func font(_ size: CGFloat) -> UIFont {
        UIFont(name: fontName, size: size + 1) ?? .systemFont(ofSize: size + 1)
    }
}

// MARK: - UIColor hex 확장

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

// MARK: - 공통 UI 컴포넌트

class DateBadgeView: UIView {
    private let label = UILabel()

    init(text: String) {
        super.init(frame: .zero)
        label.text = text
        label.font = DS.font(11)
        label.textColor = DS.fgNeutral
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
        backgroundColor = DS.yellow
        layer.cornerRadius = 4
        layer.borderWidth = 0.5
        layer.borderColor = DS.yellowBorder.cgColor
    }

    func update(text: String) {
        label.text = text
    }

    required init?(coder: NSCoder) { fatalError() }
}

class NavBarView: UIView {
    let titleLabel = UILabel()
    let leftButton = UIButton(type: .system)
    let rightButton = UIButton(type: .system)
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DS.bgBase

        titleLabel.font = DS.font(16)
        titleLabel.textColor = DS.fgStrong
        titleLabel.textAlignment = .center

        separator.backgroundColor = DS.line

        addSubview(titleLabel)
        addSubview(leftButton)
        addSubview(rightButton)
        addSubview(separator)

        [titleLabel, leftButton, rightButton, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            leftButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            leftButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            leftButton.widthAnchor.constraint(equalToConstant: 24),
            leftButton.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            rightButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            rightButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
