//
//  ViewController.swift
//  Customer
//
//  Created by naruto kurama on 16.05.2022.
//

import UIKit
import MapKit
import CoreLocation
import CoreData

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var txtCustomerName: UITextField!
    @IBOutlet weak var txtPhone: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var btnSave: UIButton!
    
    var locationManager = CLLocationManager()
    
    var chosenLatitude = Double()
    var chosenLongitude = Double()
    
    var selectedTitle = ""
    var selectedTitleID : UUID?
    
    var annotationTitle = ""
    var annotationSubtitle = ""
    var annotationLatitude = Double()
    var annotationLongitude = Double()
    
    var annotation = MKPointAnnotation()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(chooseLocation(gestureRecognizer:)))
        gestureRecognizer.minimumPressDuration = 3
        mapView.addGestureRecognizer(gestureRecognizer)
        
        fetchData()
        
    }
    @objc func chooseLocation(gestureRecognizer : UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            
            let touchedPoint = gestureRecognizer.location(in: self.mapView)
            let touchedCoordinates = mapView.convert(touchedPoint, toCoordinateFrom: self.mapView)
            
            chosenLatitude = touchedCoordinates.latitude
            chosenLongitude = touchedCoordinates.longitude
            
            let annotation = annotation
            annotation.coordinate = touchedCoordinates
            annotation.title = txtCustomerName.text
            annotation.subtitle = txtPhone.text
            self.mapView.addAnnotation(annotation)
        }
        
    }
    @IBAction func btnSaveClicked(_ sender: UIButton) {
        
        if txtCustomerName.text == "" {
            btnSave.isEnabled = true
            showAlert(message: "Please enter customer name")
        }else if txtPhone.text == "" {
            btnSave.isEnabled = true
            showAlert(message: "Please enter phone number")
        }else if annotation.coordinate.latitude == Double() {
            btnSave.isEnabled = true
            showAlert(message: "Please specify annotation")
        } else {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            let newCustomer = NSEntityDescription.insertNewObject(forEntityName: "Customer", into: context)
            
            newCustomer.setValue(txtCustomerName.text, forKey: "title")
            newCustomer.setValue(txtPhone.text, forKey: "subtitle")
            newCustomer.setValue(chosenLatitude, forKey: "latitude")
            newCustomer.setValue(chosenLongitude, forKey: "longitude")
            newCustomer.setValue(UUID(), forKey: "id")
            
            do {
                try context.save()
                print("succes")
            }catch {
                print("error")
            }
            NotificationCenter.default.post(name: NSNotification.Name("newCustomer"), object: nil)
            navigationController?.popViewController(animated: true)
            
        }
            
        }
    fileprivate func fetchData() {
        if selectedTitle != "" {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Customer")
            let idString = selectedTitleID!.uuidString
            fetchRequest.predicate = NSPredicate(format: "id = %@", idString)
            fetchRequest.returnsObjectsAsFaults = false
            
            do {
                let results = try context.fetch(fetchRequest)
                
                if results.count > 0 {
                    
                    for result in results as! [NSManagedObject]{
                        if let title = result.value(forKey: "title") as? String {
                            annotationTitle = title
                            if let subtitle = result.value(forKey: "subtitle") as? String {
                                annotationSubtitle = subtitle
                                if let latitude = result.value(forKey: "latitude") as? Double {
                                    annotationLatitude = latitude
                                    if let longitude = result.value(forKey: "longitude") as? Double {
                                        annotationLongitude = longitude
                                        
                                        let annotation = MKPointAnnotation()
                                        annotation.title = annotationTitle
                                        annotation.subtitle = annotationSubtitle
                                        
                                        let coordinate = CLLocationCoordinate2D(latitude: annotationLatitude, longitude: annotationLongitude)
                                        annotation.coordinate = coordinate
                                        
                                        self.mapView.addAnnotation(annotation)
                                        txtCustomerName.text = annotationTitle
                                        txtPhone.text = annotationSubtitle
                                        
                                        locationManager.stopUpdatingLocation()
                                        
                                        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                        let region = MKCoordinateRegion(center: coordinate, span: span)
                                        self.mapView.setRegion(region, animated: true)
                                        
                                        btnSave.isHidden = true
                                    }
                                }
                            }
                        }
                    }
                }
            }catch {
                print("error")
            }
            
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if selectedTitle == "" {
            let location = locations.last! as CLLocation
            
            let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            let region = MKCoordinateRegion(center: center, span: span)
            
            self.mapView.setRegion(region, animated: true)
        }
}
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        let reusableID = "myAnnatation"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reusableID) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reusableID)
            pinView?.canShowCallout = true
            pinView?.tintColor = UIColor.black
            
            let button = UIButton(type: UIButton.ButtonType.detailDisclosure)
            pinView?.rightCalloutAccessoryView = button
        } else {
            pinView?.annotation = annotation
        }
        
        return pinView
    }
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if selectedTitle != "" {
            let requestLocation = CLLocation(latitude: annotationLatitude, longitude: annotationLongitude)
            
            CLGeocoder().reverseGeocodeLocation(requestLocation) { placemarks, error in
                
                if let placemark = placemarks {
                    if placemark.count > 0 {
                        let newPlacemark = MKPlacemark(placemark: placemark[0])
                        let item = MKMapItem(placemark: newPlacemark)
                        item.name = self.annotationTitle
                        
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving]
                        item.openInMaps(launchOptions: launchOptions)
                        
                    }
                }
            }
        }
    }
    func showAlert(message : String) {
        let alertController = UIAlertController(title: "Opps!", message: message, preferredStyle: UIAlertController.Style.alert)
        let okButton = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alertController.addAction(okButton)
        self.present(alertController, animated: true, completion: nil)
        
    }
 }

   

