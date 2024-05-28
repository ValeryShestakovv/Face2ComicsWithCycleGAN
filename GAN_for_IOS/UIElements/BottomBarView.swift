import UIKit

protocol BottomBarDelegate: AnyObject {
    
    func switchCamera()
    func takePhoto()
    func takeVideo(isEnabled: Bool)
    func realtimeRender(isEnabled: Bool)
}

final class BottomBarView: UIView {

    lazy var captureImageButton = CaptureImageButton()
    
    lazy var switchCameraButton: UIButton = {
        let button = UIButton()
        button.tintColor = .white
        button.backgroundColor = .lavanda.withAlphaComponent(0.2)
        button.setImage(UIImage(systemName: "arrow.triangle.2.circlepath", withConfiguration: UIImage.SymbolConfiguration.init(pointSize: 25)), for: .normal)
        button.imageView?.contentMode = .scaleAspectFill
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    lazy var lastPhotoView = LastPhotoView()
    
    weak var delegate: BottomBarDelegate?

    override init(frame: CGRect) {
        super.init(frame: .zero)

        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpUI() {
        addSubview(captureImageButton)
        addSubview(lastPhotoView)
        addSubview(switchCameraButton)
        
        translatesAutoresizingMaskIntoConstraints = false

        captureImageButton.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        captureImageButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        lastPhotoView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        lastPhotoView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        lastPhotoView.widthAnchor.constraint(equalToConstant: 50).isActive = true
        lastPhotoView.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        switchCameraButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20).isActive = true
        switchCameraButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        switchCameraButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
        switchCameraButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(openLibrary))
        lastPhotoView.addGestureRecognizer(recognizer)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
               
    }

    @objc private func switchCamera() {
        delegate?.switchCamera()
    }
    
    @objc private func openLibrary() {
        UIApplication.shared.open(URL(string:"photos-redirect://")!)
    }

    func setUpPhoto(image: UIImage) {
        lastPhotoView.imageView.image = image
    }
}
