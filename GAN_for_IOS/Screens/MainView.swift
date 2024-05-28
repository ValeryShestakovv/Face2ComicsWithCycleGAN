import Foundation
import UIKit
import Lottie
import CoreVideo
import AVFoundation
import AVKit
import AnimatedCollectionViewLayout

final class MainView: UIViewController, UIImagePickerControllerDelegate {
    private lazy var logoImageView: UIImageView = {
        var imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityIdentifier = "logo"
        return imageView
    }()
    lazy var imageView: UIImageView = {
        var imageView = UIImageView()
        imageView.image = UIImage(named: "test")
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.image = UIImage(named: "default_image")
        imageView.contentMode = .scaleAspectFill
        imageView.accessibilityIdentifier = "default_image"
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    private lazy var savePhotoButton: UIButton = {
        let button =  UIButton()
        button.setTitle("Save photo in gallery", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setBackgroundImage(UIImage(named: "button"), for: .normal)
        button.setImage(UIImage(systemName: "arrow.down.circle"), for: .normal)
        button.tintColor = .white
        button.isEnabled = false
        button.alpha = 0
        return button
    }()
    private lazy var saveVideoButton: UIButton = {
        let button =  UIButton()
        button.setTitle("Save video in gallery", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setBackgroundImage(UIImage(named: "button"), for: .normal)
        button.setImage(UIImage(systemName: "arrow.down.circle"), for: .normal)
        button.tintColor = .white
        button.isEnabled = false
        button.alpha = 0
        return button
    }()
        
    private let loadingView = LottieAnimationView(name: "loading")
    
    private lazy var bottomBar = BottomBarView()
    private lazy var topBar = TopBarView()
    
    let viewModel: MainViewModel
    
    var arrayEffect = [EffectModel(image: UIImage(named: "comics")!, effect: .comics), EffectModel(image: UIImage(named: "anime")!, effect: .anime), EffectModel(image: UIImage(named: "simpson")!, effect: .simpson)]
    
    private var layout = AnimatedCollectionViewLayout()
    private lazy var collectionView: UICollectionView = {
        layout.animator = LinearCardAttributesAnimator(minAlpha: 0.1, itemSpacing: 0.3, scaleRate: 1.0)
        layout.minimumLineSpacing = Layout.galleryMinimumLineSpacing
        layout.scrollDirection = .horizontal
        layout.sectionInset = .init(top: 0, left: Layout.horizontalInset, bottom: 0, right: Layout.horizontalInset)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: Layout.leftDistanceToView,
                                                   bottom: 0, right: Layout.rightDistanceToView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceHorizontal = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CollectionCellView.self, forCellWithReuseIdentifier: "\(CollectionCellView.self)")
        
        return collectionView
    }()
        
    var isTorchOnCaptureButton = false {
        didSet {
            if isTorchOnCaptureButton {
                bottomBar.captureImageButton.backgroundColor = .gray
                bottomBar.captureImageButton.layer.borderColor = UIColor.lavanda_clear.cgColor
                collectionView.alpha = 0.5
            } else {
                bottomBar.captureImageButton.backgroundColor = .white
                bottomBar.captureImageButton.layer.borderColor = UIColor.lavanda.cgColor
                collectionView.alpha = 1
            }
        }
    }
    
    private var topSavePhotoButtonConstraint: NSLayoutConstraint?
    private var topSaveVideoButtonConstraint: NSLayoutConstraint?
    
    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.viewModel.delegate = self
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "background.png")!)
        checkPermissions()
        createIU()
        savePhotoButton.addTarget(self, action: #selector(saveImage), for: .touchUpInside)
        saveVideoButton.addTarget(self, action: #selector(saveVideo), for: .touchUpInside)
    }
    
    private func createIU() {
        view.addSubview(logoImageView)
        view.addSubview(imageView)
        view.addSubview(bottomBar)
        view.addSubview(topBar)
        view.addSubview(savePhotoButton)
        view.addSubview(saveVideoButton)
        view.addSubview(loadingView)
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            self.collectionView.leadingAnchor.constraint(equalTo: bottomBar.lastPhotoView.trailingAnchor),
            self.collectionView.trailingAnchor.constraint(equalTo: bottomBar.switchCameraButton.leadingAnchor),
            self.collectionView.heightAnchor.constraint(equalToConstant: 90),
            self.collectionView.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])
        
        loadingView.isHidden = true
        loadingView.loopMode = .loop
        
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        savePhotoButton.translatesAutoresizingMaskIntoConstraints = false
        saveVideoButton.translatesAutoresizingMaskIntoConstraints = false
        
        bottomBar.delegate = self
        topBar.delegate = self
        
        logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -10).isActive = true
        logoImageView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 90).isActive = true
        logoImageView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -90).isActive = true
        logoImageView.heightAnchor.constraint(equalToConstant: view.frame.height / 5).isActive = true
        
        imageView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 25).isActive = true
        imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: view.frame.height / 2.5).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: view.frame.height / 2.5).isActive = true
        
        let topSavePhotoButtonConstraint = savePhotoButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 50)
        topSavePhotoButtonConstraint.isActive = true
        savePhotoButton.leftAnchor.constraint(equalTo: imageView.leftAnchor, constant: 20).isActive = true
        savePhotoButton.rightAnchor.constraint(equalTo: imageView.rightAnchor, constant: -20).isActive = true
        savePhotoButton.heightAnchor.constraint(equalToConstant: view.frame.height / 20).isActive = true
        
        let topSaveVideoButtonConstraint = saveVideoButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 50)
        topSaveVideoButtonConstraint.isActive = true
        saveVideoButton.leftAnchor.constraint(equalTo: imageView.leftAnchor, constant: 20).isActive = true
        saveVideoButton.rightAnchor.constraint(equalTo: imageView.rightAnchor, constant: -20).isActive = true
        saveVideoButton.heightAnchor.constraint(equalToConstant: view.frame.height / 20).isActive = true
        
        bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        bottomBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.23).isActive = true
        
        topBar.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        topBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.14).isActive = true
        
        loadingView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20).isActive = true
        loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        loadingView.widthAnchor.constraint(equalToConstant: view.frame.height / 2.5).isActive = true
        loadingView.heightAnchor.constraint(equalToConstant: view.frame.height / 2.5).isActive = true
        
        viewModel.effect = .comics
    }
    
    
    @objc private func saveImage() {
        guard let image = imageView.image else {
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(alertSaveImageToAlbum(_ :didFinishSavingWithError:contextInfo:)), nil)
        self.setPhoto(image: image)
        viewModel.renderCameraPreview = true
        self.savePhotoButton.isEnabled = false
        
        topSavePhotoButtonConstraint?.isActive = false
        topSavePhotoButtonConstraint = savePhotoButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 50)
        topSavePhotoButtonConstraint?.isActive = true
        UIView.animate(withDuration: 0.5) {
            self.savePhotoButton.alpha = 0
            self.view.layoutIfNeeded()
        }
    }
    @objc private func saveVideo() {
        viewModel.saveVideoInLibrary()
        
        viewModel.renderCameraPreview = true
        for subview in imageView.subviews {
            if let viewWithTag = subview.viewWithTag(1) {
                    viewWithTag.removeFromSuperview()
                }
        }
        self.saveVideoButton.isEnabled = false
        topSaveVideoButtonConstraint?.isActive = false
        topSaveVideoButtonConstraint = saveVideoButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 50)
        topSaveVideoButtonConstraint?.isActive = true
        UIView.animate(withDuration: 0.5) {
            self.saveVideoButton.alpha = 0
            self.view.layoutIfNeeded()
        }
    }
    @objc private func alertSaveImageToAlbum(_ image:UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
    }
}

extension MainView: BottomBarDelegate {

    func switchCamera() {
        viewModel.switchCameraInput()

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func realtimeRender(isEnabled: Bool) {
        viewModel.realtimeRender = isEnabled
        isTorchOnCaptureButton.toggle()
    }
    
}

extension MainView : ViewTappedDelegate {
    
    func getTorchCaptureButton() -> Bool {
        return isTorchOnCaptureButton
    }
    
    func takePhoto() {
        viewModel.renderCameraPreview = false
        topSavePhotoButtonConstraint?.isActive = false
        topSavePhotoButtonConstraint = savePhotoButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20)
        topSavePhotoButtonConstraint?.isActive = true
        UIView.animate(withDuration: 1.0) {
            self.loadingView.isHidden = false
            self.savePhotoButton.alpha = 1
            self.view.layoutIfNeeded()
        }
        
        loadingView.play()
        guard let frame = viewModel.cvPixelBuffer else { return }
        DispatchQueue.main.async {
            guard let resultFrame = self.viewModel.generateFrame(frame: frame) else { return }
            let ciimage = CIImage(cvPixelBuffer: resultFrame).oriented(CGImagePropertyOrientation.right)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciimage, from: ciimage.extent) else { return }
            let image = UIImage(cgImage: cgImage)
            self.imageView.image = image
            self.loadingView.stop()
            self.loadingView.isHidden = true
            self.savePhotoButton.isEnabled = true
        }
    }
    
    func takeVideo(isEnabled: Bool) {
        viewModel.recordVideoIsRun = isEnabled
        
        if isEnabled == false {
            topSaveVideoButtonConstraint?.isActive = false
            topSaveVideoButtonConstraint = saveVideoButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20)
            topSaveVideoButtonConstraint?.isActive = true
            UIView.animate(withDuration: 1.0) {
                self.loadingView.isHidden = false
                self.saveVideoButton.alpha = 1
                self.view.layoutIfNeeded()
            }
            loadingView.play()
            self.saveVideoButton.isEnabled = true
        }
    }
}
    
extension MainView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return arrayEffect.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "\(CollectionCellView.self)", for: indexPath) as! CollectionCellView
        let model = arrayEffect[indexPath.row]
        cell.imageView.image = model.image
        cell.delegate = self
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 74, height: 74)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView is UICollectionView else {
            return
        }
        let centerPoint = CGPoint(x: scrollView.frame.size.width / 2 + scrollView.contentOffset.x,
                                  y: scrollView.frame.size.height / 2 + scrollView.contentOffset.y)
        guard
            let indexPath = collectionView.indexPathForItem(at: centerPoint),
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CollectionCellView.reuseId,
                for: indexPath) as? CollectionCellView else {
                return
            }
        let model = arrayEffect[indexPath.row]
        viewModel.effect = model.effect
    }

}

extension MainView: MainViewModelDelegate {

    func setPhoto(image: UIImage) {
        bottomBar.setUpPhoto(image: image)
    }
    
    func playVideo(_ url: URL) {
        loadingView.stop()
        loadingView.isHidden = true
        let videoLauncher = VideoPlayerView(frame: imageView.bounds, url: url)
        videoLauncher.tag = 1
        imageView.addSubview(videoLauncher)
    }
}

extension MainView {

    private func checkPermissions() {
        let cameraAuthStatus =  AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch cameraAuthStatus {
        case .authorized:
            return
        case .denied:
            abort()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler:
                                            { (authorized) in
                if(!authorized){
                    abort()
                }
            })
        case .restricted:
            abort()
        @unknown default:
            fatalError()
        }
    }
}

extension MainView {
    enum Layout {
        static var horizontalTextInset: CGFloat { 85 }
        static var horizontalInset: CGFloat { UIScreen.main.bounds.width / 4.14 }
        static var verticalInset: CGFloat { 80 }
        static var leftDistanceToView: CGFloat { 0 }
        static var rightDistanceToView: CGFloat { 0 }
        static var galleryMinimumLineSpacing: CGFloat { UIScreen.main.bounds.width / 2.07 }
        static var galleryItemWidth: CGFloat {
            if UIDevice.current.orientation.isLandscape {
                return UIScreen.main.bounds.width / 2
            } else {
                return UIScreen.main.bounds.width
            }
        }
        static var galleryItemHeight: CGFloat {
            if UIDevice.current.orientation.isLandscape {
                return UIScreen.main.bounds.height
            } else {
                return UIScreen.main.bounds.height - 150
            }
        }
    }
}
