//
//  LoaderViewModel.swift
//  UI
//
//  Created by Amisha Italiya on 13/02/24.
//

import Foundation

public class LoaderViewModel: ObservableObject {
    private let MIN_WAIT_TIME: TimeInterval = 0.4 // In seconds
    
    @Published var isStillLoading: Bool = false
    
    var timer: Timer?
    
    public init() {}
    
    deinit {
        stopTimer()
        stopLoader()
    }
    
    func onViewAppear() {
        startLoader()
    }
    
    func startLoader() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: MIN_WAIT_TIME, repeats: false, block: { [weak self] _ in
            self?.isStillLoading = true
            self?.stopTimer()
        })
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func stopLoader() {
        isStillLoading = false
    }
}
