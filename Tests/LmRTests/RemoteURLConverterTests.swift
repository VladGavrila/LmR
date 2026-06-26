import Foundation
import Testing
@testable import LmRModels

@Suite("RemoteURLConverter")
struct RemoteURLConverterTests {

    @Test func convertsSCPLikeShorthand() {
        #expect(RemoteURLConverter.httpsURL(from: "git@github.com:owner/repo.git")?.absoluteString == "https://github.com/owner/repo")
    }

    @Test func convertsSCPLikeShorthandWithoutGitSuffix() {
        #expect(RemoteURLConverter.httpsURL(from: "git@github.com:owner/repo")?.absoluteString == "https://github.com/owner/repo")
    }

    @Test func convertsSSHScheme() {
        #expect(RemoteURLConverter.httpsURL(from: "ssh://git@github.com/owner/repo.git")?.absoluteString == "https://github.com/owner/repo")
    }

    @Test func convertsSSHSchemeWithPort() {
        #expect(RemoteURLConverter.httpsURL(from: "ssh://git@example.com:2222/owner/repo.git")?.absoluteString == "https://example.com/owner/repo")
    }

    @Test func convertsGitScheme() {
        #expect(RemoteURLConverter.httpsURL(from: "git://github.com/owner/repo.git")?.absoluteString == "https://github.com/owner/repo")
    }

    @Test func passesThroughHTTPSAlreadyStrippingGitSuffix() {
        #expect(RemoteURLConverter.httpsURL(from: "https://github.com/owner/repo.git")?.absoluteString == "https://github.com/owner/repo")
    }

    @Test func upgradesHTTPToHTTPS() {
        #expect(RemoteURLConverter.httpsURL(from: "http://github.com/owner/repo")?.absoluteString == "https://github.com/owner/repo")
    }

    @Test func returnsNilForLocalPath() {
        #expect(RemoteURLConverter.httpsURL(from: "/Users/me/bare-repos/repo.git") == nil)
    }

    @Test func returnsNilForEmptyString() {
        #expect(RemoteURLConverter.httpsURL(from: "") == nil)
    }

    @Test func returnsNilForWhitespaceOnly() {
        #expect(RemoteURLConverter.httpsURL(from: "   ") == nil)
    }
}
