extension Duration {
    /// Milisaniye; hata ayıklama günlüklerindeki süre ölçümleri için.
    public var inMilliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
