
enum TradeItBrokerLogoSize: String {
    case small
    case large
}

class TradeItBrokerLogoService {
    static func setLogo(forBroker broker: TradeItBroker, onImageView imageView: UIImageView, withSize size: TradeItBrokerLogoSize) -> Bool {
        guard let logoMetadata = broker.logos as? [TradeItBrokerLogo],
            let logoData = logoMetadata.first(where: { $0.name == size.rawValue }),
            let logoUrlString = logoData.url,
            let logoUrl = URL(string: logoUrlString) else {
                print("TradeIt ERROR: No broker logo provided for \(broker.shortName ?? "")")
                return false
        }

        // Yahoo's diff in this fork is to switch to SDWebImage v3.x
        print("TradeIt Logo: Fetching remote logo for \(broker.shortName ?? "")")
        imageView.sd_setImage(with: logoUrl)
        imageView.setIndicatorStyle(.gray)
        imageView.setShowActivityIndicator(true)
        //        imageView.sd_setIndicatorStyle(.gray)
        //imageView.sd_setShowActivityIndicatorView(true)
        
        return true

    }
}
