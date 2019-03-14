//
//  NotesListCollectionViewCell.swift
//  Everpobre
//
//  Created by Charles Moncada on 11/10/18.
//  Copyright © 2018 Charles Moncada. All rights reserved.
//

import UIKit

class NotesListCollectionViewCell: UICollectionViewCell {

	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var creationDateLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
	var item: Note!

	override func awakeFromNib() {
		super.awakeFromNib()
	}

	func configure(with item: Note) {
		backgroundColor = .white
		titleLabel.text = item.title
		creationDateLabel.text = (item.creationDate as Date?)?.customStringLabel()
        guard let imageDate = item.image,
        let image = UIImage(data: imageDate as Data) else {
            imageView.image = UIImage(named: "120x180")
            return
        }

        imageView.image = image
	}
}
