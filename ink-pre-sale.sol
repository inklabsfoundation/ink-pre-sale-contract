pragma solidity ^0.4.15;

contract INK {
    uint8 public decimals;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    function transferFrom(address _from, address _to, uint256 value);
}

contract INKPreSale {
    address public constant inkAddress = 0xfe59cbc1704e89a698571413a81f0de9d8f00c69; // erc20 address
    address public constant inkLabsFoundationAddress = 0xaf8cf283ef7d1ad9fa824bd4de564f3b1b9fcd7a; // ink labs withdrawl address QccDD4Vk5Tc5Y84ydAcj4hpNkahYcsCsRq
    uint256 public constant exchangeRate = 115;   // 1 qtum = 115 ink
    uint256 public constant startDate = 1509148800; // start at 2017/10/28 00:00:00
    uint256 public constant endDate = 1509753600; // end at 2017/11/04 00:00:00
    uint256 public constant qtumDecimals = 8;
    uint256 public needQtumAmount = 800000 * (10**qtumDecimals); // 800000 qtum
    uint256 private constant voutsMaxLimit = 400;

    address public publisher; // this publisher must be INK publisher
    INK private inkToken;

    mapping (address => uint256) public qtumIncomingOf;
    mapping (address => uint256) public qtumOutgoingOf;
    mapping (address => uint256) public inkOutgoingOf; 
    mapping (address => uint256) public qtumBalanceOf;
    address[] public investorsWhiteList;

    event InvestorAdded(address investor);
    event IncomingInvestment(address investor, uint256 value);
    event InvestmentSucceed();
    event NotEnoughInkToSend(uint256 publisherInkAllowance, uint256 publisherInkBalance, uint256 ink2send);
    event Withdrawl(address to, uint256 value);
    event PublishINK(address receiver, uint256 value);
    event Refund(address to, uint256 value);

    function INKPreSale() {
        publisher = msg.sender;
        inkToken = INK(inkAddress);
    }

    function() payable {
        require(now >= startDate);
        require(now <= endDate);
        require(_hasInvestor(msg.sender));
        require(needQtumAmount >= msg.value);

        qtumIncomingOf[msg.sender] += msg.value;

        needQtumAmount -= msg.value;
        qtumBalanceOf[msg.sender] += msg.value;

        IncomingInvestment(msg.sender, msg.value);
        if(needQtumAmount <= 0){
            InvestmentSucceed();
        }
    }
    function addInvestor(address _investor) returns (bool success){
        require(publisher == msg.sender);
        require (!_hasInvestor(_investor));

        investorsWhiteList.push(_investor);

        InvestorAdded(_investor);
        return true;
    }

    function publish() payable {
        require(publisher == msg.sender);
        require(now > endDate);

        uint256 publisherInkAllowance = _getPublisherAllowance();
        uint256 publisherInkBalance = _getPublisherInkBalance();
        uint256 inkDecimals = uint256(inkToken.decimals());
        uint256 qtumToInkRatio = _divFloor((10**inkDecimals), (10**qtumDecimals));
        uint256 voutsCount = 0;
        for(uint256 i = 0; i < investorsWhiteList.length; i++){
            if(voutsCount > voutsMaxLimit){
                break;
            }
            uint256 qtum2send = qtumBalanceOf[investorsWhiteList[i]];

            if(qtum2send <= 0){
                continue;
            }

            uint256 ink2send = qtum2send * exchangeRate * qtumToInkRatio;
            if(publisherInkAllowance < ink2send || publisherInkBalance < ink2send){
                NotEnoughInkToSend(publisherInkAllowance, publisherInkBalance, ink2send);

                if(publisherInkAllowance > publisherInkBalance){
                    ink2send = publisherInkBalance - 1;
                }else{
                    ink2send = publisherInkAllowance - 1;
                }
                qtum2send = _divFloor(ink2send, exchangeRate * (10**qtumDecimals) * qtumToInkRatio);
            }
            if(ink2send <= 0 || qtum2send <= 0){
                continue;
            }

            inkLabsFoundationAddress.transfer(qtum2send);
            Withdrawl(inkLabsFoundationAddress, qtum2send);

            _publishInk(investorsWhiteList[i], ink2send);
            PublishINK(investorsWhiteList[i], ink2send);

            publisherInkAllowance -= ink2send;
            publisherInkBalance -= ink2send;
            inkOutgoingOf[investorsWhiteList[i]] += ink2send;
            qtumBalanceOf[investorsWhiteList[i]] -= qtum2send;
            qtumOutgoingOf[investorsWhiteList[i]] += qtum2send;
            voutsCount++;
        }
    }

    function refund() payable {
        require(publisher == msg.sender);
        require(now > endDate);

        uint256 voutsCount = 0;
        for(uint256 i = 0; i < investorsWhiteList.length; i++){
            if(voutsCount > voutsMaxLimit){
                break;
            }
            uint256 qtum2send = qtumBalanceOf[investorsWhiteList[i]];

            if(qtum2send <= 0){
                continue;
            }

            investorsWhiteList[i].transfer(qtum2send);
            Refund(investorsWhiteList[i], qtum2send);

            qtumBalanceOf[investorsWhiteList[i]] -= qtum2send;
            qtumOutgoingOf[investorsWhiteList[i]] += qtum2send;
            voutsCount++;
        }
    }

    function _hasInvestor(address _investor) internal returns (bool has) {
        for(uint256 i = 0; i < investorsWhiteList.length; i++){
            if(_investor == investorsWhiteList[i]){
                return true;
            }
        }
        return false;
    }

    function _getPublisherInkBalance() internal returns (uint256 balance) {
        return inkToken.balanceOf(publisher);
    }

    function _getPublisherAllowance() internal returns (uint256 allowance) {
        return inkToken.allowance(publisher, this);
    }

    function _publishInk(address _receiver, uint256 _value) internal {
        inkToken.transferFrom(publisher, _receiver, _value); // this publisher must be Ink publisher
    }

    function _divFloor(uint256 _dividend, uint256 _divisor) internal returns (uint256 result) {
        uint256 remainder = _dividend % _divisor;
        uint256 _result = 0;
        if(remainder != 0){
            _result = (_dividend - (_divisor + remainder)) / _divisor;
            if(_result <= 0){
                return 0;
            }
        }else{
            _result = _dividend / _divisor;
        }
        return _result;
    }
}
