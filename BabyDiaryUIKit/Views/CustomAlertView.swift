import UIKit

class CustomAlertView: UIView {

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var onDismiss: (() -> Void)?

    init(title: String, message: String? = nil, buttonText: String, onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        super.init(frame: .zero)

        backgroundColor = UIColor.black.withAlphaComponent(0.3)

        containerView.backgroundColor = DS.bgBase
        containerView.layer.cornerRadius = 20
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowRadius = 16
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        titleLabel.text = title
        titleLabel.font = DS.font(16)
        titleLabel.textColor = DS.fgStrong
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.text = message
        messageLabel.font = DS.font(13)
        messageLabel.textColor = DS.fgMuted
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = message == nil
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        actionButton.setTitle(buttonText, for: .normal)
        actionButton.titleLabel?.font = DS.font(14)
        actionButton.setTitleColor(DS.fgStrong, for: .normal)
        actionButton.backgroundColor = DS.yellow
        actionButton.layer.cornerRadius = 12
        actionButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, actionButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stack)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.75),

            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            actionButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func dismiss() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            self.onDismiss?()
        }
    }

    func show(in view: UIView) {
        frame = view.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = 0
        view.addSubview(self)
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
    }
}
