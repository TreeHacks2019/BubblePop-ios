//
//  ARViewController.swift
//  CardSlider
//
//  Created by Stewart Dulaney on 2/16/19.
//  Copyright © 2019 Saoud Rizwan. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Firebase
import CoreLocation

class ARViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    var treeNode: SCNNode?
    let locationManager = CLLocationManager()
    var lat: Double = 0.0
    var long : Double = 0.0
    var target_lat: Double = 0.0
    var target_long: Double = 0.0
    var username = "Will"
    var timer: Timer!
    var directionDegrees : Double = 0.0
    
    func getVector(lat0: Double, long0: Double, lat1: Double, long1: Double, compass_angle: Double) -> (Double, Double, Double) {
        let dLon = long1 - long0
        let y = sin(dLon) * cos(lat1)
        let x = cos(lat0)*sin(lat1) - sin(lat0)*cos(lat1)*cos(dLon)
        let bearing = atan2(y, x)
        let distance = sqrt(x*x + y*y)
        
        //let compass_angle = 0.0 // heading clockwise from true north
        if (x <= 0){
            // east of north
            let rotation = -compass_angle
            let xp = cos(rotation)*x + sin(rotation)*y
            let yp = -sin(rotation)*x + cos(rotation)*y
            return (xp, 0, -yp)
        }
        let rotation = compass_angle
        let xp = cos(rotation)*x + sin(rotation)*y
        let yp = -sin(rotation)*x + cos(rotation)*y
        return (xp, 0, -yp)
        //return (, -distance)
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let id = UIDevice.current.identifierForVendor!.uuidString
        let ref = Database.database().reference()
        ref.child(id).child("username").observeSingleEvent(of: .value, with: { (snapshot) in
            self.username = snapshot.value as? String ?? ""
        }) { (error) in
            print(error.localizedDescription)
        }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/Lowpoly_tree_sample.dae")!
        self.treeNode = scene.rootNode.childNode(withName: "Tree_lp_11", recursively: true)
        //self.treeNode?.position = SCNVector3Make(0, 0, -1)
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Create timer
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { [weak self] (_) in
            self?.timerHasBeenCalled()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func degreesToRadians(degrees: Double) -> Double {
        return degrees * Double.pi / 180.0
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[locations.count - 1]
        if location.horizontalAccuracy > 0 {
            print("longitude = \(location.coordinate.longitude), latitude = \(location.coordinate.latitude)")
            long = location.coordinate.longitude
            lat = location.coordinate.latitude
            let ref = Database.database().reference()
            ref.child("profile").child(username).child("lat").setValue(lat);
            ref.child("profile").child(username).child("lng").setValue(long);
            
            // add this
            let vec3 = self.getVector(lat0: self.degreesToRadians(degrees: lat), long0: self.degreesToRadians(degrees: long), lat1: self.degreesToRadians(degrees: target_lat), long1: self.degreesToRadians(degrees: target_long), compass_angle: self.degreesToRadians(degrees: directionDegrees))
            self.treeNode?.position = SCNVector3Make(Float(vec3.0), 0, Float(-vec3.1))
            print("set position: ", self.treeNode?.position)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        print(newHeading.trueHeading)
        directionDegrees = newHeading.trueHeading
    }
    
    //Write the didFailWithError method here:
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
    
    func timerHasBeenCalled() {
        // update this
        var target = "Jennie"
        if (username == "Jennie") {target = "Will"}
        
        let ref = Database.database().reference()
        ref.child("profile").child(target).observeSingleEvent(of: .value, with: { (snapshot) in
            let value = snapshot.value as? [String : AnyObject] ?? [:]
            if (value["lat"] != nil) {
                self.target_lat = value["lat"] as! Double
            }
            if (value["lng"] != nil) {
                self.target_long = value["lng"] as! Double
            }
            print( self.target_lat, self.target_long, "gotten")
            // update
            
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
}

