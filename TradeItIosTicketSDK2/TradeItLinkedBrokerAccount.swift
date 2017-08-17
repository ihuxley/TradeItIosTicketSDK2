@objc public class TradeItLinkedBrokerAccount: NSObject {
    public var brokerName: String? {
        return self.linkedBroker?.brokerName
    }

    public var accountName = ""
    public var accountNumber = ""
    public var accountIndex = ""
    public var accountBaseCurrency = ""
    public var balanceLastUpdated: Date?
    public var balance: TradeItAccountOverview?
    public var fxBalance: TradeItFxAccountOverview?
    public var positions: [TradeItPortfolioPosition] = []
    public var orderCapabilities: [TradeItInstrumentOrderCapabilities] = []
    weak var linkedBroker: TradeItLinkedBroker?
    var tradeItBalanceService: TradeItBalanceService
    var tradeItPositionService: TradeItPositionService
    var tradeService: TradeItTradeService
    var fxTradeService: TradeItFxTradeService

    private var _enabled = true
    public var isEnabled: Bool {
        get {
            return _enabled
        }

        set(newValue) {
            if _enabled != newValue {
                _enabled = newValue
                TradeItSDK.linkedBrokerCache.cache(linkedBroker: self.linkedBroker)
            }
        }
    }

    internal init(linkedBroker: TradeItLinkedBroker,
         accountName: String,
         accountNumber: String,
         accountIndex: String,
         accountBaseCurrency: String,
         balanceLastUpdated: Date? = nil,
         balance: TradeItAccountOverview?,
         fxBalance: TradeItFxAccountOverview?,
         positions: [TradeItPortfolioPosition],
         orderCapabilities: [TradeItInstrumentOrderCapabilities] = [],
         isEnabled: Bool=true
    ) {
        self.linkedBroker = linkedBroker
        self.accountName = accountName
        self.accountNumber = accountNumber
        self.accountIndex = accountIndex
        self.accountBaseCurrency = accountBaseCurrency
        self.balanceLastUpdated = balanceLastUpdated
        self.balance = balance
        self.fxBalance = fxBalance
        self.positions = positions
        self.orderCapabilities = orderCapabilities
        self._enabled = isEnabled
        // TODO: These services should be a reference to one held on the parent linkedBroker instead of duplicated for every account...
        self.tradeItBalanceService = TradeItBalanceService(session: linkedBroker.session)
        self.tradeItPositionService = TradeItPositionService(session: linkedBroker.session)
        self.tradeService = TradeItTradeService(session: linkedBroker.session)
        self.fxTradeService = TradeItFxTradeService(session: linkedBroker.session)
    }

    internal convenience init(linkedBroker: TradeItLinkedBroker, accountData: LinkedBrokerAccountData) {
        self.init(
            linkedBroker: linkedBroker,
            accountName: accountData.name,
            accountNumber: accountData.number,
            accountIndex: "",
            accountBaseCurrency: accountData.baseCurrency,
            balance: nil,
            fxBalance: nil,
            positions: []
        )
    }

    public func getAccountOverview(cacheResult: Bool = true,
                                   onSuccess: @escaping (TradeItAccountOverview?) -> Void,
                                   onFailure: @escaping (TradeItErrorResult) -> Void) {
        let request = TradeItAccountOverviewRequest(accountNumber: self.accountNumber)
        self.tradeItBalanceService.getAccountOverview(request, onSuccess: { result in
            self.balanceLastUpdated = Date()
            self.balance = result.accountOverview
            self.fxBalance = result.fxAccountOverview
            self.linkedBroker?.clearError()

            if cacheResult {
                TradeItSDK.linkedBrokerCache.cache(linkedBroker: self.linkedBroker)
            }

            onSuccess(result.accountOverview)
        }, onFailure: { error in
            self.linkedBroker?.error = error
            onFailure(error)
        })
    }

    public func getPositions(onSuccess: @escaping ([TradeItPortfolioPosition]) -> Void, onFailure: @escaping (TradeItErrorResult) -> Void) {
        let request = TradeItGetPositionsRequest(accountNumber: self.accountNumber)

        self.tradeItPositionService.getPositions(request, onSuccess: { result in
            guard let equityPositions = result.positions as? [TradeItPosition] else {
                return onFailure(TradeItErrorResult(title: "Could not retrieve account positions. Please try again."))
            }
            let portfolioEquityPositions = equityPositions.map { equityPosition -> TradeItPortfolioPosition in
                equityPosition.currencyCode = result.accountBaseCurrency
                return TradeItPortfolioPosition(linkedBrokerAccount: self, position: equityPosition)
            }

            guard let fxPositions = result.fxPositions as? [TradeItFxPosition] else {
                return onFailure(TradeItErrorResult(title: "Could not retrieve account positions. Please try again."))
            }
            let portfolioFxPositions = fxPositions.map { fxPosition -> TradeItPortfolioPosition in
                return TradeItPortfolioPosition(linkedBrokerAccount: self, fxPosition: fxPosition)
            }

            self.positions = portfolioEquityPositions + portfolioFxPositions
            onSuccess(self.positions)
        }, onFailure: { error in
            self.linkedBroker?.error = error
            onFailure(error)
        })
    }

    public func getFormattedAccountName() -> String {
        var formattedAccountNumber = self.accountNumber
        var formattedAccountName = self.accountName
        var separator = " "

        if formattedAccountNumber.characters.count > 4 {
            let startIndex = formattedAccountNumber.characters.index(formattedAccountNumber.endIndex, offsetBy: -4)
            formattedAccountNumber = String(formattedAccountNumber.characters.suffix(from: startIndex))
            separator = "**"
        }

        if formattedAccountName.characters.count > 10 {
            formattedAccountName = String(formattedAccountName.characters.prefix(10))
            separator = "**"
        }

        return "\(formattedAccountName)\(separator)\(formattedAccountNumber)"
    }

    internal func orderCapabilities(forInstrument instrument: TradeItTradeInstrumentType) -> TradeItInstrumentOrderCapabilities? {
        return self.orderCapabilities.first { instrumentCapabilities in
            return instrumentCapabilities.instrument == instrument.rawValue.lowercased()
        }
    }
}
