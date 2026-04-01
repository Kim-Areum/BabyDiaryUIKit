import UIKit

class HomeViewController: UIViewController {

    private var selectedTab = 0
    private let segmentStack = UIStackView()
    private let todayButton = UIButton(type: .system)
    private let allButton = UIButton(type: .system)
    private let todayIndicator = UIView()
    private let allIndicator = UIView()
    private let containerView = UIView()

    private var todayVC: TodayViewController?
    private var allEntriesVC: AllEntriesViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupSegmentBar()
        setupSegmentedControl()
        setupContainer()
        showTab(0)
    }

    private let segmentBar = UIView()

    private func setupSegmentBar() {
        segmentBar.backgroundColor = DS.bgBase
        segmentBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentBar)

        NSLayoutConstraint.activate([
            segmentBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            segmentBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            segmentBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            segmentBar.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupSegmentedControl() {
        // 오늘 버튼
        todayButton.setTitle("오늘", for: .normal)
        todayButton.titleLabel?.font = DS.font(13)
        todayButton.setTitleColor(DS.fgStrong, for: .normal)
        todayButton.addTarget(self, action: #selector(todayTapped), for: .touchUpInside)

        todayIndicator.backgroundColor = DS.blue
        todayIndicator.layer.cornerRadius = 2
        todayIndicator.translatesAutoresizingMaskIntoConstraints = false

        let todayStack = UIStackView(arrangedSubviews: [todayButton, todayIndicator])
        todayStack.axis = .vertical
        todayStack.alignment = .center
        todayStack.spacing = 4

        // 전체 버튼
        allButton.setTitle("전체", for: .normal)
        allButton.titleLabel?.font = DS.font(13)
        allButton.setTitleColor(DS.fgPale, for: .normal)
        allButton.addTarget(self, action: #selector(allTapped), for: .touchUpInside)

        allIndicator.backgroundColor = .clear
        allIndicator.layer.cornerRadius = 2
        allIndicator.translatesAutoresizingMaskIntoConstraints = false

        let allStack = UIStackView(arrangedSubviews: [allButton, allIndicator])
        allStack.axis = .vertical
        allStack.alignment = .center
        allStack.spacing = 4

        let hStack = UIStackView(arrangedSubviews: [todayStack, allStack])
        hStack.axis = .horizontal
        hStack.distribution = .fillEqually
        hStack.translatesAutoresizingMaskIntoConstraints = false
        segmentBar.addSubview(hStack)

        NSLayoutConstraint.activate([
            todayIndicator.widthAnchor.constraint(equalToConstant: 52),
            todayIndicator.heightAnchor.constraint(equalToConstant: 4),
            allIndicator.widthAnchor.constraint(equalToConstant: 52),
            allIndicator.heightAnchor.constraint(equalToConstant: 4),

            hStack.centerYAnchor.constraint(equalTo: segmentBar.centerYAnchor),
            hStack.leadingAnchor.constraint(equalTo: segmentBar.leadingAnchor, constant: 80),
            hStack.trailingAnchor.constraint(equalTo: segmentBar.trailingAnchor, constant: -80),
        ])
    }

    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func showTab(_ index: Int) {
        selectedTab = index

        // 인디케이터 업데이트
        todayButton.setTitleColor(index == 0 ? DS.fgStrong : DS.fgPale, for: .normal)
        allButton.setTitleColor(index == 1 ? DS.fgStrong : DS.fgPale, for: .normal)
        todayIndicator.backgroundColor = index == 0 ? DS.blue : .clear
        allIndicator.backgroundColor = index == 1 ? DS.blue : .clear

        // 자식 VC 교체
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }

        let childVC: UIViewController
        if index == 0 {
            if todayVC == nil { todayVC = TodayViewController() }
            childVC = todayVC!
        } else {
            if allEntriesVC == nil { allEntriesVC = AllEntriesViewController() }
            childVC = allEntriesVC!
        }

        addChild(childVC)
        containerView.addSubview(childVC.view)
        childVC.view.frame = containerView.bounds
        childVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        childVC.didMove(toParent: self)

        view.bringSubviewToFront(segmentBar)
    }

    @objc private func todayTapped() {
        showTab(0)
    }

    @objc private func allTapped() {
        showTab(1)
    }
}
