//
//  AudioModel.swift
//  AudioLabSwift
//
//  Modified and Extended by Peter Sun
//  Copyright © 2022 Peter Sun. All rights reserved.
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate


enum Module {
    case A, B
}

class AudioModel {
    static let shared = AudioModel()
    private var module = Module.A
    var myTimer:Timer?
    // MARK: Properties
    let DELTA_F:Float = 3.0 //Hz
    let TONE_DIFF:Float = 50.0 //Hz
    let WINDOW_SIZE = 50/3 //
    public private(set) var BUFFER_SIZE:Int = 0
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float] = []
    var fftData:[Float] = []
    var peakF1: Float = 0.0
    var peakF2: Float = 0.0
    
    var leftAvgData:[Float] = []
    var rightAvgData:[Float] = []
    var leftAverageCircularBuffer = CircularBuffer.init(numChannels: 1,
                                     andBufferSize: 10)
    var rightAverageCircularBuffer = CircularBuffer.init(numChannels: 1,
                                         andBufferSize: 10)
    var updatePeaksUI : ((Float, Float) -> Void)?
    
    // MARK: Public Methods
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withSamplingSeconds:Double, module:Module = Module.A){
        self.module = module
        self.myTimer?.invalidate()
        // setup the microphone to copy to circualr buffe
        if let manager = self.audioManager{
            // df=Fs/N => N=Fs/df where df is DELTA_F and N is buffer size and Fs is sample rate, smaller df, bigger buffer size (N) would be
            BUFFER_SIZE = Int(manager.samplingRate)/Int(DELTA_F)
            
            // anything not lazily instatntiated should be allocated here
            timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
            fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
            //rightAvgData and leftAvgData are used to calculate doppler effects
            rightAvgData = Array.init(repeating: 0.0, count: 10)
            leftAvgData = Array.init(repeating: 0.0, count: 10)
            manager.inputBlock = self.handleMicrophone
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            self.myTimer = Timer.scheduledTimer(timeInterval: withSamplingSeconds, target: self,
                                 selector: #selector(self.runEveryInterval),
                                 userInfo: nil,
                                 repeats: true)
        }
    }
    
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // analyzeAudio is the function that detects the two loudest tones
    @objc
    private func analyzeAudio() {
        // extra credit
        
        let fft2analyze = fftData.map { $0 } // make a copy of fftData and then analyze it
        
            // compute the frequency of the two loundest tones in the fft buffer
            // ** the peakInterpolation block function **
            // this function is from the slides
            let peakInterpolation = { (f2Index: Int, m2: Float) -> Float in
                
                let f2: Float = Float(f2Index) * self.DELTA_F // frequence = fft index * delta frequency
                if f2Index == 0 || f2Index == (fft2analyze.count - 1) {
                    print("f2Index == 0")
                    return f2
                }
                
                let m1 = fft2analyze[f2Index - 1] // magnitude on the left
                let m3 = fft2analyze[f2Index + 1] // magnitude on the right
                
                // 1. if the neighbors of m2 has the same magnitude, then m2 is the loudest
                let fPeak = f2 + ((m1-m3)/(m3-2*m2+m1))*(self.DELTA_F/2)
                if (fPeak < 0) {
                    print("m1:\(fft2analyze[f2Index - 1]) - \(f2):\(m2) - m3:\(fft2analyze[f2Index + 1]) => \(fPeak)")
                }
                
                return fPeak
            } // end of block function
            
            // create windows from fftdata by dividing the fftData into sub arrays of the window size
            let windowedFftData:[[Float]] = stride(from: 1, to: fft2analyze.count, by: self.WINDOW_SIZE).map {
                Array(fft2analyze[$0 ..< Swift.min($0 + self.WINDOW_SIZE, fft2analyze.count)])
            }
            // find the local peaks in the windows and then sort descending
            let peakWindows = windowedFftData.filter {$0.max() != Float.infinity && $0.first! < $0.max()! && $0.last! <= $0.max()!}
                .map{$0.max()!} // map the array of the max of each subarray
                .sorted(by: >) // sort by descending
            
            if peakWindows.count > 2 {
                let peak1Idx = fft2analyze.firstIndex(where: {$0 == peakWindows[0]})!
                let peak1 = peakInterpolation(peak1Idx, peakWindows[0])
                
                let peak2Idx = fft2analyze.firstIndex(where: {$0 == peakWindows[1]})!
                let peak2 = peakInterpolation(peak2Idx, peakWindows[1])
                
                print("Peak 1 = \(peak1*2)")
                print("PEAK 2 = \(peak2*2)")
                self.peakF1 = peak1*2
                self.peakF2 = peak2*2
                // TO-DO: Get them to display onto the ViewController
                if let updateFunc = self.updatePeaksUI {
                    DispatchQueue.main.async {
                        updateFunc(self.peakF1, self.peakF2)
                    }
                }
            }
        }
        
    


    @objc
    private func detectDoppler(){
        
        // 1. get the frequency magnitude: search the loudest tone - f w/ max magnitude
        let theF:(UInt, Float) = vDSP.indexOfMaximum(fftData) // returns max value and its index
        
        // 2. get window on both sides
        // 3. average magnitude on window of both sides put in global variable
        let windowSize:Int = 8
        var rAvg:Float = Array(self.fftData[(Int(theF.0) + 1)...(Int(theF.0) + windowSize)]).reduce(0.0, +)/Float(windowSize)
        var lAvg = Array(self.fftData[(Int(theF.0) - windowSize)...(Int(theF.0) - 1)]).reduce(0.0, +)/Float(windowSize)
        
        self.rightAverageCircularBuffer!.addNewFloatData(&rAvg, withNumSamples: 1)
        self.leftAverageCircularBuffer!.addNewFloatData(&lAvg, withNumSamples: 1)
        
        // 4. wait for the average becomes stable (10 samples)
        self.rightAverageCircularBuffer!.fetchFreshData(&rightAvgData,
                                         withNumSamples: 10)

        self.leftAverageCircularBuffer!.fetchFreshData(&leftAvgData,
                                         withNumSamples: 10)

        // 5. if right becomes bigger, hand moves in
        let rightAvgAvg = self.rightAvgData.reduce(0.0, +)/Float(10)
        let leftAvgAvg = self.rightAvgData.reduce(0.0, +)/Float(10)
        
        print("left Avg Avg = \(leftAvgAvg) === \(lAvg)")
        print("right Avg Avg = \(rightAvgAvg) === \(rAvg)")
        // 6. if left becomes bigger, hand moves away
        if (rAvg - rightAvgAvg) > 1 {
            print("strike")
        } else if (lAvg - leftAvgAvg) > 1 {
            print("withdraw")
        } else {
            print("still")
        }
        
    }

    // MARK: Model Callback Methods
    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
            //let serialQueue = DispatchQueue(label: "audio.analysis.queue", qos: .background)
            DispatchQueue.global().async {
            // copy time data to swift array
                self.inputBuffer!.fetchFreshData(&self.timeData,
                                                 withNumSamples: Int64(self.BUFFER_SIZE))
            
            // now take FFT
                self.fftHelper!.performForwardFFT(withData: &self.timeData,
                                                  andCopydBMagnitudeToBuffer: &self.fftData)
            
                switch self.module {
            case Module.B: self.detectDoppler()
                break
            case Module.A: self.analyzeAudio()
                break
            default:return
            }
        }
    }
    
}
}
