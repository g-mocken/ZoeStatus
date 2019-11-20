//
//  MapViewController.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 18.11.19.
//  Copyright © 2019 Dr. Guido Mocken. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

var locationManager = CLLocationManager()

protocol MapViewControllerDelegate: AnyObject {
    func getRemainingRange()->(Float?)
}


class MapViewController: UIViewController, MKMapViewDelegate {

    weak var delegate:MapViewControllerDelegate?

    @IBOutlet var rangeMap: MKMapView!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestWhenInUseAuthorization()

        rangeMap.userTrackingMode = .none
   
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        

    }
    
    
     func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay.isKind(of: MKCircle.self) {

            let view = MKCircleRenderer(overlay: overlay)
            view.fillColor = UIColor.green.withAlphaComponent(0.3)
            view.lineWidth = 1.0
            view.strokeColor = UIColor.black
            return view
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    var circle:MKCircle?

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {

        let r:Float? = delegate!.getRemainingRange()
        if r != nil {
            
            if circle != nil {
                rangeMap.removeOverlay(circle!)
            }
            
            circle = MKCircle(center: rangeMap.userLocation.location!.coordinate, radius: CLLocationDistance(exactly: r!)!)
            rangeMap.addOverlay(circle!)
            
            let region = MKCoordinateRegion(center: rangeMap.userLocation.location!.coordinate, latitudinalMeters: 3*CLLocationDistance(exactly: r!)!, longitudinalMeters: 3*CLLocationDistance(exactly: r!)!)
            
            rangeMap.setRegion(region, animated: true)
        }
    
        
        
        //  mapView.showAnnotations([userLocation], animated: true)

       
    }
}
