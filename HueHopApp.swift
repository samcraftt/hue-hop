import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport

// AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        // Request tracking authorization after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.requestTrackingAuthorization()
        }
        return true
    }
    func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("Authorized")
                    print(ASIdentifierManager.shared().advertisingIdentifier)
                case .denied:
                    print("Denied")
                case .notDetermined:
                    print("Not Determined")
                case .restricted:
                    print("Restricted")
                @unknown default:
                    print("Unknown")
                }
                UserDefaults.standard.set(true, forKey: "trackingRequested")
            }
        }
    }
}

// UserDefaultsManager
class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    private let trackingRequestedKey = "trackingRequested"
    var isTrackingRequested: Bool {
        get {
            return UserDefaults.standard.bool(forKey: trackingRequestedKey)
        }
    }
}

// BannerView
struct BannerView: UIViewRepresentable {
    @Binding var adLoaded: Bool
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView()
        banner.adUnitID = "ca-app-pub-3940256099942544/2435281174"
        // This is a test banner ID, replace with actual ID in deployment
        banner.rootViewController = getRootViewController()
        banner.delegate = context.coordinator
        return banner
    }
    func updateUIView(_ bannerView: GADBannerView, context: Context) {
        let frame = { () -> CGRect in
            if let window = getRootViewController()?.view.window {
                return window.frame
            } else {
                return UIScreen.main.bounds
            }
        }()
        let viewWidth = frame.size.width
        bannerView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
        loadAd(for: bannerView)
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    private func loadAd(for bannerView: GADBannerView) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    let request = GADRequest()
                    // General ads if tracking is not authorized
                    if status != .authorized {
                        let extras = GADExtras()
                        extras.additionalParameters = ["npa": "1"]
                        request.register(extras)
                    }
                    bannerView.load(request)
                }
            }
        } else {
            let request = GADRequest()
            bannerView.load(request)
        }
    }
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        return window.rootViewController
    }
    class Coordinator: NSObject, GADBannerViewDelegate {
        var parent: BannerView
        init(_ parent: BannerView) {
            self.parent = parent
        }
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            parent.adLoaded = true
        }
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("Failed to load ad: \(error)")
            parent.adLoaded = false
        }
    }
}

// HueHopperApp
@main
struct HueHopperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

//  ContentView
struct ContentView: View {
    @State private var sequence = [Int]()
    @State private var userInput = [Int]()
    @State private var currentStep = 0
    @State private var isPlaying = false
    @State private var isShowingSequence = false
    @State private var message = "Press Start to play!"
    @State private var currentScore = 0
    @State private var highestScore = UserDefaults.standard.integer(forKey: "highestScore")
    @State private var adLoaded = false
    let colors: [Color] = [.red, .green, .blue, .yellow]
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                ForEach(0..<2) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<2) { col in
                            Button(action: {
                                self.handleUserInput(index: row * 2 + col)
                            }) {
                                Rectangle()
                                    .fill(self.colors[row * 2 + col])
                                    .frame(width: 150, height: 150)
                                    .opacity(isShowingSequence && sequence.indices.contains(currentStep) && sequence[currentStep] == row * 2 + col ? 1.0 : 0.5)
                            }
                        }
                    }
                }
            }
            Spacer()
            Text(message)
                .font(.headline)
                .padding()
            if !isPlaying && !isShowingSequence {
                Button(action: startGame) {
                    Text("Start")
                        .font(.title)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            Text("Current Score: \(currentScore)")
                .font(.headline)
                .padding()
            Text("Highest Score: \(highestScore)")
                .font(.headline)
                .padding()
            Spacer()
            // Add the banner ad at the bottom
            BannerView(adLoaded: $adLoaded)
                .frame(height: 50)
                .opacity(adLoaded ? 1 : 0)
        }
        .padding()
    }
    func startGame() {
        sequence = []
        userInput = []
        currentStep = 0
        currentScore = 0
        isPlaying = true
        message = "Watch the sequence"
        addNewStep()
    }
    func addNewStep() {
        sequence.append(Int.random(in: 0...3))
        showSequence()
    }
    func showSequence() {
        isShowingSequence = true
        currentStep = 0
        var delay = 0.0
        for step in sequence.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.currentStep = step
                self.isShowingSequence = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) {
                self.isShowingSequence = false
            }
            delay += 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.message = "Your turn"
            self.currentStep = 0
            self.userInput = []
            self.isPlaying = true
            self.isShowingSequence = false
        }
    }
    func handleUserInput(index: Int) {
        guard isPlaying && !isShowingSequence else { return }
        userInput.append(index)
        if userInput[currentStep] != sequence[currentStep] {
            message = "Wrong! Game Over. Press Start to play again."
            isPlaying = false
            if currentScore > highestScore {
                highestScore = currentScore
                UserDefaults.standard.set(currentScore, forKey: "highestScore")
            }
            return
        }
        currentStep += 1
        if currentStep == sequence.count {
            currentScore += 1
            message = "Correct! Watch the next sequence."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.addNewStep()
            }
        }
    }
}
