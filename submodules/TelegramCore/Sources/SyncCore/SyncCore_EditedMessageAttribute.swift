import Foundation
import Postbox


public class EditedMessageAttribute: MessageAttribute {
    public let date: Int32
    public let isHidden: Bool
    public let mechagramDeleted: Bool
    
    public init(date: Int32, isHidden: Bool, mechagramDeleted: Bool = false) {
        self.date = date
        self.isHidden = isHidden
        self.mechagramDeleted = mechagramDeleted
    }
    
    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
        self.isHidden = decoder.decodeInt32ForKey("h", orElse: 0) != 0
        self.mechagramDeleted = decoder.decodeInt32ForKey("md", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
        encoder.encodeInt32(self.isHidden ? 1 : 0, forKey: "h")
        encoder.encodeInt32(self.mechagramDeleted ? 1 : 0, forKey: "md")
    }
}

public extension Message {
    var editedTime: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? EditedMessageAttribute, !attribute.isHidden {
                return attribute.date
            }
        }
        return nil
    }
}
