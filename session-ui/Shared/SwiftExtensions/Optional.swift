extension Optional {
  public func defaulting(to value: Wrapped) -> Wrapped {
    return (self ?? value)
  }
}
