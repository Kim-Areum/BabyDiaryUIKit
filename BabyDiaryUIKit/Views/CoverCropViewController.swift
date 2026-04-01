import UIKit

class CoverCropViewController: UIViewController, UIScrollViewDelegate {

    private let image: UIImage
    private let aspectRatio: CGFloat // width / height
    var onSave: ((UIImage) -> Void)?

    private let cropScrollView = UIScrollView()
    private let imageView = UIImageView()
    private let cropFrameView = UIView()

    init(image: UIImage, aspectRatio: CGFloat = 94.0 / 128.0) {
        self.image = image
        self.aspectRatio = aspectRatio
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupNavBar()
        setupCropArea()
        setupHint()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureCropZoom()
    }

    // MARK: - Nav Bar

    private func setupNavBar() {
        let navContainer = UIView()
        navContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navContainer)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "사진 편집"
        titleLabel.font = DS.font(15)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = UIButton(type: .system)
        saveButton.setTitle("저장", for: .normal)
        saveButton.titleLabel?.font = DS.font(13)
        saveButton.setTitleColor(DS.fgStrong, for: .normal)
        saveButton.backgroundColor = DS.blue
        saveButton.layer.cornerRadius = 15
        saveButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        navContainer.addSubview(closeButton)
        navContainer.addSubview(titleLabel)
        navContainer.addSubview(saveButton)

        NSLayoutConstraint.activate([
            navContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navContainer.heightAnchor.constraint(equalToConstant: 48),

            closeButton.leadingAnchor.constraint(equalTo: navContainer.leadingAnchor, constant: 20),
            closeButton.centerYAnchor.constraint(equalTo: navContainer.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: navContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navContainer.centerYAnchor),

            saveButton.trailingAnchor.constraint(equalTo: navContainer.trailingAnchor, constant: -20),
            saveButton.centerYAnchor.constraint(equalTo: navContainer.centerYAnchor),
        ])
    }

    // MARK: - Crop Area

    private func setupCropArea() {
        let screenW = UIScreen.main.bounds.width
        let cropW = screenW * 0.8
        let cropH = cropW / aspectRatio

        // Scroll view for pan/zoom
        cropScrollView.delegate = self
        cropScrollView.showsHorizontalScrollIndicator = false
        cropScrollView.showsVerticalScrollIndicator = false
        cropScrollView.bouncesZoom = true
        cropScrollView.clipsToBounds = true
        cropScrollView.layer.cornerRadius = 8
        cropScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cropScrollView)

        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        cropScrollView.addSubview(imageView)

        // Crop frame border
        cropFrameView.layer.cornerRadius = 8
        cropFrameView.layer.borderWidth = 1
        cropFrameView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        cropFrameView.isUserInteractionEnabled = false
        cropFrameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cropFrameView)

        NSLayoutConstraint.activate([
            cropScrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cropScrollView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cropScrollView.widthAnchor.constraint(equalToConstant: cropW),
            cropScrollView.heightAnchor.constraint(equalToConstant: cropH),

            cropFrameView.topAnchor.constraint(equalTo: cropScrollView.topAnchor),
            cropFrameView.leadingAnchor.constraint(equalTo: cropScrollView.leadingAnchor),
            cropFrameView.trailingAnchor.constraint(equalTo: cropScrollView.trailingAnchor),
            cropFrameView.bottomAnchor.constraint(equalTo: cropScrollView.bottomAnchor),
        ])
    }

    private func configureCropZoom() {
        let cropSize = cropScrollView.bounds.size
        guard cropSize.width > 0, cropSize.height > 0 else { return }

        let imgSize = image.size
        let imgAspect = imgSize.width / imgSize.height
        let cropAspect = cropSize.width / cropSize.height

        // Fill 기준 이미지 크기
        var fitSize: CGSize
        if imgAspect > cropAspect {
            fitSize = CGSize(width: cropSize.height * imgAspect, height: cropSize.height)
        } else {
            fitSize = CGSize(width: cropSize.width, height: cropSize.width / imgAspect)
        }

        imageView.frame = CGRect(origin: .zero, size: fitSize)
        cropScrollView.contentSize = fitSize
        cropScrollView.minimumZoomScale = 1.0
        cropScrollView.maximumZoomScale = 5.0
        cropScrollView.zoomScale = 1.0

        // Center image
        let offsetX = max(0, (fitSize.width - cropSize.width) / 2)
        let offsetY = max(0, (fitSize.height - cropSize.height) / 2)
        cropScrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)
    }

    private func setupHint() {
        let hintLabel = UILabel()
        hintLabel.text = "핀치로 확대/축소, 드래그로 위치 조정"
        hintLabel.font = DS.font(10)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
        ])
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let cropSize = cropScrollView.bounds.size
        let scale = UIScreen.main.scale

        let renderer = UIGraphicsImageRenderer(size: cropSize)
        let cropped = renderer.image { _ in
            let zoomScale = cropScrollView.zoomScale
            let offset = cropScrollView.contentOffset

            let drawSize = CGSize(
                width: imageView.frame.width,
                height: imageView.frame.height
            )
            let drawOrigin = CGPoint(x: -offset.x, y: -offset.y)
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }

        onSave?(cropped)
        dismiss(animated: true)
    }
}
