//
//  ViewController.swift
//  Pic
//
//  Created by 石嶺 眞太郎 on 2017/02/20.
//  Copyright © 2017年 石嶺 眞太郎. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    var timer: Timer? = nil
    var interval = 1.0                      // 撮影数/秒
    var buttonIsPushed:Bool = false         // 撮影ボタンが押されている間に撮影
    var shutterSoundIsOn:Bool = true        // シャッター音のオン・オフ
    var shutterCount:Int = 0                // シャッター切った回数
    var duration:CMTime = kCMTimeZero
    var currentISO:Float = 0.0
    
    
    @IBOutlet weak var count: UILabel!      // 連続撮影回数
    @IBOutlet weak var label: UILabel!      // 撮影数 / sec.
    @IBOutlet weak var cameraView: UIView!  // カメラ画像の表示用
    @IBOutlet weak var button: UIButton!    // 連続撮影ボタン
    @IBOutlet weak var takeOnePicButton: UIButton!  // 単発撮影ボタン
    @IBOutlet weak var shutterSpeedSlider: UISlider!// シャッタースピード調整スライダー
    @IBOutlet weak var exposeSlider: UISlider!

    @IBOutlet weak var maxISOLabel: UILabel!
    @IBOutlet weak var minISOLabel: UILabel!
    @IBOutlet weak var currentISOLabel: UILabel!
    @IBOutlet weak var currentShutterSpeedLabel: UILabel!
    @IBOutlet weak var minShutterSpeedLabel: UILabel!
    @IBOutlet weak var maxShutterSpeedLabel: UILabel!
//    @IBOutlet weak var isHighResolutionSwitch: UISwitch!
    
    
    var captureDevice: AVCaptureDevice?
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var assetCollection: PHAssetCollection!
    var albumFound : Bool = false
    var photosAsset: PHFetchResult<AnyObject>!
    var assetThumbnailSize:CGSize!
    var collection: PHAssetCollection!
    var assetCollectionPlaceholder: PHObjectPlaceholder!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = String(Int(interval)) + " / sec."
        button.backgroundColor = UIColor(colorLiteralRed: 0, green: 0.1, blue: 0.2, alpha: 0.7)
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
        takeOnePicButton.backgroundColor = UIColor(colorLiteralRed: 0, green: 0.1, blue: 0.2, alpha: 0.7)
        takeOnePicButton.layer.cornerRadius = 20
        takeOnePicButton.layer.masksToBounds = true
        count.text =  String(shutterCount) + " pics"
    }
    
    
    // カメラの準備とタイマー開始
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        captureSession = AVCaptureSession()
        stillImageOutput = AVCapturePhotoOutput()
        
        settingDevicePresset(isOn: false)
        
        createAlbum()
        
        // デバイス取得
        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        try! captureDevice?.lockForConfiguration()
        
        captureDevice?.isExposureModeSupported(AVCaptureExposureMode(rawValue: 3)!)    // 3はカスタムモードらしい
        
        captureSession.sessionPreset = AVCaptureSessionPresetInputPriority // Required for the "activeFormat" of the device to be used
        let highresFormat = (captureDevice?.formats as! [AVCaptureDeviceFormat])
            .filter { CMFormatDescriptionGetMediaSubType($0.formatDescription) == 875704422 } // Full range 420f
            .max { a, b in CMVideoFormatDescriptionGetDimensions(a.formatDescription).width < CMVideoFormatDescriptionGetDimensions(b.formatDescription).width }
        if let format = highresFormat {
            captureDevice?.activeFormat = format
        }
        
        captureDevice?.unlockForConfiguration()
        
        
        // ISOsliderの最小値・最大値を設定
        let minISO = (captureDevice?.activeFormat.minISO)!
        let maxISO = (captureDevice?.activeFormat.maxISO)!
        
        exposeSlider.minimumValue = minISO
        exposeSlider.maximumValue = maxISO
        minISOLabel.text = String(Int(minISO))
        maxISOLabel.text = String(Int(maxISO))
        currentISO = (minISO + maxISO)/2
        exposeSlider.value = currentISO
        changeCurrentISOLabelText(currentISO: currentISO)
        
        // ShutterSpeedSliderの最小値・最大値を設定
        shutterSpeedSlider.minimumValue = 1
        shutterSpeedSlider.maximumValue = 100
        minShutterSpeedLabel.text = String(Int(shutterSpeedSlider.minimumValue))+"/2000"
        maxShutterSpeedLabel.text = String(Int(shutterSpeedSlider.maximumValue))+"/2000"
        let midSpeed = (shutterSpeedSlider.minimumValue + shutterSpeedSlider.maximumValue) / 2
        duration = CMTimeMake(Int64(midSpeed), 2000)
        shutterSpeedSlider.value = midSpeed
        changeCurrentShutterSpeedLabelText(currentShutterSpeed: shutterSpeedSlider.value)
        print(duration)
        
        // デバイスの設定
        updateDeviceISOSettings(duration: duration, isoValue: currentISO)
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            if (captureSession.canAddInput(input)) {
                captureSession.addInput(input)
                
                if (captureSession.canAddOutput(stillImageOutput)) {
                    captureSession.addOutput(stillImageOutput)
                    captureSession.startRunning()
                    
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
                    previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.portrait
                    
                    cameraView.layer.addSublayer(previewLayer!)
                    cameraView.layer.setValue(previewLayer, forKey: "previewLayer")
                    
                    previewLayer?.position = CGPoint(x: self.cameraView.frame.width/2, y: self.cameraView.frame.height/2)
                    previewLayer?.bounds = cameraView.frame
                }
            }
            
        }
        catch {
            print(error)
        }
        
        startTimer()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // takeOniPicButtonが押されたら一枚だけ撮影
    @IBAction func takeOniPic(_ sender: Any) {
        takePic()
    }
    
    // shutterSpeedSliderが変更されたらdeviceのdurationを調整
    @IBAction func changedShutterSpeedSlider(_ sender: UISlider) {
        duration = CMTimeMake(Int64(sender.value), 2000)
        updateDeviceISOSettings(duration: duration, isoValue: currentISO)
        changeCurrentShutterSpeedLabelText(currentShutterSpeed: sender.value)
    }
    
    // exposeSliderが変更されたらdeviceのISOを調整
    @IBAction func changedExposeSlider(_ sender: UISlider) {
        currentISO = sender.value
        changeCurrentISOLabelText(currentISO: currentISO)
        updateDeviceISOSettings(duration: AVCaptureExposureDurationCurrent, isoValue: currentISO)
    }
    
    // ボタンがタッチされたら撮影開始
    @IBAction func touchBegin(_ sender: Any) {
        print("touch begin")
        shutterCount = 0
        count.text =  String(shutterCount) + " pics"
        buttonIsPushed = true
    }
    
    // ボタンが離されたら撮影終了
    @IBAction func touchEnd(_ sender: Any) {
        print("touch end")
        buttonIsPushed = false
    }
    
    // 撮影枚数/秒 を変更
    @IBAction func stepperTapped(_ sender: UIStepper) {
        interval = sender.value
        label.text = String(Int(interval)) + " / sec."
        stopTimer()     // これまでのタイマーを破棄
        startTimer()    // 新しく設定されたintervalでタイマーを新規に開始
    }
    
    
    func changeCurrentShutterSpeedLabelText(currentShutterSpeed : Float) {
        currentShutterSpeedLabel.text = "Speed : " + String(Int(currentShutterSpeed)) + "/2000 sec."
    }
    
    func changeCurrentISOLabelText(currentISO : Float) {
        currentISOLabel.text = "ISO : " + String(Int(currentISO))
    }
    
    //DeviceのSessionPressetを設定
    func settingDevicePresset(isOn:Bool) {
        if isOn {
            captureSession.sessionPreset = AVCaptureSessionPreset3840x2160
        } else {
            captureSession.sessionPreset = AVCaptureSessionPresetHigh
        }
    }
    
    // デバイスの設定
    func updateDeviceISOSettings(duration : CMTime, isoValue : Float) {
        if let device = captureDevice {
            try! device.lockForConfiguration()
            device.setExposureModeCustomWithDuration(duration, iso: isoValue, completionHandler: { (time) in
                //
            })
            device.unlockForConfiguration()
        }
    }
    
    // タイマー開始
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1/interval, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
    }
    
    // タイマー停止
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // 撮影
    func takePic() {
        shutterCount = shutterCount + 1
        count.text =  String(shutterCount) + " pics"
        if shutterSoundIsOn {   // シャッター音ありならカメラで
            stillImageOutput?.isHighResolutionCaptureEnabled = true
            let settingsForMonitoring = AVCapturePhotoSettings()
            settingsForMonitoring.flashMode = .off // フラッシュ設定
            settingsForMonitoring.isHighResolutionPhotoEnabled = true  // 高解像度設定
            stillImageOutput?.capturePhoto(with: settingsForMonitoring, delegate: self) // 撮影
        } else {                // シャッター音なしならpreviewをキャプチャ
            UIGraphicsBeginImageContext(cameraView.frame.size)
            let context:CGContext = UIGraphicsGetCurrentContext()!
            cameraView.layer.render(in: context)
            let capturedImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            UIImageWriteToSavedPhotosAlbum(capturedImage, self, #selector(self.image(image:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    // セレクター
    func image(image: UIImage, didFinishSavingWithError error: NSError!, contextInfo: UnsafeMutableRawPointer) {
        if error != nil {
            // プライバシー設定不許可など書き込み失敗時は -3310 (ALAssetsLibraryDataUnavailableError)
            print(error.code)
        }
    }
    
    // タイマーに呼ばれる
    func update(tm: Timer) {
        if buttonIsPushed {           // ボタンが押されていたら
            print("take pic"+nowTime())
            takePic()                   // 撮影
        }
    }
    
    func nowTime() -> String {
        let format = DateFormatter()
        format.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return format.string(from: Date())
    }
    
    // カメラで撮影完了後に呼ばれる。JPEGでフォトライブラリに保存
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let photoSampleBuffer = photoSampleBuffer {
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            let image = UIImage(data: photoData!)
            
            
            // アルバムを検索して保存
            PHPhotoLibrary.shared().performChanges({ 
                let list = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.album, subtype: PHAssetCollectionSubtype.any, options: nil)
                var assetAlbum:PHAssetCollection!
                for i in 0 ..< list.count {
                    let item = list.object(at: i) as PHAssetCollection
                    if item.localizedTitle == "Pic" {
                        assetAlbum = item
                        break
                    }
                }
                
                let result = PHAssetChangeRequest.creationRequestForAsset(from: image!)
                let assetPlaceholder = result.placeholderForCreatedAsset
                let albumChangeRequset = PHAssetCollectionChangeRequest(for: assetAlbum)
                let enumeration: NSArray = [assetPlaceholder!]
                albumChangeRequset?.addAssets(enumeration)
            }, completionHandler: nil)
        }
    }
    
    // アルバム Pic を作成
    func createAlbum() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", "Pic")
        let collection : PHFetchResult = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.album, subtype: PHAssetCollectionSubtype.any, options: fetchOptions)
        
        if let _: AnyObject = collection.firstObject {
            albumFound = true
            assetCollection = collection.firstObject! as PHAssetCollection
        } else {
            PHPhotoLibrary.shared().performChanges({
                let createAlbumRequest : PHAssetCollectionChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "Pic")
                self.assetCollectionPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
            }, completionHandler: { success, error in
                self.albumFound = (success ? true: false)
                
                if (success) {
                    let collectionFetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [self.assetCollectionPlaceholder.localIdentifier], options: nil)
                    print(collectionFetchResult)
                    self.assetCollection = collectionFetchResult.firstObject! as PHAssetCollection
                }
            })
        }
    }

}

