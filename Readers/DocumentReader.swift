import Foundation

protocol DocumentReader {

    func read(from url: URL) throws -> String

}
