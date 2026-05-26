import Foundation

enum TestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure.failed(message)
    }
}

@main
struct FeatureTests {
    static func main() throws {
        try testHTMLProcessorKeepsEnhancedDiscourseBlocks()
        try testPostDecodesPollsAndVotes()
        try testMessageBusParsesPipeDelimitedChunks()
        print("FeatureTests passed")
    }

    private static func testHTMLProcessorKeepsEnhancedDiscourseBlocks() throws {
        let html = """
        <p>Hello <img class="emoji custom" title=":linux_do:" src="/uploads/default/original/1X/emoji.png"></p>
        <aside class="onebox allowlistedgeneric" data-onebox-src="https://example.com">
          <header class="source"><a href="https://example.com">Example</a></header>
          <article class="onebox-body"><h3><a href="/t/test/1">Title</a></h3><p>Desc</p></article>
        </aside>
        <div class="poll" data-poll-name="poll"></div>
        """

        let processed = DiscourseHTMLProcessor.normalize(html, baseURL: URL(string: "https://linux.do")!)

        try expect(processed.contains("src=\"https://linux.do/uploads/default/original/1X/emoji.png\""), "custom emoji URLs should be absolutized")
        try expect(processed.contains("data-onebox-src=\"https://example.com\""), "onebox metadata should be preserved")
        try expect(processed.contains("data-poll-name=\"poll\""), "poll markers should be preserved for native enhancement")
        try expect(processed.contains("href=\"https://linux.do/t/test/1\""), "relative links should be absolutized")
    }

    private static func testPostDecodesPollsAndVotes() throws {
        let json = """
        {
          "id": 10,
          "username": "tester",
          "avatar_template": "/user_avatar/linux.do/tester/{size}/1_2.png",
          "cooked": "<div class=\\"poll\\" data-poll-name=\\"poll\\"></div>",
          "post_number": 1,
          "polls": [
            {
              "id": 7,
              "name": "poll",
              "type": "regular",
              "status": "open",
              "results": "always",
              "voters": 3,
              "options": [
                {"id": "a", "html": "Option A", "votes": 2},
                {"id": "b", "html": "Option B", "votes": 1}
              ]
            }
          ],
          "polls_votes": {
            "poll": ["a"]
          }
        }
        """.data(using: .utf8)!

        let post = try JSONDecoder().decode(Post.self, from: json)

        try expect(post.polls?.first?.name == "poll", "post should decode poll name")
        try expect(post.polls?.first?.options.first?.html == "Option A", "post should decode poll option html")
        try expect(post.pollsVotes?["poll"] == ["a"], "post should decode current user poll votes")
    }

    private static func testMessageBusParsesPipeDelimitedChunks() throws {
        let raw = """
        [{"channel":"/latest","message_id":1,"data":{"message_type":"latest","topic_id":42}}]|
        [{"channel":"/new","message_id":2,"data":{"message_type":"new_topic","topic_id":43}}]|
        """

        let messages = MessageBusService.parseMessages(from: raw)

        try expect(messages.count == 2, "should parse two message-bus chunks")
        try expect(messages[0].channel == "/latest", "should preserve first channel")
        try expect(messages[1].messageID == 2, "should decode message id")
        try expect(messages[1].data["topic_id"]?.intValue == 43, "should decode message data")
    }
}
