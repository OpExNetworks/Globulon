//
//  LocationManagerClassVref.swift
//  ViDrive
//
//  Created by David Holeman on 4/11/24.
//  Copyright © 2024 OpEx Networks, LLC. All rights reserved.
//

//  TODO: Add the following to pinfo.list
//  All three are required
//  Privacy - Location When in Use Description = "This app requires access to device location"
//  Privacy - Location Always and When in Use Description = "This app requires access to device location"
//  Privacy - Location Always Usage Description = "This app always requires access to device location"


import Foundation
import CoreLocation
import SwiftData
import MapKit


class LocationManagerV2: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var region = MKCoordinateRegion()
    @Published var location: CLLocation?
    @Published var isDriverMode: Bool = false
    @Published var isLocationEnabled: Bool = false
    
    static let shared = LocationManager()
    
    private var locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    private let locationUpdateThreshold: CLLocationDistance = 50 // meters
    private var lastLocation: CLLocation?
    
    private var locationDataBuffer: [LocationDataBuffer] = []
    private let locationDataBufferLimit = 12  // TODO: This should never be larger than the trip separator
    
    
    override init() {
        super.init()
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        //startUpdatingtLocation()
        LogEvent.print(module: "LocationManager.init()", message: "init finished")
    }
    
    
    
    func requestAppropriateLocationPermission() {
        let currentStatus = locationManager.authorizationStatus
        
        /// if not determined then ask for when in use.  If when in use is set then ask for always in use
        ///
        if currentStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if currentStatus == .authorizedWhenInUse {
            requestAuthorizedAlways()
        }
        LogEvent.print(module: "LocationManager.requestAppropriateLocationPermissino", message: "requested")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        
        //let authorizationStatus = locationManager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .notDetermined:
            LogEvent.print(module: "LocationManager.locationManagerDidChangeAuthorization", message: "Location permission: .notDetermined")
            //manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Location permission: .restricted or .denied")
        case .authorizedWhenInUse:
            LogEvent.print(module: "LocationManager.locationManagerDidChangeAuthorization", message: "Location permission: .authorizedWhenInUse")
            //locationManager.requestAlwaysAuthorization()
            startUpdatingtLocation()
        case .authorizedAlways:
            LogEvent.print(module: "LocationManager.locationManagerDidChangeAuthorization", message: "Location permission: .athorizedAlways")

            //TODO:  May remove this if turning it on down in startup does the trick
            //locationManager.startMonitoringSignificantLocationChanges()
            startUpdatingtLocation()
        default:
            print("Location permission: Unknown")
        }
    }
    
    func requestWhenInUseAuthorization() {
        // Show UI to explain the need for always authorization before requesting it
        LogEvent.print(module: "LocationManager.requestWhenInUseAuthorization", message: "Request when in use authorization...")
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAuthorizedAlways() {
        // Show UI to explain the need for always authorization before requesting it
        LogEvent.print(module: "LocationManager.requestAlwaysAuthorization", message: "Request always authorization...")
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdatingtLocation() {
        let authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .authorizedAlways {
            
            //TODO:  enable this here if it doesn't update in background.
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startUpdatingLocation()
        } else if authorizationStatus == .authorizedWhenInUse {
            
            /// Starting this service is needed to keep recording in the background running.  It detects significant changes and keeps up the recording.
            ///
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startUpdatingLocation()
        }
        LogEvent.print(module: "LocationManager.startUpdatingLocation", message: "Location tracking started...")
    }
    
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        LogEvent.print(module: "LocationManager.stopUpdatingLocation", message: "Location tracking stopped...")
    }
    
    func getAuthorizedWhenInUseV2(completion: @escaping (Bool) -> Void) {
        let authorizationStatus: CLAuthorizationStatus
        authorizationStatus = locationManager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse:
            completion(true)
        default:
            completion(false)
        }
    }
    
    func getAuthorizedAlwaysV2(completion: @escaping (Bool) -> Void) {
        let authorizationStatus: CLAuthorizationStatus
        authorizationStatus = locationManager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedAlways:
            completion(true)
        default:
            completion(false)
        }
    }
    
    func getAuthorizedWhenInUse() -> Bool {
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            return true
        } else {
            return false
        }
    }
    func getAuthorizedAlways() -> Bool {
        if locationManager.authorizationStatus == .authorizedAlways {
            return true
        } else {
            return false
        }
    }
    
    func getAuthorized() -> Bool {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse:
            return true
        case .authorizedAlways:
            return true
        default:
            return false
        }
    }
    func getLocationAuthorization() {
        /// Set to @Published value
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse:
            isLocationEnabled = true
        case .authorizedAlways:
            isLocationEnabled = true
        default:
            isLocationEnabled = false
        }
    }
    
    func getAddressFromLatLon(latitude: CLLocationDegrees, longitude: CLLocationDegrees) async -> String {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                return "No address found"
            }
            
            var addressString = ""
            if let street = placemark.thoroughfare {
                addressString += street + ", "
            }
            if let city = placemark.locality {
                addressString += city + ", "
            }
            if let state = placemark.administrativeArea {
                addressString += state + ", "
            }
            if let postalCode = placemark.postalCode {
                addressString += postalCode + ", "
            }
            if let country = placemark.country {
                addressString += country
            }
            
            return addressString
        } catch {
            print("Reverse geocoding failed: \(error)")
            return "Reverse geocoding failed"
        }
    }
    
    func getFullAddressFromLatLon(latitude: CLLocationDegrees, longitude: CLLocationDegrees) async -> String {
        let locationX = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(locationX)
            guard let placemark = placemarks.first else {
                return "No address found"
            }
            
            var addressString = ""
            if let streetNumber = placemark.subThoroughfare {
                addressString += streetNumber + " "
            }
            if let street = placemark.thoroughfare {
                addressString += street + ", "
            }
            if let city = placemark.locality {
                addressString += city + ", "
            }
            if let state = placemark.administrativeArea {
                addressString += state + ", "
            }
            if let postalCode = placemark.postalCode {
                addressString += postalCode + ", "
            }
            if let country = placemark.country {
                addressString += country
            }
            
            return addressString
        } catch {
            print("Reverse geocoding failed: \(error)")
            return "Reverse geocoding failed"
        }
    }
    
    private func updateRegion(_ location: CLLocation) {
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    var tripInitiated = false
    var tripCompleted = false
    var tripActivated = false
    
    var tripBufferred = false
    
    var lastTimestamp = Date()
    var lastSpeed = 0.0
    var lastLatitude = 0.0
    var lastLongitude = 0.0
    
    var locationUpdateCounter = 0
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        /// Too slow, not driving so bail on the rest.  Remove this if you want to capture all samples driving or not.
        ///
        guard let speed = locations.last?.speed, speed > 0.0 else {
            return
        }
        
        /// When driving above the tracking speed threshold grab data from the buffer and start interval collection of GPS data
        ///
        if speed >= UserSettings.init().trackingSpeedThreshold {
            
            if self.tripBufferred {
                print("** xfr buffer info")
                saveLocationDataBuffer()
                self.tripBufferred = false
            }
            
            /// Above threshold speed tracking
            ///
            if let currentLocation = locations.last {
                locationUpdateCounter = locationUpdateCounter + 1
                if locationUpdateCounter >= UserSettings.init().trackingSampleRate {
                    saveLocationDataBuffer()
                    saveLocation(location: currentLocation)
                    locationUpdateCounter = 0
                }
            }
            

        }
        
        if speed < UserSettings.init().trackingSpeedThreshold {
            if let currentLocation = locations.last {
                print("** below speed \(currentLocation.timestamp) \(currentLocation.speed)")
                udateLocationDataBuffer(location: currentLocation)
                self.tripBufferred = true
            }
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle failure to get location
    }
    
    func saveLocation(location: CLLocation) {
        do {
            // Access the sharedModelContainer
            guard let container = AppEnvironment.sharedModelContainer else {
                LogEvent.print(module: "LocationManager.saveLocation()", message: "shared model container has not been initialized")
                return
            }
            
            let context = ModelContext(container)
            
            let entry = GpsJournalSD(
                timestamp: Date(),
                longitude: location.coordinate.longitude,
                latitude: location.coordinate.latitude,
                speed: location.speed,
                processed: false,
                code: "",
                note: ""
            )
            
            context.insert(entry)
            
//            lastTimestamp = entry.timestamp
//            lastLatitude = entry.latitude
//            lastLatitude = entry.latitude
//            lastSpeed = entry.speed
            
            print("**+ Location saved: \(entry.timestamp) \(formatMPH(convertMPStoMPH( entry.speed))) mph")
        }
    }
    
    
    /// Buffering stuff...
    ///
    func udateLocationDataBuffer(location: CLLocation?) {
        
        /// Guard to make sure location is not nil and speed is not negative
        ///
        guard let location = location, location.speed >= 0 else { return }
        
        /// Check if the array has reached its capacity.  If so Remove the oldest entry to make space for the new one.
        ///
        if locationDataBuffer.count >= locationDataBufferLimit {
            locationDataBuffer.removeLast()
        }
        
        /// Insert the new data at the beginning of the array, treating it as a queue
        ///
        let entry = LocationDataBuffer(
            timestamp: Date(),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speed: location.speed,
            processed: false,
            code: "",
            note: ""
        )
        locationDataBuffer.insert(entry, at: 0)
    }
    
    func saveLocationDataBuffer() {
        
        print("** buffer count: \(locationDataBuffer.count)")
        
        guard let container = AppEnvironment.sharedModelContainer else {
            LogEvent.print(module: "LocationManager.saveLocation()", message: "shared model container has not been initialized")
            return
        }
        
        let context = ModelContext(container)
        
        var index = 0
        while index < locationDataBuffer.count {
            
            if locationDataBuffer[index].speed >= 0.0 {
                
                print("**> add bufferred item: \(locationDataBuffer[index].timestamp), \(locationDataBuffer[index].speed), \(locationDataBuffer[index].latitude) : \(locationDataBuffer[index].longitude)")
                
                let entry = GpsJournalSD(
                    timestamp: locationDataBuffer[index].timestamp,
                    longitude: locationDataBuffer[index].longitude,
                    latitude: locationDataBuffer[index].latitude,
                    speed: locationDataBuffer[index].speed,
                    processed: false,
                    code: "",
                    note: ""
                )
                context.insert(entry)
            }
            index += 1
        }
        locationDataBuffer.removeAll()
        
                
                //                guard let container = AppEnvironment.sharedModelContainer else {
                //                    LogEvent.print(module: "LocationManager.saveLocation()", message: "shared model container has not been initialized")
                //                    return
                //                }
                //
                //                let context = ModelContext(container)
                //
                //                print("**% \(locationDataBuffer[index].timestamp), \(locationDataBuffer[index].speed), \(locationDataBuffer[index].latitude) : \(locationDataBuffer[index].longitude)")
                //
                //                let entry = GpsJournalSD(
                //                    timestamp: locationDataBuffer[index].timestamp,
                //                    longitude: locationDataBuffer[index].longitude,
                //                    latitude: locationDataBuffer[index].latitude,
                //                    speed: locationDataBuffer[index].speed,
                //                    processed: false
                //                )
                //
                //                context.insert(entry)
                //
                //                var saveIndex = 0
                //
                //                print("** index \(index)")
                //
                //                while saveIndex < index {
                //                    print("**> \(locationDataBuffer[saveIndex].timestamp), \(locationDataBuffer[saveIndex].speed), \(locationDataBuffer[saveIndex].latitude) : \(locationDataBuffer[saveIndex].longitude)")
                //
                //                    let entry = GpsJournalSD(
                //                        timestamp: locationDataBuffer[saveIndex].timestamp,
                //                        longitude: locationDataBuffer[saveIndex].longitude,
                //                        latitude: locationDataBuffer[saveIndex].latitude,
                //                        speed: locationDataBuffer[saveIndex].speed,
                //                        processed: false
                //                    )
                //
                //                    context.insert(entry)
                //
                //                    saveIndex += 1
                //                }
                //
                //
                //                locationDataBuffer.removeAll()
                //                break
                
    }
}