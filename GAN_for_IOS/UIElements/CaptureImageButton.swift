import UIKit

final class CaptureImageButton: UIView {

    override var intrinsicContentSize: CGSize {
        CGSize(width: 82, height: 82)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.cornerRadius = intrinsicContentSize.height / 2
        layer.borderWidth = 4
        layer.borderColor = UIColor.lavanda.cgColor
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
