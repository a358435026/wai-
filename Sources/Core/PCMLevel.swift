import Foundation

public enum PCMLevel {
    public static func normalized(_ data: Data) -> Float {
        let bytes = [UInt8](data)
        let count = bytes.count / 2
        guard count > 0 else { return 0 }
        var energy: Double = 0
        for i in 0..<count {
            let sample = Int16(bitPattern: UInt16(bytes[2*i]) | UInt16(bytes[2*i+1]) << 8)
            let value = Double(sample) / 32768
            energy += value * value
        }
        return min(1, Float(sqrt(energy / Double(count))) * 6)
    }
}
