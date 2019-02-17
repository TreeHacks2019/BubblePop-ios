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

import AVFoundation
import PushKit
import CallKit
import TwilioVoice

import ARCL

let baseURLString = "https://838fd95b.ngrok.io"
// If your token server is written in PHP, accessTokenEndpoint needs .php extension at the end. For example : /accessToken.php
let accessTokenEndpoint = "/accessToken"
let identity = "alice"
let twimlParamTo = "to"

class ARViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate, PKPushRegistryDelegate, TVONotificationDelegate, TVOCallDelegate, CXProviderDelegate, UITextFieldDelegate {
    
//    @IBOutlet var sceneView: ARSCNView!
    var modelNode:SCNNode!
//    @IBOutlet weak var placeCallButton: UIButton!
//    @IBOutlet weak var iconView: UIImageView!
//    @IBOutlet weak var outgoingValue: UITextField!
    var outgoingValue: String = "2135870447"
//    @IBOutlet weak var callControlView: UIView!
//    @IBOutlet weak var muteSwitch: UISwitch!
//    @IBOutlet weak var speakerSwitch: UISwitch!
    
    var treeNode: SCNNode?
    let locationManager = CLLocationManager()
    var userLocation = CLLocation()
    var location = CLLocation()
    var username = "Will"
    var timer: Timer!
    var debugLabel : UILabel = UILabel()
    var distance : Double = 0.0
    var deviceTokenString: String?
    var heading: Double = 0.0
    var target_lat: Double = 0.0
    var target_long: Double = 0.0
    
    var voipRegistry: PKPushRegistry
    var incomingPushCompletionCallback: (()->Swift.Void?)? = nil
    
    var isSpinning: Bool
    var incomingAlertController: UIAlertController?
    
    var callInvite: TVOCallInvite?
    var call: TVOCall?
    var callKitCompletionCallback: ((Bool)->Swift.Void?)? = nil
    
    let callKitProvider: CXProvider
    let callKitCallController: CXCallController
    var userInitiatedDisconnect: Bool = false
    
    var sceneLocationView = SceneLocationView()
    
  
    func foundPerson(_ sender: Any) {
        // interact with second segue
        performSegue(withIdentifier: "SecondSegue", sender: sender)
    }
    
    func makeCall(_ sender: Any) {
        print("call button tapped...")
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
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        // Set the view's delegate
//        sceneView.delegate = self
//
//        // Show statistics such as fps and timing information
//        sceneView.showsStatistics = true
        sceneLocationView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/Lowpoly_tree_sample")!
        self.modelNode = scene.rootNode.childNode(withName: "Tree_lp_11", recursively: true)
        //self.treeNode?.rotation = vector4(x:0,y:90,z:0,w:0)
        //self.treeNode?.position = SCNVector3Make(0, 0, -1)
        
        // Set the scene to the view
//        sceneView.scene = scene
        
        // Create timer
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { [weak self] (_) in
            self?.timerHasBeenCalled()
        })
        
        // TODO maybe activate only when user is close enough
        let button = UIButton(frame: CGRect(x: self.view.frame.width / 2 - 50, y: self.view.frame.height / 2 + 100, width: 100, height: 50))
        button.backgroundColor = .blue
        button.setTitle("Found!", for: .normal)
        button.addTarget(self, action: #selector(foundPerson), for: .touchUpInside)
        button.layer.cornerRadius = 10
        sceneLocationView.addSubview(button)
        
        let callButton = UIButton(frame: CGRect(x: self.view.frame.width / 2 - 50, y: self.view.frame.height / 2 + 200, width: 100, height: 50))
        callButton.backgroundColor = .green
        callButton.setTitle("📞 Call", for: .normal)
        callButton.addTarget(self, action: #selector(placeCall), for: .touchUpInside)
        callButton.layer.cornerRadius = 10
        sceneLocationView.addSubview(callButton)
        
//        toggleUIState(isEnabled: true, showCallControl: false)
//        outgoingValue.delegate = self
        sceneLocationView.run()
        view.addSubview(sceneLocationView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        // Run the view's session
//        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
//        sceneView.session.pause()
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
        let userLocation = locations[locations.count - 1]
        if userLocation.horizontalAccuracy > 0 {
            print("longitude = \(userLocation.coordinate.longitude), latitude = \(userLocation.coordinate.latitude)")
            self.userLocation = userLocation
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading
    }
    
    func timerHasBeenCalled() {
        // update this
        var target = "Jennie"
        if (username == "Jennie") {target = "Will"}
        
        let ref = Database.database().reference()
//        ref.child("profile").child(target).observeSingleEvent(of: .value, with: { (snapshot) in
//            let value = snapshot.value as? [String : AnyObject] ?? [:]
//            if (value["lat"] != nil && value["lng"] != nil) {
//                self.location = CLLocation(latitude: value["lat"] as! Double, longitude: value["lng"] as! Double)
//                self.updateLocation(self.location.coordinate.latitude, self.location.coordinate.longitude)
//            }
//        }) { (error) in
//            print(error.localizedDescription)
//        }
//        ref.child("profile").child(username).child("lat").setValue(self.userLocation.coordinate.latitude);
//        ref.child("profile").child(username).child("lng").setValue(self.userLocation.coordinate.longitude);
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
        sceneLocationView.removeAllNodes()
        let coordinate = CLLocationCoordinate2D(latitude: target_lat, longitude: target_long)
        let location = CLLocation(coordinate: coordinate, altitude: 5)
        let image = UIImage(named: "pin")!
        
        let annotationNode = LocationAnnotationNode(location: location, image: image)
        sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        isSpinning = false
        voipRegistry = PKPushRegistry.init(queue: DispatchQueue.main)
        
        TwilioVoice.logLevel = .verbose
        
        let configuration = CXProviderConfiguration(localizedName: "CallKit Quickstart")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        if let callKitIcon = UIImage(named: "iconMask80") {
            configuration.iconTemplateImageData = UIImagePNGRepresentation(callKitIcon)
        }
        
        callKitProvider = CXProvider(configuration: configuration)
        callKitCallController = CXCallController()
        
        super.init(coder: aDecoder)
        
        callKitProvider.setDelegate(self, queue: nil)
        
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }
    
    deinit {
        // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
        callKitProvider.invalidate()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func fetchAccessToken() -> String? {
        let endpointWithIdentity = String(format: "%@?identity=%@", accessTokenEndpoint, identity)
        guard let accessTokenURL = URL(string: baseURLString + endpointWithIdentity) else {
            return nil
        }
        
        print("call kit is used")
        
        return try? String.init(contentsOf: accessTokenURL, encoding: .utf8)
    }
    
//    func toggleUIState(isEnabled: Bool, showCallControl: Bool) {
//        placeCallButton.isEnabled = isEnabled
//        if (showCallControl) {
//            callControlView.isHidden = false
//            muteSwitch.isOn = false
//            speakerSwitch.isOn = true
//        } else {
//            callControlView.isHidden = true
//        }
//    }
    
    func placeCall(_ sender: UIButton) {
        if (self.call != nil && self.call?.state == .connected) {
            self.userInitiatedDisconnect = true
            performEndCallAction(uuid: self.call!.uuid)
//            self.toggleUIState(isEnabled: false, showCallControl: false)
        } else {
            let uuid = UUID()
            let handle = "Voice Bot"
            
            performStartCallAction(uuid: uuid, handle: handle)
        }
    }
    
//    @IBAction func muteSwitchToggled(_ sender: UISwitch) {
//        if let call = call {
//            call.isMuted = sender.isOn
//        } else {
//            NSLog("No active call to be muted")
//        }
//    }
    
//    @IBAction func speakerSwitchToggled(_ sender: UISwitch) {
//        toggleAudioRoute(toSpeaker: sender.isOn)
//    }
    
    // MARK: UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
//        outgoingValue.resignFirstResponder()
        return true
    }
    
    
    // MARK: PKPushRegistryDelegate
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, forType type: PKPushType) {
        NSLog("pushRegistry:didUpdatePushCredentials:forType:")
        
        if (type != .voIP) {
            return
        }
        
        guard let accessToken = fetchAccessToken() else {
            return
        }
        
        let deviceToken = (credentials.token as NSData).description
        
        TwilioVoice.register(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
            if let error = error {
                NSLog("An error occurred while registering: \(error.localizedDescription)")
            }
            else {
                NSLog("Successfully registered for VoIP push notifications.")
            }
        }
        
        self.deviceTokenString = deviceToken
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenForType type: PKPushType) {
        NSLog("pushRegistry:didInvalidatePushTokenForType:")
        
        if (type != .voIP) {
            return
        }
        
        guard let deviceToken = deviceTokenString, let accessToken = fetchAccessToken() else {
            return
        }
        
        TwilioVoice.unregister(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
            if let error = error {
                NSLog("An error occurred while unregistering: \(error.localizedDescription)")
            }
            else {
                NSLog("Successfully unregistered from VoIP push notifications.")
            }
        }
        
        self.deviceTokenString = nil
    }
    
    /**
     * Try using the `pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:` method if
     * your application is targeting iOS 11. According to the docs, this delegate method is deprecated by Apple.
     */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, forType type: PKPushType) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:")
        
        if (type == PKPushType.voIP) {
            TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
        }
    }
    
    /**
     * This delegate method is available on iOS 11 and above. Call the completion handler once the
     * notification payload is passed to the `TwilioVoice.handleNotification()` method.
     */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:")
        // Save for later when the notification is properly handled.
        self.incomingPushCompletionCallback = completion
        
        if (type == PKPushType.voIP) {
            TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
        }
    }
    
    func incomingPushHandled() {
        if let completion = self.incomingPushCompletionCallback {
            completion()
            self.incomingPushCompletionCallback = nil
        }
    }
    
    // MARK: TVONotificaitonDelegate
    func callInviteReceived(_ callInvite: TVOCallInvite) {
        if (callInvite.state == .pending) {
            handleCallInviteReceived(callInvite)
        } else if (callInvite.state == .canceled) {
            handleCallInviteCanceled(callInvite)
        }
    }
    
    func handleCallInviteReceived(_ callInvite: TVOCallInvite) {
        NSLog("callInviteReceived:")
        
        if (self.callInvite != nil && self.callInvite?.state == .pending) {
            NSLog("Already a pending incoming call invite.");
            NSLog("  >> Ignoring call from %@", callInvite.from);
            self.incomingPushHandled()
            return;
        } else if (self.call != nil) {
            NSLog("Already an active call.");
            NSLog("  >> Ignoring call from %@", callInvite.from);
            self.incomingPushHandled()
            return;
        }
        
        self.callInvite = callInvite
        
        reportIncomingCall(from: "Voice Bot", uuid: callInvite.uuid)
    }
    
    func handleCallInviteCanceled(_ callInvite: TVOCallInvite) {
        NSLog("callInviteCanceled:")
        
        performEndCallAction(uuid: callInvite.uuid)
        
        self.callInvite = nil
        self.incomingPushHandled()
    }
    
    func notificationError(_ error: Error) {
        NSLog("notificationError: \(error.localizedDescription)")
    }
    
    
    // MARK: TVOCallDelegate
    func callDidConnect(_ call: TVOCall) {
        NSLog("callDidConnect:")
        
        self.call = call
        self.callKitCompletionCallback!(true)
        self.callKitCompletionCallback = nil
        
//        self.placeCallButton.setTitle("Hang Up", for: .normal)
        
//        toggleUIState(isEnabled: true, showCallControl: true)
        stopSpin()
        toggleAudioRoute(toSpeaker: true)
    }
    
    func call(_ call: TVOCall, didFailToConnectWithError error: Error) {
        NSLog("Call failed to connect: \(error.localizedDescription)")
        
        if let completion = self.callKitCompletionCallback {
            completion(false)
        }
        
        performEndCallAction(uuid: call.uuid)
        callDisconnected()
    }
    
    func call(_ call: TVOCall, didDisconnectWithError error: Error?) {
        if let error = error {
            NSLog("Call failed: \(error.localizedDescription)")
        } else {
            NSLog("Call disconnected")
        }
        
        if !self.userInitiatedDisconnect {
            var reason = CXCallEndedReason.remoteEnded
            
            if error != nil {
                reason = .failed
            }
            
            self.callKitProvider.reportCall(with: call.uuid, endedAt: Date(), reason: reason)
        }
        
        callDisconnected()
    }
    
    func callDisconnected() {
        self.call = nil
        self.callKitCompletionCallback = nil
        self.userInitiatedDisconnect = false
        
        stopSpin()
//        toggleUIState(isEnabled: true, showCallControl: false)
//        self.placeCallButton.setTitle("Call", for: .normal)
    }
    
    
    // MARK: AVAudioSession
    func toggleAudioRoute(toSpeaker: Bool) {
        // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver. Use port override to switch the route.
        do {
            if (toSpeaker) {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            } else {
                try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
            }
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    
    // MARK: Icon spinning
    func startSpin() {
        if (isSpinning != true) {
            isSpinning = true
//            spin(options: UIViewAnimationOptions.curveEaseIn)
        }
    }
    
    func stopSpin() {
        isSpinning = false
    }
    
//    func spin(options: UIViewAnimationOptions) {
//        UIView.animate(withDuration: 0.5,
//                       delay: 0.0,
//                       options: options,
//                       animations: { [weak iconView] in
//                        if let iconView = iconView {
//                            iconView.transform = iconView.transform.rotated(by: CGFloat(Double.pi/2))
//                        }
//        }) { [weak self] (finished: Bool) in
//            guard let strongSelf = self else {
//                return
//            }
//
//            if (finished) {
//                if (strongSelf.isSpinning) {
//                    strongSelf.spin(options: UIViewAnimationOptions.curveLinear)
//                } else if (options != UIViewAnimationOptions.curveEaseOut) {
//                    strongSelf.spin(options: UIViewAnimationOptions.curveEaseOut)
//                }
//            }
//        }
//    }
    
    
    // MARK: CXProviderDelegate
    func providerDidReset(_ provider: CXProvider) {
        NSLog("providerDidReset:")
        TwilioVoice.isAudioEnabled = true
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        NSLog("providerDidBegin")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        NSLog("provider:didActivateAudioSession:")
        TwilioVoice.isAudioEnabled = true
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NSLog("provider:didDeactivateAudioSession:")
        TwilioVoice.isAudioEnabled = false
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        NSLog("provider:timedOutPerformingAction:")
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        NSLog("provider:performStartCallAction:")
        
//        toggleUIState(isEnabled: false, showCallControl: false)
        startSpin()
        
        TwilioVoice.configureAudioSession()
        TwilioVoice.isAudioEnabled = false
        
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        
        self.performVoiceCall(uuid: action.callUUID, client: "") { (success) in
            if (success) {
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                action.fulfill()
            } else {
                action.fail()
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NSLog("provider:performAnswerCallAction:")
        
        // RCP: Workaround from https://forums.developer.apple.com/message/169511 suggests configuring audio in the
        //      completion block of the `reportNewIncomingCallWithUUID:update:completion:` method instead of in
        //      `provider:performAnswerCallAction:` per the WWDC examples.
        // TwilioVoice.configureAudioSession()
        
        assert(action.callUUID == self.callInvite?.uuid)
        
        TwilioVoice.isAudioEnabled = false
        self.performAnswerVoiceCall(uuid: action.callUUID) { (success) in
            if (success) {
                action.fulfill()
            } else {
                action.fail()
            }
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NSLog("provider:performEndCallAction:")
        
        if (self.callInvite != nil && self.callInvite?.state == .pending) {
            self.callInvite?.reject()
            self.callInvite = nil
        } else if (self.call != nil) {
            self.call?.disconnect()
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        NSLog("provider:performSetHeldAction:")
        if (self.call?.state == .connected) {
            self.call?.isOnHold = action.isOnHold
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    // MARK: Call Kit Actions
    func performStartCallAction(uuid: UUID, handle: String) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)
        
        callKitCallController.request(transaction)  { error in
            if let error = error {
                NSLog("StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }
            
            NSLog("StartCallAction transaction request successful")
            
            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false
            
            self.callKitProvider.reportCall(with: uuid, updated: callUpdate)
        }
    }
    
    func reportIncomingCall(from: String, uuid: UUID) {
        let callHandle = CXHandle(type: .generic, value: from)
        
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = callHandle
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false
        
        callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if let error = error {
                NSLog("Failed to report incoming call successfully: \(error.localizedDescription).")
                return
            }
            
            NSLog("Incoming call successfully reported.")
            
            // RCP: Workaround per https://forums.developer.apple.com/message/169511
            TwilioVoice.configureAudioSession()
        }
    }
    
    func performEndCallAction(uuid: UUID) {
        
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("EndCallAction transaction request failed: \(error.localizedDescription).")
                return
            }
            
            NSLog("EndCallAction transaction request successful")
        }
    }
    
    func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Swift.Void) {
        guard let accessToken = fetchAccessToken() else {
            completionHandler(false)
            return
        }
        
        call = TwilioVoice.call(accessToken, params: [twimlParamTo : self.outgoingValue], uuid:uuid, delegate: self)
        self.callKitCompletionCallback = completionHandler
    }
    
    func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Swift.Void) {
        call = self.callInvite?.accept(with: self)
        self.callInvite = nil
        self.callKitCompletionCallback = completionHandler
        self.incomingPushHandled()
    }
    
    //MARK: - CLLocationManager
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func updateLocation(_ latitude : Double, _ longitude : Double) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        self.distance = Double(location.distance(from: self.userLocation))
    }
    
    func positionModel(_ location: CLLocation) {
        // Translate node
        self.modelNode.position = translateNode(location)
        
        // Scale node
        self.modelNode.scale = scaleNode(location)
    }
    
    func rotateNode(_ angleInRadians: Float, _ transform: SCNMatrix4) -> SCNMatrix4 {
        let rotation = SCNMatrix4MakeRotation(angleInRadians, 0, 1, 0)
        return SCNMatrix4Mult(transform, rotation)
    }
    
    func translateNode (_ location: CLLocation) -> SCNVector3 {
        let locationTransform = transformMatrix(matrix_identity_float4x4, userLocation, location)
        return positionFromTransform(locationTransform)
    }
    
    func scaleNode (_ location: CLLocation) -> SCNVector3 {
        let scale = max( min( Float(1000/distance), 1.5 ), 3 )
        return SCNVector3(x: scale, y: scale, z: scale)
    }
    
    func positionFromTransform(_ transform: simd_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
    
    func transformMatrix(_ matrix: simd_float4x4, _ originLocation: CLLocation, _ driverLocation: CLLocation) -> simd_float4x4 {
        let bearing = bearingBetweenLocations(userLocation, driverLocation)
        let rotationMatrix = rotateAroundY(matrix_identity_float4x4, Float(bearing))
        
        let position = float4(0.0, 0.0, Float(-distance), 0.0)
        let translationMatrix = getTranslationMatrix(matrix_identity_float4x4, position)
        
        let transformMatrix = simd_mul(rotationMatrix, translationMatrix)
        
        return simd_mul(matrix, transformMatrix)
    }
    
    func getTranslationMatrix(_ matrix: simd_float4x4, _ translation : vector_float4) -> simd_float4x4 {
        var matrix = matrix
        matrix.columns.3 = translation
        return matrix
    }
    
    func rotateAroundY(_ matrix: simd_float4x4, _ degrees: Float) -> simd_float4x4 {
        var matrix = matrix
        
        matrix.columns.0.x = cos(degrees)
        matrix.columns.0.z = -sin(degrees)
        
        matrix.columns.2.x = sin(degrees)
        matrix.columns.2.z = cos(degrees)
        return matrix.inverse
    }
    
    func bearingBetweenLocations(_ originLocation: CLLocation, _ driverLocation: CLLocation) -> Double {
        let lat1 = self.degreesToRadians(degrees: originLocation.coordinate.latitude)
        let lon1 = self.degreesToRadians(degrees: originLocation.coordinate.longitude)
        
        let lat2 = self.degreesToRadians(degrees: location.coordinate.latitude)
        let lon2 = self.degreesToRadians(degrees: location.coordinate.longitude)
        
        let longitudeDiff = lon2 - lon1
        
        let y = sin(longitudeDiff) * cos(lat2);
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(longitudeDiff);
        
        return atan2(y, x)
    }
    
    func makeBillboardNode(_ image: UIImage) -> SCNNode {
        let plane = SCNPlane(width: 10, height: 10)
        plane.firstMaterial!.diffuse.contents = image
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        return node
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        sceneLocationView.frame = view.bounds
    }
    
}

