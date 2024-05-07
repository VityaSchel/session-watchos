extension Array {
  func appending(contentsOf other: [Element]?) -> [Element] {
    guard let other: [Element] = other else { return self }
    
    var updatedArray: [Element] = self
    updatedArray.append(contentsOf: other)
    return updatedArray
  }
  
  func grouped<Key: Hashable>(by keyForValue: (Element) throws -> Key) -> [Key: [Element]] {
    return ((try? Dictionary(grouping: self, by: keyForValue)) ?? [:])
  }
}
