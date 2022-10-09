//
//  ModuleAViewController.swift
//  AudioFftDoppler
//
//  Modified and Extended by Peter Sun
//  Copyright © 2022 Peter Sun. All rights reserved.
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import UIKit
import Metal





class AModuleViewController: UIViewController {
    @IBOutlet weak var peak2Label: UILabel!
    @IBOutlet weak var peak1Label: UILabel!
    var myTimer:Timer?
    // setup audio model
    let audio = AudioModel.shared
    var enabled4DisplayPeaks = true
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.view)
    }()
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            self.myTimer?.invalidate()
            self.audio.myTimer?.invalidate()
        }
    }
    
    @IBOutlet weak var detectButton: UIButton!
    @IBAction func detectButtonClicked(_ sender: UIButton) {
        print("button clicked")
        if detectButton.titleLabel?.text == "Detect" {
            audio.updatePeaksUI = self.updatePeaks(peak1:peak2:)
            detectButton.setTitle("Stop", for: .normal)
        } else {
            // current label is stop
            audio.updatePeaksUI = nil
            detectButton.setTitle("Detect", for: .normal)
        }
    }
    
    func updatePeaks(peak1: Float, peak2: Float) {
        if self.enabled4DisplayPeaks == true {
            self.enabled4DisplayPeaks = false
            UIView.transition(with: self.peak1Label,
                              duration: 2,
                                          options: .transitionCrossDissolve,
                                          animations: { [weak self] in
                self?.peak1Label.text = "\(peak1) Hz"
                        }, completion: nil)
            UIView.transition(with: self.peak2Label,
                                          duration: 2,
                                          options: .transitionCrossDissolve,
                                          animations: { [weak self] in
                self?.peak2Label.text = "\(peak2) Hz"
            }, completion: {_ in self.enabled4DisplayPeaks = true})
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withSamplingSeconds: 0.25, module: Module.A)

        audio.play()
    }
    

}

