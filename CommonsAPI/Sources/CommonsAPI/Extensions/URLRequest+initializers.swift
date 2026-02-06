//
//  URLRequest+createPOSTMultipartRequest.swift
//  CommonsAPI
//
//  Created by Tom Brewe on 13.12.25.
//

import Foundation

extension API {
    func GET(url: URL, query: [String: String]) throws -> URLRequest {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw CommonAPIError.invalidQueryParams
        }
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        // URLQueryItem leaves literal "+" unchanged in values; MediaWiki treats "+" as a space in query parsing.
        if let percentEncodedQuery = components.percentEncodedQuery {
            components.percentEncodedQuery = percentEncodedQuery.replacing("+", with: "%2B")
        }
        guard let finalURL = components.url else {
            throw CommonAPIError.invalidQueryParams
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
    
    func POST(url: URL, form: [String: String]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formURLEncode(form)
        return request
    }
    
    func POSTMultipart(url: URL, fileURL: URL, filename: String, mimeType: String, params: [String:String]) throws -> URLRequest {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let httpBody = NSMutableData()
        for (key, value) in params {
            httpBody.appendString(MultipartSupport.convertFormField(named: key, value: value, using: boundary))
        }
        
        let fileData = try Data.init(contentsOf: fileURL)
        
        httpBody.append(MultipartSupport.convertFileData(
            fieldName: "file",
            fileName: filename,
            mimeType: mimeType,
            fileData: fileData,
            using: boundary
        ))
        httpBody.appendString("--\(boundary)--")
        
        request.httpBody = httpBody as Data
        
        return request
    }
}

// encode to application/x-www-form-urlencoded
private func formURLEncode(_ form: [String: String]) -> Data {
    // NOTE: cannot use URLQueryItem encoding, as there are differences (eg. no "?" for the first kv-pair, only "&"s.
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: ":#[]@!$&'()*+,;=") // reserved characters that must be percent-encoded in this context

    let pairs: [String] = form.map { key, value in
        let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        let vEncoded = value
            .addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacing("%20", with: "+")
        ?? value.replacing(" ", with: "+")
        return "\(k)=\(vEncoded)"
    }
    .sorted()

    return pairs.joined(separator: "&").data(using: .utf8) ?? Data()
}

private enum MultipartSupport {
    static func convertFormField(named name: String, value: String, using boundary: String) -> String {
      var fieldString = "--\(boundary)\r\n"
      fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
      fieldString += "\r\n"
      fieldString += "\(value)\r\n"

      return fieldString
    }
    
    static func convertFileData(fieldName: String, fileName: String, mimeType: String, fileData: Data, using boundary: String) -> Data {
      let data = NSMutableData()

      data.appendString("--\(boundary)\r\n")
      data.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
      data.appendString("Content-Type: \(mimeType)\r\n\r\n")
      data.append(fileData)
      data.appendString("\r\n")

      return data as Data
    }
}

extension NSMutableData {
  func appendString(_ string: String) {
    if let data = string.data(using: .utf8) {
      self.append(data)
    }
  }
}
