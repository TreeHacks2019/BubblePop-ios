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
    var debugLabel : UILabel = UILabel()
    
    func getVector(lat0: Double, long0: Double, lat1: Double, long1: Double, compass_angle: Double) -> (Double, Double, Double) {
        let lat0r = self.degreesToRadians(degrees: lat0)
        let lat1r = self.degreesToRadians(degrees: lat1)
        let long0r = self.degreesToRadians(degrees: long0)
        let long1r = self.degreesToRadians(degrees: long1)
        let distance = CLLocation(latitude: lat0, longitude: long0).distance(from: CLLocation(latitude: lat1, longitude: long1))
        
        let dLon = long1r - long0r
        let y = sin(dLon) * cos(lat1r) * distance
        let x = (cos(lat0r)*sin(lat1r) - sin(lat0r)*cos(lat1r)*cos(dLon)) * distance
//        print("distance",distance)
//        print(y,x,(y*y+x*x).squareRoot(),"alternative distance")
        let bearing = atan2(y, x)
        
        //let compass_angle = 0.0 // heading clockwise from true north
        if (x <= 0){
            // east of north
            let rotation = -compass_angle
            let xp = cos(rotation)*x + sin(rotation)*y
            let yp = -sin(rotation)*x + cos(rotation)*y
            return (xp, yp, 0)
        }
        let rotation = compass_angle
        let xp = cos(rotation)*x + sin(rotation)*y
        let yp = -sin(rotation)*x + cos(rotation)*y
        return (xp, yp, 0)
    }
    
    func foundPerson(_ sender: Any) {
        // interact with second segue
        performSegue(withIdentifier: "SecondSegue", sender: sender)
    }
    override func viewDidLoad() {
        
        super.viewDidLoad()
        debugLabel.text = "Test"
        debugLabel.font = UIFont(name: "AvenirNext-Bold", size: 20)
        debugLabel.textAlignment = .center
        debugLabel.frame = CGRect(x: 15, y: self.view.frame.height/2 - 150, width:self.view.frame.width - 15, height: 300)
        // self.view.addSubview(debugLabel)
        
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
        let scene = SCNScene(named: "art.scnassets/Lowpoly_tree_sample")!
        self.treeNode = scene.rootNode.childNode(withName: "Tree_lp_11", recursively: true)
        //self.treeNode?.rotation = vector4(x:0,y:90,z:0,w:0)
        //self.treeNode?.position = SCNVector3Make(0, 0, -1)
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Create timer
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { [weak self] (_) in
            self?.timerHasBeenCalled()
        })
        
        // TODO maybe activate only when user is close enough
        let button = UIButton(frame: CGRect(x: self.view.frame.width / 2 - 50, y: self.view.frame.height / 2 + 200, width: 100, height: 50))
        button.backgroundColor = .black
        button.setTitle("Found!", for: .normal)
        button.addTarget(self, action: #selector(foundPerson), for: .touchUpInside)
        button.layer.cornerRadius = 10
        self.view.addSubview(button)
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
            let vec3 = self.getVector(lat0: lat, long0: long, lat1: target_lat, long1: target_long, compass_angle: directionDegrees)
            self.treeNode?.position = SCNVector3Make(Float(vec3.0), 0, Float(-vec3.1))
            let res = "set position: " + String(describing: self.treeNode?.position)
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        print(newHeading.trueHeading)
        directionDegrees = newHeading.trueHeading
        let vec3 = self.getVector(lat0: lat, long0: long, lat1: target_lat, long1: target_long, compass_angle: directionDegrees)
        self.treeNode?.position = SCNVector3Make(Float(vec3.0), 0, Float(-vec3.1))
        
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
        
        // add this
        
        let vec3 = self.getVector(lat0: lat, long0: long, lat1: target_lat, long1: target_long, compass_angle: directionDegrees)
        self.treeNode?.position = SCNVector3Make(Float(vec3.0), 0, Float(-vec3.1))
        let res = "set position: " + String(describing: self.treeNode?.position)
        print(res)
    }
    
}

