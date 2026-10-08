// Development-only Foundation primitive for the closed native ARM64 replay.
// Input is the generator's synthetic prompt list, never account/App data.
import Foundation

let input = FileHandle.standardInput.readDataToEndOfFile()
let prompts = try JSONDecoder().decode([String?].self, from: input)
let predicate = NSPredicate(format: "SELF MATCHES %@", #"回复 [\s\S]* :"#)
let matches = prompts.map { prompt in
    prompt.map { predicate.evaluate(with: $0) } ?? false
}
FileHandle.standardOutput.write(try JSONEncoder().encode(matches))
