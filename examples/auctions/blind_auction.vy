# Blind Auction # Adapted to Vyper from [Solidity by Example](https://github.com/ethereum/solidity/blob/develop/docs/solidity-by-example.rst#blind-auction-1)
#
# @author William Entriken
# @notice This code has not been audited.

# Event for logging that auction has ended
AuctionEnded: event({_highestBidder: address, _highestBid: wei_value})

# Auction parameters
beneficiary: public(address)
biddingEnd: public(timestamp)
revealEnd: public(timestamp)

# Set to true at the end of auction, disallowing any new bids
ended: public(bool)

# Final auction state
highestBid: public(wei_value)
highestBidder: public(address)

# State of the bids
bids: map(bytes32, wei_value) # Indexed by blinded bid

# Allowed withdrawals of previous bids
pendingReturns: map(address, wei_value)


# Create a blinded auction
#
# @param _beneficiary the recipient of funds at auction end
# @param _biddingTime the amount of seconds that bidding is allowed
# @param _revealTime  the amount of time the bid reveals are allowed
@public
def __init__(_beneficiary: address, _biddingTime: timedelta, _revealTime: timedelta):
    self.beneficiary = _beneficiary
    self.biddingEnd = block.timestamp + _biddingTime
    self.revealEnd = self.biddingEnd + _revealTime


# Place a blinded bid with:
#
# @param _blindedBib a blinded bid equal to:
#        keccak256(concat(convert(bid_amount, bytes32),bidder,secret))
@public
@payable
def submitBlindedBid(_blindedBid: bytes32):
    # Check if bidding period is still open
    assert block.timestamp < self.biddingEnd

    # Check that this bid was not accepted already
    assert self.bids[_blandedBid] == 0

    # Check that some funds are committed
    assert msg.value > 0

    # Register the bid
    self.bids[_blandedBid] = msg.value


# Reveal a bid during the bid reveal period
#
# @param  _secret    a secret value used as part of the blinded bid
# @param  _bidAmount the effective bid amount
# @return True if bid is not the highest bid, False otherwise
@public
def revealBid(_secret: bytes32, _bidAmount: wei_value) -> bool:
    # Check that bidding period is over
    assert block.timestamp > self.biddingEnd

    # Decode blinded bid
    blindedBid: bytes32 = keccak256(concat(
        convert(_bidAmount, bytes32),
        convert(msg.sender, bytes32),
        _secret
    ))

    # Handle a valid new highest bid
    if block.timestamp < self.revealEnd
        if _bidAmount > self.highestBid
            if self.bids[blindedBid] >= _bidAmount
                # Refund prior locked-up funds
                # Security notice: overflow on += is not a concern because the
                # amount of Ether in exististance fits in 256-bit number
                self.pendingReturns[self.highestBidder] += self.highestBid

                # Recognize new bidder
                self.highestBidder = msg.sender
                self.highestBid = _bidAmount
                self.pendingReturns[msg.sender] += self.highestBid

                # Return unused funds
                amount_to_refund = wei_value = self.bids[blindedBid] - _bidAmount
                if amount_to_refund > 0
                    self.pendingReturns[msg.sender] += amount_to_refund

                # Return unused storage space
                self.bids[blindedBid] = 0

                # End processing
                return True

    # Return unused funds for unsuccessful reveal
    self.pendingReturns[msg.sender] += self.bids[blindedBid]

    # Return unused storage space
    self.bids[blindedBid] = 0

    return False


# Withdraw losing bids and overcommitted funds
@public
def withdraw():
    amount_to_send: wei_value = self.pendingReturns[msg.sender]
    self.pendingReturns[msg.sender] = 0

    # ⚠️ The send operation permits reentrancy, be sure that checks and
    # deductions are handled before this line! ⚠️
    send(msg.sender, pendingAmount)


# End the auction and send the highest bid to the beneficiary
@public
def auctionEnd():
    # Check that the bid reveal period has passed
    assert block.timestamp > self.revealEnd

    # Check that auction has not already been marked as ended
    assert not self.ended

    # Log auction ending and set flag
    log.AuctionEnded(self.highestBidder, self.highestBid)
    self.ended = True

    # Transfer funds to beneficiary
    # ⚠️ The send operation permits reentrancy, be sure that checks and
    # deductions are handled before this line! ⚠️
    send(self.beneficiary, self.highestBid)
