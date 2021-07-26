//
//  ViewController.swift
//  Snapchat
//
//  Created by Dela Cruz, Lester on 7/25/21.
//
import AVFoundation
import UIKit
import Swifter
import Dispatch

class ViewController: UIViewController {
    
    // Capture Session
    var session: AVCaptureSession?

    // Photo Output
    let output = AVCapturePhotoOutput()

    // Video Preview
    let previewLayer = AVCaptureVideoPreviewLayer()

    // server
    let server = HttpServer()
    
    // Data
    var data : Data?
    
    let timeLimit: TimeInterval = 5
    
    private let ipText: UILabel = {
        let label = UILabel(frame: CGRect(x: 100, y: 200, width: 300, height: 41))
        label.textAlignment = NSTextAlignment.center
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = .black
        view.layer.addSublayer(previewLayer)
        ipText.text = "http://" + self.getIPAddress() + "/take_snapshot"
        view.addSubview(ipText)
        checkCameraPermissions()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        server.GET["/take_snapshot"] = {
            request in
            print("Taking a photo")

            self.takePhoto()
            let startDate = NSDate()
            var tempData: Data?
            while (self.dataIsEmpty(data: self.data) && self.noTimeOut(date: startDate)) {
                print("Capturing photo")
            }
            
            tempData = self.data
            self.data = nil
            
            guard let tempData2 = tempData else {
                return HttpResponse.ok(.text("Error happened"))
            }
            return HttpResponse.ok(.data(tempData2, contentType: "image/jpeg"))
            
        }
        do {
            try server.start(80)
        }
        catch {
            print("Server failed to start")
        }
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        ipText.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 100)
    }
    
    private func noTimeOut(date: NSDate) -> Bool {
        return NSDate().timeIntervalSince1970 - date.timeIntervalSince1970 < self.timeLimit
    }
    
    private func dataIsEmpty(data: Data?) -> Bool {
        return data == nil
    }
    
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: {
                [weak self] granted in
                    guard granted else {
                        return
                    }
                    DispatchQueue.main.async {
                        self?.setUpCamera()
                    }
                }
            )
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            setUpCamera()
        @unknown default:
            break
        }
    }
    
    private func setUpCamera() {
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .video) {
            configureCameraForHighestFrameRate(device: device)
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
                
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session
                
                session.startRunning()
                self.session = session
            }
            catch {
                print("Error setup camera")
            }
        }
    }

    private func takePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.photoQualityPrioritization = AVCapturePhotoOutput.QualityPrioritization.quality
        output.maxPhotoQualityPrioritization = AVCapturePhotoOutput.QualityPrioritization.quality
        output.isHighResolutionCaptureEnabled = true
        output.capturePhoto(with: photoSettings,
                            delegate: self)
    }
    
    // Set the shouldAutorotate to False
    override open var shouldAutorotate: Bool {
       return false
    }

    // Specify the orientation.
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
       return .portrait
    }
    
    func configureCameraForHighestFrameRate(device: AVCaptureDevice) {
        
        var bestFormat: AVCaptureDevice.Format?

        for format in device.formats {
            bestFormat = format
        }
        
        if let bestFormat = bestFormat {
            
            do {
                try device.lockForConfiguration()
                
                // Set the device's active format.
                device.activeFormat = bestFormat
                print(bestFormat)
                
                device.unlockForConfiguration()
            } catch {
                // Handle error.
            }
        }
    }
    
    func getIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface.ifa_name))
                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address ?? ""
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else {
            return
        }
        self.data = data
        print("Photo taken and data saved")
    }
}

