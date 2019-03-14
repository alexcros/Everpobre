//
//  NoteDetailsViewController.swift
//  Everpobre
//
//  Created by Charles Moncada on 08/10/18.
//  Copyright © 2018 Charles Moncada. All rights reserved.
//

import UIKit
import CoreData

// MARK:- NoteDetailsViewControllerProtocol

protocol NoteDetailsViewControllerProtocol: class {
	func didSaveNote()
}

// MARK:- NoteDetailsViewController class

class NoteDetailsViewController: UIViewController {
    
    enum Tag: String, CaseIterable {
        case Personal = "Personal"
        case Todo = "Todo"
        case Info = "Info"
        case Otros = "Otros"
    }
    
	enum Kind {
		case new(notebook: Notebook)
		case existing(note: Note)
	}

    private var pickerView: UIPickerView = {
        var picker = UIPickerView()
        return picker
    }()

    // MARK: IBOutlets
	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var titleTextField: UITextField!
	//@IBOutlet weak var tagsLabel: UITextField!
    @IBOutlet weak var tagsTextField: UITextField!
	@IBOutlet weak var creationDateLabel: UILabel!
	@IBOutlet weak var lastSeenDateLabel: UILabel!
	@IBOutlet weak var descriptionTextView: UITextView!
    
	// MARK: Parameters

//	let note: Note
	let managedContext: NSManagedObjectContext
	let kind: Kind

	weak var delegate: NoteDetailsViewControllerProtocol?

	// MARK: Init

	init(kind: Kind, managedContext: NSManagedObjectContext) {
		self.kind = kind
		self.managedContext = managedContext
		super.init(nibName: "NoteDetailsViewController", bundle: nil)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpPickerView()
        setUpTextField()
		configure()
        
    }

	// MARK: IBAction

	@IBAction private func pickImage(_ sender: UIButton) {
		if UIImagePickerController.isSourceTypeAvailable(.camera) {
			showPhotoMenu()
		} else {
			choosePhotoFromLibrary()
		}
	}

	// MARK: Helper methods

	private func configure() {
		let saveButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveNote))
		self.navigationItem.rightBarButtonItem = saveButtonItem
		let cancelButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		self.navigationItem.leftBarButtonItem = cancelButtonItem

		title = kind.title
		titleTextField.text = kind.note?.title
        tagsTextField.text = kind.note?.tags
		creationDateLabel.text = "Created: \((kind.note?.creationDate as Date?)?.customStringLabel() ?? "ND")"
		lastSeenDateLabel.text = "Last seen: \((kind.note?.lastSeenDate as Date?)?.customStringLabel() ?? "ND")"
		descriptionTextView.text = kind.note?.text ?? "Ingrese texto..."

		guard let data = kind.note?.image as Data? else {
			imageView.image = #imageLiteral(resourceName: "120x180.png")
			return
		}

		imageView.image = UIImage(data: data)
	}

	@objc private func saveNote() {

		func addProperties(to note: Note) -> Note {
			note.title = titleTextField.text
			note.text = descriptionTextView.text
            note.tags = tagsTextField.text

			let imageData: NSData?
			if let image = imageView.image,
				let data = image.pngData() {
				imageData = NSData(data: data)
			} else { imageData = nil }
			note.image = imageData

			return note
		}

		switch kind {
		case .existing(let note):
			let modifiedNote = addProperties(to: note)
			modifiedNote.lastSeenDate = NSDate()

		case .new(let notebook):
			let note = Note(context: managedContext)
			let modifiedNote = addProperties(to: note)
			modifiedNote.creationDate = NSDate()
			modifiedNote.notebook = notebook

			if let notes = notebook.notes?.mutableCopy() as? NSMutableOrderedSet {
				notes.add(note)
				notebook.notes = notes
			}
		}

		do {
			try managedContext.save()
			delegate?.didSaveNote()
		} catch let error as NSError {
			print("error: \(error.localizedDescription)")
		}

		dismiss(animated: true, completion: nil)

	}

	@objc private func cancel() {
		dismiss(animated: true, completion: nil)
	}
    
    private func setUpPickerView() {
        pickerView.delegate = self
        pickerView.dataSource = self
    }
    
    private func setUpTextField() {
        tagsTextField.delegate = self
        tagsTextField.inputView = pickerView
    }
}

// MARK: - UIPickerViewDelegate

extension NoteDetailsViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Tag.allCases[row].rawValue
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        print(row)
        tagsTextField.text = Tag.allCases[row].rawValue
    }
}

// MARK: - UIPickerViewDataSource

extension NoteDetailsViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return Tag.allCases.count
    }
}

// MARK: - UITextFieldDelegate

extension NoteDetailsViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == self.tagsTextField {
            // Select the value in the picker from the text in the textField
            let row = Tag.allCases.firstIndex(where: { (tag) -> Bool in
                tag.rawValue == self.tagsTextField.text
            })
            
            if let row = row {
                pickerView.selectRow(row, inComponent: 0, animated: true)
            }
        }
    }
}

// MARK:- UIImagePickerControllerDelegate & related methods

extension NoteDetailsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		dismiss(animated: true, completion: nil)
	}

	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

		func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
			return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
		}

		func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
			return input.rawValue
		}

		let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

		let rawImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.editedImage)] as? UIImage

		let imageSize = CGSize(width: self.imageView.bounds.width * UIScreen.main.scale, height: self.imageView.bounds.height * UIScreen.main.scale)

		DispatchQueue.global(qos: .default).async {
			let image = rawImage?.resizedImageWithContentMode(.scaleAspectFill, bounds: imageSize, interpolationQuality: .high)

			DispatchQueue.main.async {
				if let image = image {
					self.imageView.contentMode = .scaleAspectFill
					self.imageView.clipsToBounds = true
					self.imageView.image = image
				}
			}
		}

		dismiss(animated: true, completion: nil)
	}

	private func showPhotoMenu() {
		let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		let takePhotoAction = UIAlertAction(title: "Take Photo", style: .default, handler: { _ in self.takePhotoWithCamera() })
		let chooseFromLibrary = UIAlertAction(title: "Choose From Library", style: .default, handler: { _ in self.choosePhotoFromLibrary() })

		alertController.addAction(cancelAction)
		alertController.addAction(takePhotoAction)
		alertController.addAction(chooseFromLibrary)

		present(alertController, animated: true, completion: nil)
	}

	private func choosePhotoFromLibrary() {
		let imagePicker = UIImagePickerController()
		imagePicker.sourceType = .photoLibrary
		imagePicker.delegate = self
		imagePicker.allowsEditing = true
		present(imagePicker, animated: true, completion: nil)
	}

	private func takePhotoWithCamera() {
		let imagePicker = UIImagePickerController()
		imagePicker.sourceType = .camera
		imagePicker.delegate = self
		imagePicker.allowsEditing = true
		present(imagePicker, animated: true, completion: nil)
	}
}

// MARK:- NoteDetailsViewController.Kind extension

private extension NoteDetailsViewController.Kind {
	var note: Note? {
		guard case let .existing(note) = self else { return nil }
		return note
	}

	var title: String {
		switch self {
		case .existing:
			return "Detalle"
		case .new:
			return "Nueva Nota"
		}
	}
}
