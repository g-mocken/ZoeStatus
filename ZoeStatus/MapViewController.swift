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

    @IBOutlet var doneButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestWhenInUseAuthorization()
        var rescaleFactor = self.view.bounds.width / 320.0
        
        if rescaleFactor > 1.5 { // limit size on iPad, as it can otherwise become ridiculously large
            rescaleFactor = 1.5
        }
        print("viewDidLoad: rescaleFactor = \(rescaleFactor)")


        let doneButtonWidthConstraint = NSLayoutConstraint(item: doneButton!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: rescaleFactor * doneButton.bounds.width)
        view.addConstraints([doneButtonWidthConstraint])

        
        rangeMap.userTrackingMode = .none
   
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        positionFixed = false
        updateRangeMap()
    }
    
    
     func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay.isKind(of: MKCircle.self) {

            let view = MKCircleRenderer(overlay: overlay)
            view.fillColor = UIColor.green.withAlphaComponent(0.2)
            view.lineWidth = 1.0
            view.strokeColor = UIColor.black
            return view
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    var circle:MKCircle?

    var positionFixed = false
    
    fileprivate func updateRangeMap() {
        if (!positionFixed){
            
            
            let r:Float? = delegate!.getRemainingRange()
             
            let loc = rangeMap.userLocation.location
            

            if (r != nil) && (loc != nil) {

                print("position = \(loc!.coordinate)")

                
                if circle != nil {
                    rangeMap.removeOverlay(circle!)
                }
                
                circle = MKCircle(center: loc!.coordinate, radius: CLLocationDistance(exactly: r!)!)
                rangeMap.addOverlay(circle!)
                
                let region = MKCoordinateRegion(center: loc!.coordinate, latitudinalMeters: 3*CLLocationDistance(exactly: r!)!, longitudinalMeters: 2.2*CLLocationDistance(exactly: r!)!)
                
                rangeMap.setRegion(region, animated: true)
                positionFixed = true
            }
            
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {

        updateRangeMap()
        
        
        //  mapView.showAnnotations([userLocation], animated: true)

       
    }
}
