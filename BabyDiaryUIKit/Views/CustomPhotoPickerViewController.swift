import UIKit
import Photos

protocol CustomPhotoPickerDelegate: AnyObject {
    func photoPicker(_ picker: CustomPhotoPickerViewController, didSelect image: UIImage)
}

class CustomPhotoPickerViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    weak var delegate: CustomPhotoPickerDelegate?
    private var targetDate: Date?

    private var categories: [PhotoCategory] = []
    private var selectedCategory: PhotoCategory?
    private var photos: [PHAsset] = []
    private var selectedAsset: PHAsset?
    private var fetchResult: PHFetchResult<PHAsset>?
    private var loadedCount = 0
    private let pageSize = 100

    private var collectionView: UICollectionView!
    private let categoryScrollView = UIScrollView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    init(date: Date? = nil) {
        self.targetDate = date
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DS.bgBase
        setupNavBar()
        setupCategoryBar()
        setupCollectionView()
        setupLoading()
        loadPhotos()
    }

    private func setupNavBar() {
        let navBar = NavBarView()
        navBar.titleLabel.text = "사진 선택"
        navBar.leftButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        navBar.leftButton.tintColor = DS.fgStrong
        navBar.leftButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let doneButton = UIButton(type: .system)
        doneButton.setTitle("완료", for: .normal)
        doneButton.titleLabel?.font = DS.font(13)
        doneButton.setTitleColor(DS.fgPale, for: .normal)
        doneButton.backgroundColor = DS.bgNeutral
        doneButton.layer.cornerRadius = 15
        doneButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.tag = 999
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(doneButton)
        navBar.rightButton.isHidden = true

        NSLayoutConstraint.activate([
            doneButton.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -20),
            doneButton.centerYAnchor.constraint(equalTo: navBar.titleLabel.centerYAnchor),
        ])

        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        navBar.tag = 100

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupCategoryBar() {
        categoryScrollView.showsHorizontalScrollIndicator = false
        categoryScrollView.translatesAutoresizingMaskIntoConstraints = false
        categoryScrollView.backgroundColor = DS.bgBase
        view.addSubview(categoryScrollView)

        let navBar = view.viewWithTag(100)!
        NSLayoutConstraint.activate([
            categoryScrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            categoryScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryScrollView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func setupCollectionView() {
        let spacing: CGFloat = 2
        let columns = 3
        let itemSize = (UIScreen.main.bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: itemSize, height: itemSize)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.backgroundColor = DS.bgBase
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: categoryScrollView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupLoading() {
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = DS.fgPale
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        loadingIndicator.startAnimating()
    }

    private func loadPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            loadCategories()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] s in
                DispatchQueue.main.async {
                    if s == .authorized || s == .limited {
                        self?.loadCategories()
                    }
                }
            }
        default: break
        }
    }

    private func fetchAssetsForDate(_ date: Date) -> PHFetchResult<PHAsset> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(with: .image, options: opts)
    }

    private func loadCategories() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            var cats: [PhotoCategory] = []

            // 오늘 날짜 사진 탭
            if let date = self.targetDate {
                let assets = self.fetchAssetsForDate(date)
                if assets.count > 0 {
                    cats.append(.dateMemory(date))
                }
            }

            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            smartAlbums.enumerateObjects { collection, _, _ in
                let opts = PHFetchOptions()
                opts.fetchLimit = 1
                if PHAsset.fetchAssets(in: collection, options: opts).count > 0 {
                    cats.append(.album(collection))
                }
            }

            let priority: [PHAssetCollectionSubtype] = [
                .smartAlbumUserLibrary, .smartAlbumFavorites, .smartAlbumRecentlyAdded,
                .smartAlbumScreenshots, .smartAlbumSelfPortraits, .smartAlbumLivePhotos
            ]
            cats.sort { a, b in
                guard case .album(let c1) = a, case .album(let c2) = b else { return false }
                let i1 = priority.firstIndex(of: c1.assetCollectionSubtype) ?? Int.max
                let i2 = priority.firstIndex(of: c2.assetCollectionSubtype) ?? Int.max
                return i1 < i2
            }

            DispatchQueue.main.async {
                self.categories = cats
                self.updateCategoryButtons()
                if let first = cats.first {
                    self.selectCategory(first)
                }
                self.loadingIndicator.stopAnimating()
            }
        }
    }

    private func updateCategoryButtons() {
        categoryScrollView.subviews.forEach { $0.removeFromSuperview() }
        var x: CGFloat = 8
        for (index, cat) in categories.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(cat.title, for: .normal)
            btn.titleLabel?.font = DS.font(13)
            btn.setTitleColor(selectedCategory == cat ? DS.fgStrong : DS.fgPale, for: .normal)
            btn.tag = index
            btn.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            btn.sizeToFit()
            btn.frame = CGRect(x: x, y: 0, width: btn.frame.width + 20, height: 40)
            categoryScrollView.addSubview(btn)
            x += btn.frame.width
        }
        categoryScrollView.contentSize = CGSize(width: x + 8, height: 40)
    }

    private func selectCategory(_ cat: PhotoCategory) {
        selectedCategory = cat
        loadedCount = 0
        photos = []

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        switch cat {
        case .dateMemory(let date):
            fetchResult = fetchAssetsForDate(date)
        case .album(let collection):
            fetchResult = PHAsset.fetchAssets(in: collection, options: opts)
        }

        loadMore()
        updateCategoryButtons()
    }

    private func loadMore() {
        guard let result = fetchResult, loadedCount < result.count else { return }
        let count = min(pageSize, result.count - loadedCount)
        for i in loadedCount..<loadedCount + count {
            photos.append(result.object(at: i))
        }
        loadedCount += count
        collectionView.reloadData()
    }

    // MARK: - UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        photos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let asset = photos[indexPath.item]
        cell.configure(with: asset, isSelected: asset == selectedAsset)

        if indexPath.item == photos.count - 1 {
            loadMore()
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = photos[indexPath.item]
        selectedAsset = selectedAsset == asset ? nil : asset
        collectionView.reloadData()

        // 완료 버튼 상태 업데이트
        if let navBar = view.viewWithTag(100), let doneBtn = navBar.viewWithTag(999) as? UIButton {
            let hasSelection = selectedAsset != nil
            doneBtn.setTitleColor(hasSelection ? DS.fgStrong : DS.fgPale, for: .normal)
            doneBtn.backgroundColor = hasSelection ? DS.blue : DS.bgNeutral
        }
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        let cat = categories[sender.tag]
        selectCategory(cat)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        guard let asset = selectedAsset else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1920, height: 1920), contentMode: .aspectFill, options: opts) { [weak self] img, _ in
            guard let self = self, let img = img else { return }
            DispatchQueue.main.async {
                self.delegate?.photoPicker(self, didSelect: img)
            }
        }
    }
}

// MARK: - PhotoCategory

enum PhotoCategory: Equatable {
    case dateMemory(Date)
    case album(PHAssetCollection)

    var id: String {
        switch self {
        case .dateMemory: return "dateMemory"
        case .album(let c): return c.localIdentifier
        }
    }

    var title: String {
        switch self {
        case .dateMemory(let date):
            let f = DateFormatter()
            f.locale = Locale.current
            f.setLocalizedDateFormatFromTemplate("MMMMd")
            return f.string(from: date)
        case .album(let c): return c.localizedTitle ?? "앨범"
        }
    }

    static func == (lhs: PhotoCategory, rhs: PhotoCategory) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - PhotoCell

class PhotoCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let overlay = UIView()
    private var requestID: PHImageRequestID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = DS.bgSubtle

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlay.isHidden = true
        contentView.addSubview(overlay)

        checkmark.tintColor = DS.blue
        checkmark.isHidden = true
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkmark)

        NSLayoutConstraint.activate([
            checkmark.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            checkmark.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            checkmark.widthAnchor.constraint(equalToConstant: 22),
            checkmark.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds
        overlay.frame = contentView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if let id = requestID {
            PHImageManager.default().cancelImageRequest(id)
        }
        imageView.image = nil
        overlay.isHidden = true
        checkmark.isHidden = true
    }

    func configure(with asset: PHAsset, isSelected: Bool) {
        let size = contentView.bounds.size
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true
        requestID = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: opts) { [weak self] img, _ in
            self?.imageView.image = img
        }

        overlay.isHidden = !isSelected
        checkmark.isHidden = !isSelected
    }
}
