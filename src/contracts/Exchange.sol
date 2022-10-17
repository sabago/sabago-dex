// It will deposit and withdrawal funds
// Can manage orders - Make Or Cancel
// Handle Trades - Charge Fees

// TODO:
// [1] Set the fee account
// [3] Deposit Ether
// [4] Withdraw Ether
// [2] Deposit tokens
// [5] Withdraw tokens
// [6] Check balances
// [7] Make order
// [8] Cancel order
// [9] Fill order
// [10] Charge fees
// Can do any combination of the above

pragma solidity ^0.5.0;

import "./Token.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Exchange {
	using SafeMath for uint;
	// Variables
	address public feeAccount; // the account that receives exchange fees
	uint256 public feePercent; // the fee percentage
	address constant ETHER = address(0); // store Ether in tokens mapping with blank address
	mapping(address  => mapping(address => uint256)) public tokens; // mapping tokens: first key = token address, second key = user address, and this shows all their balances
	mapping(uint256 => _Order) public orders;
    uint256 public orderCount;
    mapping(uint256 => bool) public orderCancelled;
    mapping(uint256 => bool) public orderFilled;

	event Deposit(address token, address user, uint256 amount, uint256 balance);
	event Withdraw(address token, address user, uint amount, uint balance);
	event Order(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
    event Cancel(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
    event Trade(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        address userFill,
        uint256 timestamp
    );


    // Structs
    struct _Order {
        uint256 id;
        address user;
        address tokenGet;
        uint256 amountGet;
        address tokenGive;
        uint256 amountGive;
        uint256 timestamp;
    }

	// Orders
	// Need a way to model the order -> structs
	// a way to store the order -> mapping
	// add the order to storage -> see makeOrder

	constructor(address _feeAccount, uint256 _feePercent) public {
		feeAccount = _feeAccount;
		feePercent = _feePercent;
	}

    	// 	Safeguard: Do not want them to send ether to the smart contract by itself coz there is no way to withdraw it
    	// Fallback: reverts if Ether is sent to this smart contract by mistake
    function() external {
    	revert();
    }

	function depositEther() payable public {
		// Assume that ether has a blank address!
		tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].add(msg.value); // msg.value is how you pass ether to this function: the payable modifier allows this to work. 
		// Solidity allows you to send ether with any function call
		emit Deposit(ETHER, msg.sender, msg.value, tokens[ETHER][msg.sender]);
	}

	function withdrawEther(uint _amount) public {
		tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].sub(_amount);
		msg.sender.transfer(_amount);
		emit Withdraw(ETHER, msg.sender, _amount, tokens[ETHER][msg.sender]);
	}

	function depositToken(address _token, uint _amount) public {
		// Don't allow Ether deposits
		require(_token != ETHER);
		// Which token ? How much?
		// Send tokens to this contract
		require(Token(_token).transferFrom(msg.sender, address(this), _amount)); // this* means THIS SMART CONTRACT	
		// Manage deposit - update balance: want to use some kind of internal tracking mechanism, hence tokens
		tokens[_token][msg.sender] = tokens[_token][msg.sender].add(_amount);	
		// Emit Event
		emit Deposit(_token, msg.sender, _amount, tokens[_token][msg.sender]);
	}

	function withdrawToken(address _token, uint256 _amount) public {
        require(_token != ETHER);
        require(tokens[_token][msg.sender] >= _amount);
        tokens[_token][msg.sender] = tokens[_token][msg.sender].sub(_amount);
        require(Token(_token).transfer(msg.sender, _amount));
        emit Withdraw(_token, msg.sender, _amount, tokens[_token][msg.sender]);
    }

    function balanceOf(address _token, address _user) public view returns (uint256) {
        return tokens[_token][_user];
    }
    function makeOrder(address _tokenGet, uint256 _amountGet, address _tokenGive, uint256 _amountGive) public {
        orderCount = orderCount.add(1);
        orders[orderCount] = _Order(orderCount, msg.sender, _tokenGet, _amountGet, _tokenGive, _amountGive, now);
        emit Order(orderCount, msg.sender, _tokenGet, _amountGet, _tokenGive, _amountGive, now);
    }

    function cancelOrder(uint256 _id) public {
    	    // Must be a valid order
        _Order storage _order = orders[_id]; // Specifically fetching it out of storage
        // Must be "my" order
        require(address(_order.user) == msg.sender);
        require(_order.id == _id); // The order must exist
        orderCancelled[_id] = true;
        emit Cancel(_order.id, msg.sender, _order.tokenGet, _order.amountGet, _order.tokenGive, _order.amountGive, now);
    }

    function fillOrder(uint256 _id) public {  	
        require(_id > 0 && _id <= orderCount, 'Error, wrong id');
        require(!orderFilled[_id], 'Error, order already filled');
        require(!orderCancelled[_id], 'Error, order already cancelled');
        // Fetch the Order from storage
        _Order storage _order = orders[_id];
        // Execute the trade -> charge fes -> Emit trade event
        _trade(_order.id, _order.user, _order.tokenGet, _order.amountGet, _order.tokenGive, _order.amountGive);
        // Mark order as filled
        orderFilled[_order.id] = true;
    }

    function _trade(uint256 _orderId, address _user, address _tokenGet, uint256 _amountGet, address _tokenGive, uint256 _amountGive) internal {
        // Fee paid by the user that fills the order, a.k.a. msg.sender.
        // Charge fees
        uint256 _feeAmount = _amountGet.mul(feePercent).div(100);
		// Execute the trade	v  
        tokens[_tokenGet][msg.sender] = tokens[_tokenGet][msg.sender].sub(_amountGet.add(_feeAmount)); //msg.sender fullfilling the order
        tokens[_tokenGet][_user] = tokens[_tokenGet][_user].add(_amountGet); // _user created order
        tokens[_tokenGet][feeAccount] = tokens[_tokenGet][feeAccount].add(_feeAmount);
        tokens[_tokenGive][_user] = tokens[_tokenGive][_user].sub(_amountGive);
        tokens[_tokenGive][msg.sender] = tokens[_tokenGive][msg.sender].add(_amountGive);
        // Emit trade event
        emit Trade(_orderId, _user, _tokenGet, _amountGet, _tokenGive, _amountGive, msg.sender, now);
    }

}