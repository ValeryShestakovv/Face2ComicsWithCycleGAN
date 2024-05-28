//
//  File.swift
//  GAN_for_IOS
//
//  Created by Jarvis on 22.05.2024.
//

import Foundation
import UIKit

protocol ViewTappedDelegate: AnyObject {
    func getTorchCaptureButton() -> Bool
    func takePhoto()
    func takeVideo(isEnabled: Bool)
    func realtimeRender(isEnabled: Bool)
   }

final class CollectionCellView: UICollectionViewCell, UIGestureRecognizerDelegate {
    static let reuseId = "CollectionCellView"
    weak var delegate : ViewTappedDelegate?
    var imageView = UIImageView()
    var effect = VideoEffects.noise
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    func setupUI() {
        self.contentView.addSubview(imageView)
        self.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = self.frame.size.width / 2
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.orange.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                            action: #selector(tapCell(recognizer:)))
        tapGesture.delegate = self
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGesture)
        
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(longTapCell(recognizer:)))
        imageView.addGestureRecognizer(longGesture)
    }
    
    @objc func tapCell(recognizer:UITapGestureRecognizer) {
        guard let torch = delegate?.getTorchCaptureButton() else { return }
        if torch {
            return
        } else {
            delegate?.takePhoto()
        }
    }
    
    @objc func longTapCell(recognizer:UILongPressGestureRecognizer) {
        guard let torch = delegate?.getTorchCaptureButton() else { return }
        if torch {
            return
        } else {
            if recognizer.state == UIGestureRecognizer.State.began {
                delegate?.takeVideo(isEnabled: true)
             }
            else if recognizer.state == UIGestureRecognizer.State.ended {
                delegate?.takeVideo(isEnabled: false)
             }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

