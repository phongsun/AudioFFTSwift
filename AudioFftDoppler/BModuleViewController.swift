//
//  ModuleBViewController.swift
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





class BModuleViewController: UIViewController {
    @IBOutlet weak var motionLabel: UILabel!
    var myTimer:Timer?
    // setup audio model
    let audio = AudioModel.shared
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.view)
    }()
    
    func updateMotionLabel(motion: Action){
        motionLabel.text = "\(motion)"
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            self.myTimer?.invalidate()
            self.audio.myTimer?.invalidate()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withSamplingSeconds: 0.25, module: Module.B)
        
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            // add in graphs for display
            graph.addGraph(withName: "fft",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph:audio.BUFFER_SIZE/2)
            
            graph.addGraph(withName: "time",
                numPointsInGraph: audio.BUFFER_SIZE)
            
            graph.makeGrids() // add grids to graph
        }


        audio.play()
        
        // run the loop for updating the graph peridocially
        self.myTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        
        audio.updateMotionUI = self.updateMotionLabel(motion:)
    }
    
    // periodically, update the graph with refreshed FFT Data
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
        
        self.graph?.updateGraph(
            data: self.audio.timeData,
            forKey: "time"
        )
    }
    
    

}

