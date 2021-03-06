//
//  MapViewController.swift
//  TRANSFLO Truck Stops
//
//  Created by Kristopher Sandrick on 4/25/18.
//  Copyright © 2018 Kristopher Sandrick. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class MapViewController: UIViewController {

    private var resetWorkItem: DispatchWorkItem?
    var locationManager: CLLocationManager!
    
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            mapView.mapType = mapType
        }
    }
    
    @IBOutlet weak var mapTypeControl: UISegmentedControl! {
        didSet {
            let typeVal: Int
            switch mapType {
                case .standard:
                typeVal = 0
            case .satellite:
                typeVal = 1
            default:
                typeVal = 0
            }
            mapTypeControl.selectedSegmentIndex = typeVal
        }
    }
    
    @IBOutlet weak var mapTrackingButton: UIButton! {
        didSet {
            configureTrackingButtonFor(state: isTracking)
        }
    }
    
    var truckStops: [TruckStop] = []

    struct K {
        static let trackingKey = "tracking"
        static let mapTypeKey = "mapType"
        static let truckStopSegue = "truckStopSegue"
        static let searchViewSegue = "searchViewSegue"
        static let userLocationMarker = "userLocationMarker"
        static let truckStopMarker = "truckStopMarker"
    }
    
    let userDefaults = UserDefaults.standard
    
    var isFirstTime: Bool = true
    var isDisplayingSearch: Bool = false
    var isTracking: Bool {
        get {
            return userDefaults.bool(forKey: K.trackingKey)
        }
        set(newValue) {
            userDefaults.set(newValue, forKey: K.trackingKey)
        }
    }
    
    var mapType: MKMapType {
        get {
            guard let savedMapType = userDefaults.value(forKey: K.mapTypeKey) as? UInt else {
                return MKMapType.standard
            }
            return MKMapType(rawValue: savedMapType)!
        }
        set(newType) {
            userDefaults.set(newType.rawValue, forKey: K.mapTypeKey)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager = CLLocationManager()
        locationManager.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        determineLocationStatus()
    }
    
    @IBAction func unwindToMainViewController(sender: UIStoryboardSegue) {
        if let currentTruckStop = (sender.source as? TruckStopViewController)?.truckStop {
            mapView.deselectAnnotation(currentTruckStop, animated: false)
        }else if let searchPredicate = (sender.source as? SearchViewController)?.searchPredicate {
            let filteredTruckStops: [TruckStop] = (self.truckStops as NSArray).filtered(using: searchPredicate) as! [TruckStop]
            
            mapView.removeAnnotations(filteredTruckStops)
            let searchResults: [TruckStop] = filteredTruckStops.map { t in
                t.searchResult = true
                return t
            }
            mapView.addAnnotations(searchResults)
            isDisplayingSearch = true
            mapView.showAnnotations(searchResults, animated: true)
            if isTracking { reCenterMapInSeconds(Timing.searchInactivityDelay) }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let annotationView = sender as? MKAnnotationView
        let truckStop = annotationView?.annotation as? TruckStop
        if let modalViewController = segue.destination as? TruckStopViewController {
            modalViewController.truckStop = truckStop
            modalViewController.userLocation = mapView.userLocation.location
        } else if segue.destination is SearchViewController {
            mapView.removeAnnotations(truckStops)
            truckStops = truckStops.map { t in
                t.searchResult = false
                return t
            }
            mapView.addAnnotations(truckStops)
        }
    }
    
}

extension MapViewController: CLLocationManagerDelegate {

    func determineLocationStatus() {
        if CLLocationManager.locationServicesEnabled() {
            handleAuthorization(status: CLLocationManager.authorizationStatus())
        } else {
            print("Location services are not enabled")
            showSettingsAlert()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorization(status: status)
    }
    
    func handleAuthorization(status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showSettingsAlert()
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationManager()
        }
    }
 
    func showSettingsAlert() {
        let alertController = UIAlertController(title: NSLocalizedString("Location Services Required", comment: "" ), message: NSLocalizedString("Open user settings", comment: "" ), preferredStyle: UIAlertControllerStyle.alert)

        let okAction = UIAlertAction(title: "Settings", style: .default) {
            (result: UIAlertAction) -> Void in
            UIApplication.shared.open(NSURL(string: UIApplicationOpenSettingsURLString)! as URL, options: [:], completionHandler: nil)
        }

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "" ), style: .cancel, handler: nil)
        
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }

    func startLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.pausesLocationUpdatesAutomatically = true
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = Distances.defaultFilterDistance
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("User location did change")
        let userLocation: CLLocation = locations.last! as CLLocation

        if isFirstTime {
            isFirstTime = false
            reCenterMapOnLocation(userLocation, withReset: true)
        }
        if !isTracking { manager.stopUpdatingLocation() }
    }
 
}

extension MapViewController: MKMapViewDelegate {
    
    @IBAction func mapTypeChanged(sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            mapType = .standard
        case 1:
            mapType = .satellite
        default:
            mapType = .standard
        }
        mapView.mapType = mapType
    }
    
    @IBAction func toggleTracking(_ sender: UIButton) {
        isTracking = !isTracking
        configureTrackingButtonFor(state: isTracking)
        if isTracking {
            locationManager.startUpdatingLocation()
            reCenterMapInSeconds(Timing.defaultMinimumDelay)
        }
    }
    
    func configureTrackingButtonFor(state: Bool) {
        let buttonTitle = state ? NSLocalizedString("Tracking: On", comment: "" ) : NSLocalizedString("Tracking: Off", comment: "" )
        mapTrackingButton.setTitle(buttonTitle, for: .normal)
    }
    
    @IBAction func resetMap() {
        if let currentUserLocation = mapView.userLocation.location {
            reCenterMapOnLocation(currentUserLocation, withReset: true)
        }
    }
    
    func reCenterMapOnUser() {
        if let currentUserLocation = mapView.userLocation.location {
            mapView.setCenter(currentUserLocation.coordinate, animated: true)
        }
    }
    
    func reCenterMapOnLocation(_ location: CLLocation, withReset: Bool) {
        let radius = withReset ? Distances.defaultRadius : mapView.currentRadius()
            centerMapOnLocation(location, radius: radius)
    }
    
    func reCenterMapInSeconds(_ seconds: Double) {
        isDisplayingSearch = false
        resetWorkItem = DispatchWorkItem {[weak self] in
            self?.reCenterMapOnUser()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: resetWorkItem!)
    }
    
    func centerMapOnLocation(_ location: CLLocation,
                             radius: Double = Distances.defaultRadius) {
        let radiusInMeters = radius.toMeters()
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                                  radiusInMeters, radiusInMeters)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        resetWorkItem?.cancel()
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let detailsPresent = self.presentedViewController is TruckStopViewController

        if !detailsPresent {
            let currentMapLocation = mapView.centerCoordinate
            let location: CLLocation = CLLocation(latitude: currentMapLocation.latitude, longitude: currentMapLocation.longitude)

            TruckStop.retrieveTruckStops(radius: mapView.currentRadius(), location: location) { (status, resultTruckStops) in
                switch status {
                case .failure :
                    let alertController = UIAlertController(title: NSLocalizedString("Network Failure", comment: "" ), message: NSLocalizedString("This app requires access to the internet to provide full functionality to you. Please check your settings.", comment: "" ), preferredStyle: UIAlertControllerStyle.alert)
                    DispatchQueue.main.async {
                        self.present(alertController, animated: true, completion: nil)
                    }
                    self.isTracking = false
                    self.locationManager.stopUpdatingLocation()
                case .success:
                    let newTruckStops = resultTruckStops.newest(from: self.truckStops)
                    DispatchQueue.main.async {
                        self.mapView.addAnnotations(newTruckStops)
                    }
                    var accumulatedTruckStops = self.truckStops + newTruckStops
                    accumulatedTruckStops = Array(Set(accumulatedTruckStops))
                    self.truckStops = accumulatedTruckStops
                }
            }
        }

        if isTracking && !detailsPresent && !isDisplayingSearch { reCenterMapInSeconds(Timing.inactivityDelay) }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        recolorSelectedPin(view: view, toColor: UIColor.green)
        if let location = view.annotation?.coordinate {
            mapView.setCenter(location, animated: true)
        }
        performSegue(withIdentifier: K.truckStopSegue, sender: view)
        
        if isTracking {
            resetWorkItem?.cancel()
            reCenterMapInSeconds(Timing.detailInactivityDelay)
        }
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        if let curAnnotation = view.annotation as? TruckStop {
            recolorSelectedPin(view: view, toColor: curAnnotation.searchResult ? UIColor.red : UIColor.orange)
        }
    }
    
    func recolorSelectedPin(view: MKAnnotationView, toColor: UIColor) {
        if let curAnnotation = view.annotation as? TruckStop {
            if let markerView = mapView.view(for: curAnnotation) as? MKMarkerAnnotationView {
                markerView.markerTintColor = toColor
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        let userAnnotationView = mapView.view(for: mapView.userLocation)
        userAnnotationView?.isEnabled = false
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            let locationView = mapView.view(for: annotation) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: K.userLocationMarker)
            locationView.markerTintColor = UIColor.blue
            locationView.glyphImage = UIImage.init(named: "truck")
            return locationView
        }
        
        guard let curAnnotation = annotation as? TruckStop else { return nil }
        let identifier = K.truckStopMarker
        var pinView: MKMarkerAnnotationView
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as?  MKMarkerAnnotationView {
            dequeuedView.annotation = curAnnotation
            pinView = dequeuedView
        } else {
            pinView = MKMarkerAnnotationView(annotation: curAnnotation, reuseIdentifier: identifier)
            pinView.canShowCallout = false
//            pinView.markerTintColor = UIColor.orange
//            pinView.glyphImage = UIImage.init(named: "gasPump")
        }
        pinView.glyphImage = curAnnotation.searchResult ? UIImage.init(named: "magnifier") : UIImage.init(named: "gasPump")
        pinView.markerTintColor = curAnnotation.searchResult ? UIColor.red : UIColor.orange
        return pinView
    }
}
