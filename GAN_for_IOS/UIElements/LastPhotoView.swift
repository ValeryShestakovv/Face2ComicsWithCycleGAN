import UIKit

final class LastPhotoView: UIView {

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .lavanda
        layer.cornerRadius = 10
        addSubview(imageView)

        imageView.topAnchor.constraint(equalTo: topAnchor, constant: 2).isActive = true
        imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2).isActive = true
        imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2).isActive = true
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2).isActive = true
    }
}
