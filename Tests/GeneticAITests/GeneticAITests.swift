import XCTest
import Foundation

@testable import GeneticAI

extension String {
    var asciiArray: [Int32] {
        return unicodeScalars.filter{$0.isASCII}.map{Int32($0.value)}
    }
    
    init (_ asciiArray : [Int32]) {
        self.init()
        
        for x in asciiArray {
            self.append(Character(UnicodeScalar(UInt32(x))!))
        }
    }
}

final class GeneticAITests: XCTestCase {
    
    class Organism {
        var content : [Int32]?
        
        init(_ contentLength:Int) {
            content = [Int32](repeating:0, count:contentLength)
        }
        
        subscript(index:Int) -> Int32 {
            get {
                return content![index]
            }
            set(newElm) {
                content![index] = newElm
            }
        }
    }
    
    private func sharedTest(timeout: Int,
                            targetString: [Int32],
                            allCharacters: [Int32],
                            threaded: Bool) {
        
        let ga = GeneticAlgorithm<Organism>()
        
        // Generate organism delegate needs to create a new organism instance and fill it with random characters
        ga.generateOrganism = { (idx, pnrg) in
            let newChild = Organism (targetString.count)
            for i in 0..<targetString.count {
                newChild.content! [i] = pnrg.get(allCharacters)
            }
            return newChild
        }
        
        // Breed organisms delegate needs to breed two organisms together and put their chromosomes into the child
        // in some manner. We have two ways we breed:
        // 1) If we are breeding someone asexually, we simply give them a high chance of a single mutation (we assume they're close to perfect and should only be tweaked a little)
        // 2) If we are breeding two distinct individuals, choose some chromosomes randomly from each parent, and have a small chance to mutate any chromosome
        ga.breedOrganisms = { (organismA, organismB, child, prng) in
            
            if organismA === organismB {
                // breed an organism with itself; this is optimized as we generally want a higher chance to singly mutate something
                // think of this as we almost have the perfect organism, we just want to tweak one thing
                for i in 0..<targetString.count {
                    child [i] = organismA [i]
                }
                if prng.get() < 0.9 {
                    child [prng.get() % targetString.count] = prng.get(allCharacters)
                }
                
            } else {
                
                // breed two organisms, we'll do this by randomly choosing chromosomes from each parent, with the odd-ball mutation
                for i in 0..<targetString.count {
                    let t: Float = prng.get()
                    if t < 0.45 {
                        child [i] = organismA [i]
                    } else if t < 0.9 {
                        child [i] = organismB [i]
                    } else {
                        child [i] = prng.get(allCharacters)
                    }
                }
            }
        }
        
        // Scoring an organism we calculate the distance of each string from each other and negate it (so 0 is a perfect match)
        ga.scoreOrganism = { (organism, threadIdx, prng) in
            var score : Float = 0
            for i in 0..<targetString.count {
                score += Float(abs(targetString [i] - organism [i]))
            }
            return -score
        }
        
        // Choosing organism, if we have a perfect match return true and stop genetic processing
        ga.chosenOrganism = { (organism, score, generation, sharedOrganismIdx, prng) in
            if score == 0 {
                return true
            }
            return false
        }
        
        var finalResult : Organism? = nil
        if(threaded) {
            finalResult = ga.perform(many: Int64(timeout))
        }else{
            finalResult = ga.perform(single: Int64(timeout))
        }
        
        
        if(targetString == finalResult!.content!) {
            print("SUCCESS: \(String(finalResult!.content!))\n")
        }else{
            print("FAILURE: \(String(finalResult!.content!))\n")
        }
    }
    
    func testSingleThread0() {
        let timeout = 50
        let targetString : [Int32] = Array("CAT".asciiArray)
        let allCharacters : [Int32] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ".asciiArray)
        
        sharedTest(timeout: timeout,
                   targetString: targetString,
                   allCharacters: allCharacters,
                   threaded: false)
        
    }
    
    func testSingleThread1() {
        let timeout = 500
        let targetString : [Int32] = "SUPERCALIFRAGILISTICEXPIALIDOCIOUS".asciiArray
        let allCharacters : [Int32] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".asciiArray
        
        sharedTest(timeout: timeout,
                   targetString: targetString,
                   allCharacters: allCharacters,
                   threaded: false)
        
    }
    
    func testSingleThread2() {
        let timeout = 20000
        let targetString : [Int32] = Array("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed sodales velit et velit viverra, porta porta ligula sollicitudin. Pellentesque commodo eu nunc finibus mollis. Proin sit amet volutpat sem. Quisque sit amet auctor risus. Duis porta elit vestibulum velit gravida fermentum. Sed lacinia ornare odio, ut vestibulum lacus hendrerit vitae. Suspendisse egestas, ex ut tincidunt mattis, mauris ligula placerat nisi, vel lacinia elit ex feugiat ex. Sed urna lorem, eleifend id maximus sit amet, dictum eu nisi. Nunc consectetur libero gravida ultricies hendrerit. In volutpat mollis eros id rhoncus. Etiam sagittis dapibus neque at condimentum.".asciiArray)
        let allCharacters : [Int32] = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#$%&\\'()*+,-./:;?@[\\\\]^_`{|}~ \\t\\n\\r\\x0b\\x0c".asciiArray)
        
        sharedTest(timeout: timeout,
                   targetString: targetString,
                   allCharacters: allCharacters,
                   threaded: true)
        
    }
}

extension GeneticAITests {
    static var allTests: [(String, (GeneticAITests) -> () throws -> Void)] {
        return [
            ("testSingleThread0", testSingleThread0)
        ]
    }
}
