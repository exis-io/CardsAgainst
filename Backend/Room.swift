//
//  Room.swift
//  ExAgainst
//
//  Created by Mickey Barboi on 11/19/15.
//  Copyright © 2015 exis. All rights reserved.
//

import Foundation
import Riffle

var baseQuestions = loadCards("q13")
var baseAnswers = loadCards("a13")


class Room: RiffleDomain {
    var timer: DelayedCaller!
    var dynamicRoleId: String!
    var state: String = "Empty"
    
    var players: [Player] = []
    var czar: Player?
    var questions = baseQuestions
    var answers = baseAnswers
    
    
    override func onJoin() {
        timer = DelayedCaller(target: self)
        register("pick#details", pick)
        register("leave#details", removePlayer)
    }
    
    func removePlayer(domain: String) {
        if let player = getPlayer(players, domain: domain) {
            print("Player marked as zombie: \(domain)")
            player.zombie = true
            player.demo = true
        } else {
            print("WARN-- asked to remove player \(domain), not found in players!")
        }
    }
    
    func addPlayer(domain: String) -> AnyObject {
        // Add the new player and draw them a hand. Let everyone else in the room know theres a new player
        print("Adding Player \(domain)")
        
        let newPlayer = Player()
        newPlayer.domain = domain
        newPlayer.demo = false
        newPlayer.hand = answers.randomElements(4, remove: true)
        
        players.append(newPlayer)
        publish("joined", newPlayer)

        // Add dynamic role
        app.call("xs.demo.Bouncer/assignDynamicRole", self.dynamicRoleId, "player", container.domain, [domain], handler: nil)
        
        if state == "Empty" {
            timer.startTimer(EMPTY_TIME, selector: "startAnswering")
            roomMaintenance()
        }
        
        return [newPlayer.hand, players, state, self.name!]
    }
    
    func pick(domain: String, card: String) {
        guard let player = getPlayer(players, domain: domain) else { return }
        
        if state == "Answering" && player.pick == nil && !player.czar {
            guard let pick = player.hand.removeObject(card) else { return }
            player.pick = pick
            print("Player: \(player.domain) answered: \(card)")
            
        } else if state == "Picking" && player.czar {
            let winner = players.filter { $0.pick == card }[0]
            timer.startTimer(0.0, selector: "startScoring:", info: winner.domain)
        }
    }
    
    

    
    
    // MARK: Player Utils
    func roomMaintenance() {
        // If there aren't enough players to play a full
        while players.count < 3 {
            let player = Player()
            player.domain = app.domain + ".demo\(randomStringWithLength(4))"
            player.hand = answers.randomElements(10, remove: true)
            player.demo = true
            players.append(player)
            
            if state != "Empty" {
                publish("joined", player)
            }
        }
        
        // Set the next czar round-robin, or randomly if no player is currently the czar
        if czar == nil {
            czar = players.randomElements(1)[0]
            czar!.czar = true
        } else {
            let i = players.indexOf(czar!)!
            let newCzar = players[(i + 1) % (players.count)]
            czar!.czar = false
            newCzar.czar = true
            czar = newCzar
        }
        
        print("New Czar: \(czar!.domain)")
    }
}