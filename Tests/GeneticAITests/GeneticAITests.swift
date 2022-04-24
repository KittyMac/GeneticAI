import XCTest
import Foundation

@testable import GeneticAI

final class GeneticAITests: XCTestCase {
    
    class Organism {
        let values: UnsafeMutableBufferPointer<Int32>
        
        deinit {
            values.deallocate()
        }
        
        init(capacity: Int) {
            values = UnsafeMutableBufferPointer<Int32>.allocate(capacity: capacity)
        }
        
        init(string: String) {
            var count = 0
            for scalar in string.unicodeScalars where scalar.isASCII {
                count += 1
            }
            
            values = UnsafeMutableBufferPointer<Int32>.allocate(capacity: count)
            
            var idx = 0
            for scalar in string.unicodeScalars where scalar.isASCII {
                values[idx] = Int32(scalar.value)
                idx += 1
            }
        }
        
        @inlinable @inline(__always)
        var count: Int {
            return values.count
        }
        
        @inlinable @inline(__always)
        subscript(index:Int) -> Int32 {
            get {
                return values[index]
            }
            set(newElm) {
                values[index] = newElm
            }
        }
        
        func asString() -> String {
            var string = String()
            for idx in 0..<values.count {
                string.append(Character(UnicodeScalar(UInt32(values[idx]))!))
            }
            return string
        }
    }
    
    private func sharedTest(timeout: Int,
                            targetString: String,
                            allCharacters: String,
                            threaded: Bool) {
        
        let ga = GeneticAlgorithm<Organism>()
        let allCharactersContent = Organism(string: allCharacters)
        let targetStringContent = Organism(string: targetString)
        
        // Generate organism delegate needs to create a new organism instance and fill it with random characters
        ga.generateOrganism = { (idx, pnrg) in
            let newChild = Organism (capacity: targetStringContent.count)
            for i in 0..<targetStringContent.count {
                newChild[i] = pnrg.get(allCharactersContent.values)
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
                for i in 0..<targetStringContent.count {
                    child [i] = organismA [i]
                }
                if prng.get() < 0.9 {
                    child [prng.get() % targetStringContent.count] = prng.get(allCharactersContent.values)
                }
                
            } else {
                
                // breed two organisms, we'll do this by randomly choosing chromosomes from each parent, with the odd-ball mutation
                for i in 0..<targetStringContent.count {
                    let t: Float = prng.get()
                    if t < 0.45 {
                        child [i] = organismA [i]
                    } else if t < 0.9 {
                        child [i] = organismB [i]
                    } else {
                        child [i] = prng.get(allCharactersContent.values)
                    }
                }
            }
        }
        
        // Scoring an organism we calculate the distance of each string from each other and negate it (so 0 is a perfect match)
        ga.scoreOrganism = { (organism, threadIdx, prng) in
            var diff: Int32 = 0
            for i in 0..<targetStringContent.count {
                diff += abs(targetStringContent[i] - organism[i])
            }
            return -Float(diff)
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
            finalResult = ga.perform(many: timeout)
        }else{
            finalResult = ga.perform(single: timeout)
        }
        
        let finalString = finalResult?.asString() ?? ""
        
        if(targetString == finalString) {
            print("SUCCESS: \(finalString)\n")
        }else{
            print("FAILURE: \(finalString)\n")
        }
    }
    
    func testCAT0() {
        let timeout = 50
        let targetString = "CAT"
        let allCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        
        sharedTest(timeout: timeout,
                   targetString: targetString,
                   allCharacters: allCharacters,
                   threaded: true)
        
    }
    
    func testSUPERCALIFRAGILISTICEXPIALIDOCIOUS0() {
        let timeout = 500
        let targetString = "SUPERCALIFRAGILISTICEXPIALIDOCIOUS"
        let allCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        
        sharedTest(timeout: timeout,
                   targetString: targetString,
                   allCharacters: allCharacters,
                   threaded: true)
        
    }
    
    func testLOREMIPSUM0() {
        let timeout = 50000
        let targetString = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed sodales velit et velit viverra, porta porta ligula sollicitudin. Pellentesque commodo eu nunc finibus mollis. Proin sit amet volutpat sem. Quisque sit amet auctor risus. Duis porta elit vestibulum velit gravida fermentum. Sed lacinia ornare odio, ut vestibulum lacus hendrerit vitae. Suspendisse egestas, ex ut tincidunt mattis, mauris ligula placerat nisi, vel lacinia elit ex feugiat ex. Sed urna lorem, eleifend id maximus sit amet, dictum eu nisi. Nunc consectetur libero gravida ultricies hendrerit. In volutpat mollis eros id rhoncus. Etiam sagittis dapibus neque at condimentum."
        let allCharacters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#$%&\\'()*+,-./:;?@[\\\\]^_`{|}~ \\t\\n\\r\\x0b\\x0c"
        
        sharedTest(timeout: timeout,
                   targetString: targetString,
                   allCharacters: allCharacters,
                   threaded: true)
        
    }
    
    // singlethreaded
    // C#: Done in 50009ms and 6,446,517 generations
    // SWIFT: Done in 50000ms and 9,120,957 generations
    
    // multithreaded
    // C#: Done in 50051ms and 249,932,020 generations
    // SWIFT: Done in 50078ms and 294,233,080 generations
    
    func testCRANDOM() {
        let random = CRandom("123456789")
        
        for _ in 0..<100 {
            print(random.next())
        }
    }
    
    func testRandomLessThanChance() {
        let crandom = CRandom("123456789")
        let starrandom = Xoroshiro256StarStar("123456789")
        
        var ccount = 0
        var starcount = 0
        for _ in 0..<100000 {
            if crandom.get() < 0.5 {
                ccount += 1
            }
            if starrandom.get() < 0.5 {
                starcount += 1
            }
        }
        print("CRandom: \(ccount)")
        print("Xoroshiro256StarStar: \(starcount)")
    }
}

extension GeneticAITests {
    static var allTests: [(String, (GeneticAITests) -> () throws -> Void)] {
        return [
            ("testCAT0", testCAT0),
            ("testSUPERCALIFRAGILISTICEXPIALIDOCIOUS0", testSUPERCALIFRAGILISTICEXPIALIDOCIOUS0)
        ]
    }
}
