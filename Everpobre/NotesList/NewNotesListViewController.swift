//
//  NewNotesListViewController.swift
//  Everpobre
//
//  Created by Charles Moncada on 11/10/18.
//  Copyright © 2018 Charles Moncada. All rights reserved.
//

import UIKit
import CoreData
import MapKit

extension NewNotesListViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            centerMap(at: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("user's location error: \(error.localizedDescription)")
    }
    
    private func centerMap(at center: CLLocationCoordinate2D) {
        let regionRadius: CLLocationDistance = 1000
        let region = MKCoordinateRegion(center: center, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
        mapView.setRegion(region, animated: true)
    }
}

extension NewNotesListViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? Note else { return nil }
        
        let identifier = "note"
        var view: MKMarkerAnnotationView
        
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
            dequeuedView.annotation = annotation
            view = dequeuedView
        } else {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = true
        }
        
        view.markerTintColor = .red
        view.titleVisibility = .visible
        view.subtitleVisibility = .adaptive

        return view
    }
}

extension Note: MKAnnotation {
    public var coordinate: CLLocationCoordinate2D {
        guard let location = self.location else { return kCLLocationCoordinate2DInvalid }
        return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
}

class NewNotesListViewController: UIViewController {
    
	// MARK: IBOutlets
    
	@IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var mapView: MKMapView!
    
    // MARK: Properties

	let notebook: Notebook
	//let managedContext: NSManagedObjectContext
	let coreDataStack: CoreDataStack!
    let locationManager = CLLocationManager()

	var notes: [Note] = [] {
		didSet {
			self.collectionView.reloadData()
		}
	}

	let transition = Animator()

	// MARK: Init

	init(notebook: Notebook, coreDataStack: CoreDataStack) {
		self.notebook = notebook
		self.notes = (notebook.notes?.array as? [Note]) ?? []
		self.coreDataStack = coreDataStack
		super.init(nibName: "NewNotesListViewController", bundle: nil)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()
        self.mapView.isHidden = true
        self.collectionView.isHidden = false
        print("NewNotesListViewController")
		title = "Notas"
		self.view.backgroundColor = .white

		let nib = UINib(nibName: "NotesListCollectionViewCell", bundle: nil)
		collectionView.register(nib, forCellWithReuseIdentifier: "NotesListCollectionViewCell")

		collectionView.backgroundColor = .lightGray

		let addButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNote))
		let exportButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(exportCSV))

		self.navigationItem.rightBarButtonItems = [addButtonItem, exportButtonItem]
        
        setupLocationInMapView()
	}

    // MARK: Helper methods
    
    private func setupLocationInMapView() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestLocation()
        mapView.showsUserLocation = true
        mapView.userLocation.title = nil
        mapView.delegate = self
        
        mapView.addAnnotations(notes)
    }
    
	@objc private func exportCSV() {

		coreDataStack.storeContainer.performBackgroundTask { [unowned self] context in

			var results: [Note] = []

			do {
				results = try self.coreDataStack.managedContext.fetch(self.notesFetchRequest(from: self.notebook))
			} catch let error as NSError {
				print("Error: \(error.localizedDescription)")
			}

			let exportPath = NSTemporaryDirectory() + "export.csv"
			let exportURL = URL(fileURLWithPath: exportPath)
			FileManager.default.createFile(atPath: exportPath, contents: Data(), attributes: nil)

			let fileHandle: FileHandle?
			do {
				fileHandle = try FileHandle(forWritingTo: exportURL)
			} catch let error as NSError {
				print(error.localizedDescription)
				fileHandle = nil
			}

			if let fileHandle = fileHandle {
				for note in results {
					fileHandle.seekToEndOfFile()
					guard let csvData = note.csv().data(using: .utf8, allowLossyConversion: false) else { return }
					fileHandle.write(csvData)
				}

				fileHandle.closeFile()
				DispatchQueue.main.async { [weak self] in
					self?.showExportFinishedAlert(exportPath)
				}

			} else {
				print("no podemos exportar la data")
			}
		}

	}

	private func showExportFinishedAlert(_ exportPath: String) {
		let message = "El archivo CSV se encuentra en \(exportPath)"
		let alertController = UIAlertController(title: "Exportacion terminada", message: message, preferredStyle: .alert)
		let dismissAction = UIAlertAction(title: "Dismiss", style: .default)
		alertController.addAction(dismissAction)

		present(alertController, animated: true)
	}

	private func notesFetchRequest(from notebook: Notebook) -> NSFetchRequest<Note> {
		let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
		//fetchRequest.fetchBatchSize = 50
		fetchRequest.predicate = NSPredicate(format: "notebook == %@", notebook)
		fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

		return fetchRequest
	}

	@objc private func addNote() {
		let newNoteVC = NoteDetailsViewController(kind: .new(notebook: notebook), managedContext: coreDataStack.managedContext)
		newNoteVC.delegate = self
		let navVC = UINavigationController(rootViewController: newNoteVC)
		self.present(navVC, animated: true, completion: nil)
	}
    
    // MARK: - IBAction Segmented Control
    
    @IBAction func indexChanged(_ sender: UISegmentedControl) {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            print("First Segment Selected")
            self.mapView.isHidden = true
            self.collectionView.isHidden = false
        case 1:
            print("Second Segment Selected")
            self.mapView.isHidden = false
            self.collectionView.isHidden = true
        default:
            break
        }
    }

}

// MARK:- UICollectionViewDataSource

extension NewNotesListViewController: UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return notes.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NotesListCollectionViewCell", for: indexPath) as! NotesListCollectionViewCell
		cell.configure(with: notes[indexPath.row])
		return cell
	}

}

// MARK:- UICollectionViewDelegate

extension NewNotesListViewController: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let detailVC = NoteDetailsViewController(kind: .existing(note: notes[indexPath.row]), managedContext: coreDataStack.managedContext)
		detailVC.delegate = self
		//self.show(detailVC, sender: nil)

		// custom animation
		let navVC = UINavigationController(rootViewController: detailVC)
		navVC.transitioningDelegate = self
		present(navVC, animated: true, completion: nil)

	}
}

// MARK:- UICollectionViewDelegateFlowLayout

extension NewNotesListViewController: UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		return CGSize(width: 100, height: 150)
	}
}

// MARK:- NoteDetailsViewControllerProtocol implementation

extension NewNotesListViewController: NoteDetailsViewControllerProtocol {
	func didSaveNote() {
		self.notes = (notebook.notes?.array as? [Note]) ?? []
	}
}

// MARK:- Custom Animation - UIViewControllerTransitioningDelegate

extension NewNotesListViewController: UIViewControllerTransitioningDelegate {

	func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		let indexPath = (collectionView.indexPathsForSelectedItems?.first!)!
		let cell = collectionView.cellForItem(at: indexPath)
		transition.originFrame = cell!.superview!.convert(cell!.frame, to: nil)

		transition.presenting = true

		return transition
	}

	func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		return nil
	}
}
