//
//  TestForLoops.swift
//  evoai
//
//  Created by Rocco Bowling on 1/26/17.
//  Copyright © 2017 Rocco Bowling. All rights reserved.
//

import Foundation

#if os(OSX) || os(iOS)
import Darwin
#elseif os(Linux)
import Glibc

@inlinable @inline(__always)
func autoreleasepool(_ callback: () -> ()) {
    callback()
}

#endif

@usableFromInline
typealias AnyPtr = UnsafeMutableRawPointer?

@inlinable @inline(__always)
func Ptr <T: AnyObject>(_ obj: T) -> AnyPtr {
    return Unmanaged.passRetained(obj).toOpaque()
}

@inlinable @inline(__always)
func Class <T: AnyObject>(_ ptr: AnyPtr) -> T? {
    guard let ptr = ptr else { return nil }
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}

@discardableResult
@inlinable @inline(__always)
func Release <T: AnyObject>(_ ptr: AnyPtr) -> T? {
    guard let ptr = ptr else { return nil }
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}

public class GeneticAlgorithm<T: AnyObject> {

    public typealias AdjustPopulationmFunc<T> = ((inout[T], inout[Float], Int, Randomable) -> Void)
    public typealias GenerateOrganismFunc<T> = ((Int, Randomable) -> T)
    public typealias BreedOrganismsFunc<T> = ((T, T, T, Randomable) -> Void)
    public typealias ScoreOrganismFunc<T> = ((T, Int, Randomable) -> Float)
    public typealias ChosenOrganismFunc<T> = ((T, Float, Int, Int, Randomable) -> Bool)

    // population size: tweak this to your needs
    public var numberOfOrganisms = 20
    
    // end after this many generations pass when a new best organism has not been found (-1 means never end early)
    public var endAfterRepeatedFailsToFindNewBestOragnism = -1

    // an optional method that gives the callee direct access to the entire population array prior to the entire poopulation array being rescored and resorted.
    // useful if the callee wants to populate the array with specific elements
    public var adjustPopulation: AdjustPopulationmFunc<T>?

    // generate organisms: delegate received the population index of the new organism, and a uint suitable for seeding a RNG. delegete should return a newly allocated organism with assigned chromosomes.
    public var generateOrganism: GenerateOrganismFunc<T>!

    // breed organisms: delegate is given two parents, a child, and a uint suitable for seeding a RNG. delegete should fill out the chromosomes of the child with chromosomes selected from each parent,
    // along with any possible mutations which might occur.
    public var breedOrganisms: BreedOrganismsFunc<T>!

    // score organism: delegate is given and organism and should return a float value representing the "fitness" of the organism. Higher scores must always be better scores!
    public var scoreOrganism: ScoreOrganismFunc<T>!

    // choose organism: delegate is given an organism, its fitness score, and the number of generations processed so far. return true to signify this organism's answer is
    // sufficient and the genetic algorithm should stop; return false to tell the genetic algorithm to keep processing.
    public var chosenOrganism: ChosenOrganismFunc<T>!

    // tweening method used by PerformGenetics() to aid in the selection of parents to breed; easeInExpo will favor parents with bad fitness values
    private func easeInExpo (_ start: Float, _ end: Float, _ val: Float) -> Float {
        return (end - start) * pow(2, 10 * (val / 1 - 1)) + start
    }

    // tweening method used by PerformGenetics() to aid in the selection of parents to breed; easeOutExpo will favor parents with good fitness values
    private func easeOutExpo (_ start: Float, _ end: Float, _ val: Float) -> Float {
        return (end - start) * (-pow(2, -10 * val / 1) + 1) + start
    }

    public init() {
        
    }
    
    // main workhorse method: build a population, select and breed parents over multiple generations, insert children into the new population if they are good enough
    private func process (_ millisecondsToProcess: Int,
                          _ adjustPopulation: AdjustPopulationmFunc<T>?,
                          _ generateOrganism: GenerateOrganismFunc<T>,
                          _ breedOrganisms: BreedOrganismsFunc<T>,
                          _ scoreOrganism: ScoreOrganismFunc<T>,
                          _ chosenOrganism: ChosenOrganismFunc<T>,
                          _ sharedOrganismIdx: Int = -1,
                          _ neighborOrganismIdx: Int = -1 ) -> T {

        // Done in 3008ms and 10761140 generations
        let prng = CRandom()

        // Done in 8011ms and 6114224 generations
        // let prng = Xoroshiro256StarStar(UUID().uuidString)

        // simple counter to keep track of the number of generations (parents selected to breed a child) have passed
        var numberOfGenerations = 0

        // Replacement window is the number of organisms in the population we should "shuffle down" when we insert a newly born child into the population
        // This is generally an optimization step for large populations, as shifting the entire array each time a new child is inserted is expensive (and
        // generally not necessary).
        let localNumberOfOrganismsMinusOne = numberOfOrganisms - 1
        let localNumberOfOrganismsMinusOnef = Float(numberOfOrganisms - 1)
        let replacementWindow = 2

        // Create the population arrays; one for the organism classes and another to hold the scores of said organisms
        var allOrganisms = [T]()
        var allOrganismScores = [Float](repeating: 0, count: numberOfOrganisms)

        // Call the delegate to generate all of the organisms in the population array; score them as well
        for i in 0..<numberOfOrganisms {
            allOrganisms.append(generateOrganism(i, prng))
        }
        if let adjustPopulation = adjustPopulation {
            adjustPopulation(&allOrganisms, &allOrganismScores, 0, prng)
        }
        for i in 0..<numberOfOrganisms {
            allOrganismScores[i] = scoreOrganism(allOrganisms[i], sharedOrganismIdx, prng)
        }

        // sort the organisms so the higher fitness are all the end of the array; it is critical
        // for performance that this array remains sorted during processing (it eliminates the need
        // to search the population for the best organism).
        comboSort(&allOrganismScores, &allOrganisms)

        let watchStart = DispatchTime.now()

        // create a new "child" organism. this is an optimization, in order to remove the need to allocate new children
        // during breeding, as designate one extra organsism as the "child".  We then shuffle this in and out of the
        // population array when required, eliminating the need for costly object allocations
        var newChild: T = generateOrganism(0, prng)
        var trashedChild: T = newChild
        var childScore = scoreOrganism(newChild, sharedOrganismIdx, prng)

        // The multi-threaded version of this relies on a ring network of threads to process; if this is the multithreaded version
        // then we need to include an extra generation step during processing (see comments PerformGeneticsThreaded for overview)
        var maxBreedingPerGeneration = 3
        if neighborOrganismIdx >= 0 {
            maxBreedingPerGeneration = 4
        }

        // If this is the multi-threded version, put our best plan into our index in the shared organsisms array
        if sharedOrganismIdx >= 0 {
            let _: T? = Release(sharedOrganisms[sharedOrganismIdx])
            sharedOrganisms[sharedOrganismIdx] = Ptr(allOrganisms[localNumberOfOrganismsMinusOne])
        }

        // used in parent selection for breeders below
        var a: Float = 0.0, b: Float = 0.0
        var didFindNewBestOrganism = false
        var didFindNewBestOrganismCount = 0

        // Check to see if we happen to already have the answer in the starting population
        if chosenOrganism(allOrganisms[localNumberOfOrganismsMinusOne], allOrganismScores[localNumberOfOrganismsMinusOne], numberOfGenerations, sharedOrganismIdx, prng) == false {

            // continue processing unless we've processed for too long
            var finished = false

            while finished == false &&
                (millisecondsToProcess < 0 || ((DispatchTime.now().uptimeNanoseconds - watchStart.uptimeNanoseconds) / 1000000) < millisecondsToProcess) {

                autoreleasepool {
                    // optimization: we only call chosen organsism below when the new best organism changes
                    didFindNewBestOrganism = false

                    // multi-threaded check to see if someone else in the ring thread network has already found the solution; if they
                    // have, we can end processing early.
                    if sharedOrganismsDone {
                        finished = true
                        return
                    }

                    // we use three (or four) methods of parent selection for breeding; this iterates over all of those
                    for i in 0..<maxBreedingPerGeneration {

                        // Below we have four different methods for selecting parents to breed. Each are explained individually
                        if i == 0 {
                            // Breed the pretty ones together: favor choosing two parents with good fitness values
                            a = (easeOutExpo(0.25, 1.0, prng.get()) * localNumberOfOrganismsMinusOnef)
                            b = (easeOutExpo(0.25, 1.0, prng.get()) * localNumberOfOrganismsMinusOnef)
                            // a = 0
                            // b = localNumberOfOrganismsMinusOnef
                            breedOrganisms(allOrganisms[Int(a)], allOrganisms[Int(b)], newChild, prng)
                        } else if i == 1 {
                            // Breed a pretty one and an ugly one: favor one parent with a good fitness value, and another parent with a bad fitness value
                            a = (easeInExpo(0.0, 0.75, prng.get()) * localNumberOfOrganismsMinusOnef)
                            b = (easeOutExpo(0.25, 1.0, prng.get()) * localNumberOfOrganismsMinusOnef)
                            breedOrganisms(allOrganisms[Int(a)], allOrganisms[Int(b)], newChild, prng)
                        } else if i == 2 {
                            // Breed the best organism asexually: IT IS BEST IF THE BREEDORGANISM DELEGATE CAN RECOGNIZE THIS AND FORCE A HIGHER RATE OF SINGLE CHROMOSOME MUTATION
                            a = localNumberOfOrganismsMinusOnef
                            b = localNumberOfOrganismsMinusOnef
                            breedOrganisms(allOrganisms[Int(a)], allOrganisms[Int(b)], newChild, prng)
                        } else if i == 3 {
                            // Breed the best organism of my neighboring thread in the ring network asexually into our population
                            if neighborOrganismIdx >= sharedOrganismsCount {
                               continue
                            }
                            if let neighborOrganismPtr = sharedOrganisms[neighborOrganismIdx],
                               let neighborOrganism: T = Class(neighborOrganismPtr) {
                                breedOrganisms(neighborOrganism, neighborOrganism, newChild, prng)
                            }
                        }

                        // record the fitness value of the newly bred child
                        childScore = scoreOrganism(newChild, sharedOrganismIdx, prng)

                        // if we're better than the worst member of the population, then the child should be inserted into the population
                        if childScore > allOrganismScores[0] {

                            // perform a binary search to find where we should insert this new child (we want to keep our population array sorted)
                            var left = 0
                            var right = localNumberOfOrganismsMinusOne
                            var middle = 0
                            while left < right {
                                middle = (left + right) >> 1
                                if allOrganismScores[middle] < childScore {
                                    left = middle + 1
                                } else if allOrganismScores[middle] > childScore {
                                    right = middle - 1
                                } else {
                                    left = middle - 1
                                    break
                                }
                            }

                            // sanity check: ensure we've got a better score than the organism we are replacing
                            if childScore > allOrganismScores[left] {
                                let oldBestScore = allOrganismScores[localNumberOfOrganismsMinusOne]
                                
                                // when we insert a new child into the population, we "shuffle down" existing organisms to make
                                // room for the new guy, allowing us to euthenize a worse organism while keeping the
                                // strong organisms. as an optimization, we don't do the entire population array, instead
                                // we do replacementWindow number of organisms
                                let startReplacementWindow = (left - replacementWindow >= 0 ? left - replacementWindow : 0)

                                // note: we need to juggle the organism we're going to trash, as it will become our
                                // newChild replacement object ( so we recycle organisms instead of creating new ones )
                                trashedChild = allOrganisms[startReplacementWindow]

                                // "shuffle down" our replacement window
                                if (startReplacementWindow + 1) <= left {
                                    for j in (startReplacementWindow + 1)...left {
                                        allOrganismScores[j - 1] = allOrganismScores[j]
                                        allOrganisms[j - 1] = allOrganisms[j]
                                    }
                                }

                                // insert the new child into the population
                                allOrganisms[left] = newChild
                                allOrganismScores[left] = childScore

                                // reuse our trashed organism
                                newChild = trashedChild

                                // if we have discovered a new best organism
                                
                                if childScore > oldBestScore {

                                    // set this flag to ensure chosenOrganism() gets called
                                    didFindNewBestOrganism = true
                                    didFindNewBestOrganismCount = 0

                                    // if we're multi-threaded, make note of this new best organism in our shared organisms array
                                    if sharedOrganismIdx >= 0 {
                                        let _: T? = Release(sharedOrganisms[sharedOrganismIdx])
                                        sharedOrganisms[sharedOrganismIdx] = Ptr(allOrganisms[localNumberOfOrganismsMinusOne])
                                    }
                                }
                            }
                        }
                    }

                    // update the number of generations we have now processed
                    numberOfGenerations += maxBreedingPerGeneration
                    didFindNewBestOrganismCount += maxBreedingPerGeneration

                    // every little while, introduce new half of the population
                    if numberOfGenerations % (maxBreedingPerGeneration * 500) == 0 {
                        // Call the delegate to generate all of the organisms in the population array; score them as well
                        if let adjustPopulation = adjustPopulation {
                            adjustPopulation(&allOrganisms, &allOrganismScores, numberOfGenerations, prng)
                            for i in 0..<localNumberOfOrganismsMinusOne {
                                allOrganismScores[i] = scoreOrganism(allOrganisms[i], sharedOrganismIdx, prng)
                            }
                        }

                        allOrganismScores[localNumberOfOrganismsMinusOne] = scoreOrganism(allOrganisms[localNumberOfOrganismsMinusOne], sharedOrganismIdx, prng)
                        comboSort(&allOrganismScores, &allOrganisms)
                        didFindNewBestOrganism = true
                    }

                    // if we found a new best organism, check with our delegate to see if we need to continue processing or not
                    if didFindNewBestOrganism && chosenOrganism(allOrganisms[localNumberOfOrganismsMinusOne], allOrganismScores[localNumberOfOrganismsMinusOne], numberOfGenerations, sharedOrganismIdx, prng) {
                        // if we're multi-threaded and we found the correct answer, make sure to let all of the other ring-threads know so they can stop too
                        if sharedOrganismIdx >= 0 {
                            sharedOrganismsDone = true
                        }
                        finished = true
                        return
                    }
                    
                    if endAfterRepeatedFailsToFindNewBestOragnism >= 0 && didFindNewBestOrganismCount > endAfterRepeatedFailsToFindNewBestOragnism {
                        // if we're multi-threaded and we found the correct answer, make sure to let all of the other ring-threads know so they can stop too
                        if sharedOrganismIdx >= 0 {
                            sharedOrganismsDone = true
                        }
                        finished = true
                        return
                    }
                }
            }
        }

        // note: for proper reporing of number of generations processed, we need to call choose organism one more time before exiting
        _ = chosenOrganism(allOrganisms[localNumberOfOrganismsMinusOne], allOrganismScores[localNumberOfOrganismsMinusOne], numberOfGenerations, sharedOrganismIdx, prng)

        // return the best organism we've managed to breed
        return allOrganisms[localNumberOfOrganismsMinusOne]
    }

    // Perform the genetic algorithm on the current thread
    public func perform(single millisecondsToProcess: Int) -> (T, Int) {

        let watchStart = DispatchTime.now()
        var masterGenerations = 0

        let bestOrganism = process(millisecondsToProcess, adjustPopulation, generateOrganism, breedOrganisms, scoreOrganism, {(organism, score, generation, sharedOrganismIdx, prng) in
            masterGenerations = generation
            return chosenOrganism(organism, score, generation, sharedOrganismIdx, prng)
        })

        let watchEnd = DispatchTime.now()

        print("Done in \((watchEnd.uptimeNanoseconds-watchStart.uptimeNanoseconds) / 1000000)ms and \(masterGenerations) generations\n")

        return (bestOrganism, masterGenerations)
    }

    // Perform the genetic algorithm on many threads (as many threads as we have processing cores, specifically).
    // To do this, we take on a ring network paradigm for the threads.  Each thread is created and given its
    // own population of organisms which it processes separately from all other threads. Threads then
    // pass the best organism in their population to their neighboring thread (one way only, and the neighbors
    // wrap so that there is a full ring of communication). During the parent selection phases during breeding
    // one of the selection methods is to asexually breed this shared organism into the thread's population.
    // Using this scheme, each thread is able to process in a highly parallizable fashion while still incorporating
    // the best chromosomes of other threads into its population
    private var sharedOrganisms = UnsafeMutablePointer<AnyPtr>.allocate(capacity: 0)
    private var sharedOrganismsCount = 0
    private var sharedOrganismsDone = false
    public func perform(many millisecondsToProcess: Int,
                        threads: Int = 0) -> (T, Int) {

        // figure out the number of threads we want to use to create our ring network
        let numThreads = threads > 0 ? threads : ProcessInfo.processInfo.activeProcessorCount
        if numThreads == 1 {
            return perform(single: millisecondsToProcess)
        }

        let watchStart = DispatchTime.now()

        // when each thread ends, it will check to see if its chosen plan is better than the master plan and replace it,
        // allowing us to return the best plan conceived over all of the threads in the ring network
        var masterBestOrganism: T = generateOrganism(0, CRandom())
        var masterBestOrganismScore: Float = -Float.greatestFiniteMagnitude
        var masterGenerations = 0

        // allocate our shared oragnisms array to allow threads to pass their best organisms along
        sharedOrganisms = UnsafeMutablePointer<AnyPtr>.allocate(capacity: numThreads)
        sharedOrganismsCount = numThreads
        sharedOrganismsDone = false

        for i in 0..<numThreads {
            sharedOrganisms[i] = nil
        }

        let endOfProcessingLock = NSLock()
        var numberOfRunningThreads = numThreads

        for i in 0..<numThreads {
            let sharedOrganismIdx = i

            let processFunc = self.process

            DispatchQueue.global().async {
                // we wrap he choose organism delegate to keep try of the best organism and the number of generations processed
                var bestOrganismScore: Float = -999999.0
                var maxGenerations = 0
                var bestOrganism: T?

                let chooseOrganismAndTrack: ChosenOrganismFunc<T> = { newOrganism, score, generation, sharedOrganismIdx, prng in
                    if score > bestOrganismScore {
                        bestOrganism = newOrganism
                        bestOrganismScore = score
                    }
                    maxGenerations = generation
                    return self.chosenOrganism(newOrganism, score, generation, sharedOrganismIdx, prng)
                }

                bestOrganism = processFunc(millisecondsToProcess,
                                            self.adjustPopulation,
                                            self.generateOrganism,
                                            self.breedOrganisms,
                                            self.scoreOrganism,
                                            chooseOrganismAndTrack,
                                            sharedOrganismIdx,
                                            (sharedOrganismIdx + 1) % numThreads)

                // when we're all done, lock while ensuring we have the best organism
                endOfProcessingLock.lock()

                masterGenerations += maxGenerations
                if let bestOrganism = bestOrganism,
                   bestOrganismScore > masterBestOrganismScore {
                    masterBestOrganismScore = bestOrganismScore
                    masterBestOrganism = bestOrganism
                }
                numberOfRunningThreads -= 1

                endOfProcessingLock.unlock()
            }

        }

        // lock waiting for all threads to finish
        while numberOfRunningThreads > 0 {
            sleep(1)
        }

        sharedOrganismsDone = false

        let watchEnd = DispatchTime.now()
        print("Done in \((watchEnd.uptimeNanoseconds-watchStart.uptimeNanoseconds) / 1000000)ms and \(masterGenerations) generations\n")

        return (masterBestOrganism, masterGenerations)
    }
}
