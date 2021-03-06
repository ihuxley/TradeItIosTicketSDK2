import UIKit
import MBProgressHUD
import BEMCheckBox

class TradeItYahooTradePreviewViewController: CloseableViewController, UITableViewDelegate, UITableViewDataSource, AcknowledgementDelegate {
    @IBOutlet weak var brokerLabel: UILabel!
    @IBOutlet weak var orderDetailsTable: UITableView!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!

    var linkedBrokerAccount: TradeItLinkedBrokerAccount!
    var previewOrderResult: TradeItPreviewOrderResult?
    var placeOrderResult: TradeItPlaceOrderResult?
    var placeOrderCallback: TradeItPlaceOrderHandlers?
    var previewCellData = [PreviewCellData]()
    var acknowledgementCellData: [AcknowledgementCellData] = []
    let alertManager = TradeItAlertManager(linkBrokerUIFlow: TradeItYahooLinkBrokerUIFlow())
    weak var delegate: TradeItYahooTradePreviewViewControllerDelegate?

    private let actionButtonTitleTextSubmitOrder = "Submit order"
    private let actionButtonTitleTextGoToPortolio = "Go to portfolio"

    override func viewDidLoad() {
        super.viewDidLoad()

        precondition(self.linkedBrokerAccount != nil, "TradeItSDK ERROR: TradeItYahooTradingPreviewViewController loaded without setting linkedBrokerAccount.")

        self.title = "Preview order"
        self.brokerLabel.text = self.linkedBrokerAccount.brokerName
        self.statusLabel.text = "Preview order"
        self.statusLabel.textColor = UIColor.yahooTextColor
        self.actionButton.setTitle(self.actionButtonTitleTextSubmitOrder, for: .normal)

        self.previewCellData = self.generatePreviewCellData()

        orderDetailsTable.dataSource = self
        orderDetailsTable.delegate = self
        
        updatePlaceOrderButtonStatus()
    }

    private func updateOrderDetailsTable() {
        self.previewCellData = self.generatePreviewCellData()
        self.orderDetailsTable.reloadData()
    }

    // MARK: IBActions

    private func submitOrder() {
        guard let placeOrderCallback = self.placeOrderCallback else {
            print("TradeItSDK ERROR: placeOrderCallback not set on TradeItYahooTradePreviewViewController")
            return
        }

        self.actionButton.disable()

        let activityView = MBProgressHUD.showAdded(to: self.view, animated: true)
        activityView.label.text = "Authenticating"

        self.linkedBrokerAccount?.linkedBroker?.authenticateIfNeeded(
            onSuccess: {
                activityView.label.text = "Placing Order"

                placeOrderCallback(
                    { placeOrderResult in

                        self.placeOrderResult = placeOrderResult

                        self.title = "Order Confirmation"

                        self.statusLabel.text = "✓ Order Submitted"
                        self.statusLabel.textColor = UIColor.yahooGreenSuccessColor

                        self.actionButton.enable()
                        self.actionButton.setTitle(self.actionButtonTitleTextGoToPortolio, for: .normal)

                        self.updateOrderDetailsTable()

                        activityView.hide(animated: true)
                    },
                    { error in
                        activityView.hide(animated: true)

                        self.actionButton.enable()

                        guard let linkedBroker = self.linkedBrokerAccount.linkedBroker else {
                            return self.alertManager.showError(
                                error,
                                onViewController: self
                            )
                        }

                        self.alertManager.showAlertWithAction(
                            error: error,
                            withLinkedBroker: linkedBroker,
                            onViewController: self
                        )
                    }
                )
            },
            onSecurityQuestion: { securityQuestion, answerSecurityQuestion, cancelSecurityQuestion in
                activityView.hide(animated: true)
                self.alertManager.promptUserToAnswerSecurityQuestion(
                    securityQuestion,
                    onViewController: self,
                    onAnswerSecurityQuestion: answerSecurityQuestion,
                    onCancelSecurityQuestion: cancelSecurityQuestion
                )
            },
            onFailure: { errorResult in
                activityView.hide(animated: true)
                self.actionButton.enable()
                // TODO: use self.alertManager.showRelinkError
                self.alertManager.showError(errorResult, onViewController: self)
            }
        )
    }

    @IBAction func actionButtonTapped(_ sender: UIButton) {
        if self.placeOrderResult != nil {
            self.delegate?.viewPortfolioTapped(onTradePreviewViewController: self, linkedBrokerAccount: self.linkedBrokerAccount)
        } else {
            self.submitOrder()
        }
    }

    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }

    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return previewCellData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellData = previewCellData[indexPath.row]

        switch cellData {
        case let warningCellData as WarningCellData:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TRADE_IT_YAHOO_PREVIEW_WARNING_CELL_ID") as! TradeItYahooPreviewOrderWarningTableViewCell
            cell.populate(withWarning: warningCellData.warning)
            return cell
        case let acknowledgementCellData as AcknowledgementCellData:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TRADE_IT_YAHOO_PREVIEW_ACKNOWLEDGEMENT_CELL_ID") as! TradeItYahooPreviewOrderAcknowledgementTableViewCell
            cell.populate(withCellData: acknowledgementCellData, andDelegate: self)
        return cell
        case let valueCellData as ValueCellData:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TRADE_IT_YAHOO_PREVIEW_CELL_ID") ?? UITableViewCell()
            cell.textLabel?.text = valueCellData.label
            cell.detailTextLabel?.text = valueCellData.value

            return cell
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    // MARK: AcknowledgementDelegate
    
    func acknowledgementWasChanged() {
        updatePlaceOrderButtonStatus()
    }
    
    // MARK: Private
    
    private func updatePlaceOrderButtonStatus() {
        if allAcknowledgementsAccepted() {
            self.actionButton.enable()
        } else {
            self.actionButton.disable()
        }
    }
    
    private func allAcknowledgementsAccepted() -> Bool {
        return acknowledgementCellData.filter{ !$0.isAcknowledged }.count == 0
    }
    
    private func generatePreviewCellData() -> [PreviewCellData] {
        guard let linkedBrokerAccount = linkedBrokerAccount,
            let orderDetails = previewOrderResult?.orderDetails
            else { return [] }

        var cells = [PreviewCellData]()

        cells += [
            ValueCellData(label: "Account", value: linkedBrokerAccount.getFormattedAccountName())
        ] as [PreviewCellData]

        let orderDetailsPresenter = TradeItOrderDetailsPresenter(orderDetails: orderDetails)

        if let orderNumber = self.placeOrderResult?.orderNumber {
            cells += [
                ValueCellData(label: "Order #", value: orderNumber)
            ] as [PreviewCellData]
        }

        cells += [
            ValueCellData(label: "Action", value: orderDetailsPresenter.getOrderActionLabel()),
            ValueCellData(label: "Symbol", value: orderDetails.orderSymbol),
            ValueCellData(label: "Shares", value: NumberFormatter.formatQuantity(orderDetails.orderQuantity)),
            ValueCellData(label: "Price", value: orderDetails.orderPrice),
            ValueCellData(label: "Time in force", value: orderDetailsPresenter.getOrderExpirationLabel())
        ] as [PreviewCellData]

        if let estimatedOrderCommission = orderDetails.estimatedOrderCommission {
            cells.append(ValueCellData(label: "Broker fee", value: self.formatCurrency(estimatedOrderCommission)))
        }

        if let estimatedTotalValue = orderDetails.estimatedTotalValue {
            cells.append(ValueCellData(label: "Estimated cost", value: self.formatCurrency(estimatedTotalValue)))
        }
        
        cells += generateWarningCellData()

        acknowledgementCellData = generateAcknowledgementCellData()
        cells += acknowledgementCellData as [PreviewCellData]
        
        return cells
    }
    
    private func generateWarningCellData() -> [PreviewCellData] {
        guard let warnings = previewOrderResult?.warningsList as? [String] else { return [] }
        
        return warnings.map({ warning in
            return WarningCellData(warning: warning)
        })
    }
    
    private func generateAcknowledgementCellData() -> [AcknowledgementCellData] {
        guard let acknowledgements = previewOrderResult?.ackWarningsList as? [String] else { return [] }
        
        return acknowledgements.map({ acknowledgement in
            return AcknowledgementCellData(acknowledgement: acknowledgement)
        })
    }

    private func formatCurrency(_ value: NSNumber) -> String {
        return NumberFormatter.formatCurrency(value, currencyCode: self.linkedBrokerAccount.accountBaseCurrency)
    }
}

protocol TradeItYahooTradePreviewViewControllerDelegate: class {
    func viewPortfolioTapped(
        onTradePreviewViewController tradePreviewViewController: TradeItYahooTradePreviewViewController,
        linkedBrokerAccount: TradeItLinkedBrokerAccount
    )
}
