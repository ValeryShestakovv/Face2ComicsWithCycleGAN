import UIKit

final class TopBarView: UIView {

    lazy var flashButton: UIButton = {
        let button = UIButton()
        button.tintColor = .white
        button.backgroundColor = .clear
        button.setImage(UIImage(systemName: "bolt.circle.fill", withConfiguration: UIImage.SymbolConfiguration.init(pointSize: 30)), for: .normal)
        button.imageView?.contentMode = .scaleToFill
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        return button
    }()
    
    lazy var previewButton: UIButton = {
        let button = UIButton()
        button.tintColor = .white
        button.backgroundColor = .clear
        button.setImage(UIImage(systemName: "rt.circle.fill", withConfiguration: UIImage.SymbolConfiguration.init(pointSize: 30)), for: .normal)
        button.imageView?.contentMode = .scaleToFill
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(togglePreview), for: .touchUpInside)
        return button
    }()

    var isTorchOnFlash = false {
        didSet {
            if isTorchOnFlash {
                flashButton.tintColor = .orange
            } else {
                flashButton.tintColor = .white
            }
        }
    }
    
    var isTorchOnPreview = false {
        didSet {
            if isTorchOnPreview {
                previewButton.tintColor = .orange
            } else {
                previewButton.tintColor = .white
            }
        }
    }

    weak var delegate: BottomBarDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpUI() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(flashButton)
        addSubview(previewButton)
        
        flashButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12).isActive = true
        flashButton.topAnchor.constraint(equalTo: topAnchor, constant: 50).isActive = true
        flashButton.widthAnchor.constraint(equalToConstant: 35).isActive = true
        flashButton.heightAnchor.constraint(equalToConstant: 35).isActive = true
        
        previewButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12).isActive = true
        previewButton.topAnchor.constraint(equalTo: topAnchor, constant: 50).isActive = true
        previewButton.widthAnchor.constraint(equalToConstant: 35).isActive = true
        previewButton.heightAnchor.constraint(equalToConstant: 35).isActive = true
    }

    @objc private func toggleFlash(_ sender: UIButton) {
        isTorchOnFlash.toggle()
    }
    @objc private func togglePreview(_ sender: UIButton) {
        isTorchOnPreview.toggle()
        delegate?.realtimeRender(isEnabled: isTorchOnPreview)
    }
}
