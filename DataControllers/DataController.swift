//
//  DataController.swift
//  theracingline
//
//  Created by Dave on 25/10/2022.
//

import Foundation
import SwiftUI
import SwiftDate

class DataController: ObservableObject {
    
    static var shared = DataController()
    
    @Published var series: [Series] = []
    @Published var circuits: [Circuit] = []
    
    @Published var events: [RaceEvent] = []
    @Published var eventsInProgress: [RaceEvent] = []
    @Published var eventsInProgressAndUpcoming: [RaceEvent] = []

    @Published var sessions: [Session] = []
    @Published var seessionsInProgressAndUpcoming: [Session] = []
    @Published var liveSessions: [Session] = []
    @Published var sessionsWithinNextTwelveHours: [Session] = []
    
    init() {
        downloadData()
    }
    
    var timeLineHeight: CGFloat {
        return CGFloat(sessionsWithinNextTwelveHours.count * 50)
    }
    
    // DOWNLOAD DATA
    
    func downloadData() {
        print("DownloadDataRun")
        
        let keys = Keys()
        let key = keys.getKey()
        let binUrl = keys.getFullDataUrl()
        
        guard let url = URL(string: binUrl) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(key, forHTTPHeaderField: "X-ACCESS-KEY")
        request.addValue("false", forHTTPHeaderField: "X-BIN-META")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print("API CALL FAILED")
                print(error!)
                return
            }

            guard let data = data else {
                return
            }
            
            do {
                let json = try JSONDecoder().decode(FullDataDownload.self, from: data)
                
                let now = Date()
                
                var sortedEvents = json.events
                sortedEvents.sort {$0.firstRaceDate() < $1.firstRaceDate()}
                
                var sortedSessions = self.createSessions(events: self.events)
                sortedSessions.sort{ $0.raceStartTime() < $1.raceStartTime()}
                
                let twelveHoursAway = Date() + 12.hours

                DispatchQueue.main.async {
                    // series
                    self.series = json.series
                    print("Series Done")
                    
                    
                    // circuits
                    self.circuits = json.circuits
                    print("Circuits Done")
                    
                    // events
                    self.events = sortedEvents
                    
                    self.eventsInProgress = sortedEvents.filter {
                        if $0.eventInProgress() != nil && $0.eventInProgress()! {
                            return true
                        } else {
                            return false
                        }
                    ;}
                    
                    self.eventsInProgressAndUpcoming = sortedEvents.filter { !$0.eventComplete() }
                                        
                    print("Events Done")
                    
                    // sessions
                    
                    self.sessions = sortedSessions
                    
                    self.seessionsInProgressAndUpcoming = sortedSessions.filter { !$0.isComplete() }
                    
                    self.liveSessions = sortedSessions.filter { $0.isInProgress() }
                    print("Sessions Done")
                    
                    self.sessionsWithinNextTwelveHours = sortedSessions.filter { $0.raceStartTime() < twelveHoursAway && $0.raceStartTime() > now }
                    
                    print("Decoded")
                }
            } catch let jsonError as NSError {
                print(jsonError)
                print(jsonError.underlyingErrors)
                print(jsonError.localizedDescription)
            }

        }.resume()
    } // DOWNLOADDATA
    
    func getSeriesById(seriesId: String) -> Series? {
        if let index = self.series.firstIndex(where: {$0.seriesInfo.id == seriesId}) {
            return series[index]
        } else {
            return nil
        }
    }
    
    func getCircuitByName(circuit: String) -> Circuit? {
        if let index = self.circuits.firstIndex(where: {$0.circuit == circuit}) {
            return circuits[index]
        } else {
            return nil
        }
    }
    
    func createSessions(events: [RaceEvent]) -> [Session] {
        
        var sessions: [Session] = []
        for event in events {
            sessions.append(contentsOf: event.sessions)
        }
        sessions.sort { $0.raceStartTime() < $1.raceStartTime() }
        
        return sessions
    }
} // CONTROLER
