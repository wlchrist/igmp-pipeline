let response = "HELLO - 92.169.78.1"
let regex = try! NSRegularExpression(pattern: #"(\d{1,3}\.){3}\d{1,3}"#)
if let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) {
    let ipRange = Range(match.range, in: response)!
    let ip = String(response[ipRange])
    print(ip) // Output: 92.169.78.1
}