// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "./shared/GovernableUpgradeable.sol";

contract PrivateOffering is ContextUpgradeable, ReentrancyGuardUpgradeable, GovernableUpgradeable {
    struct DepositData {
        bool initialized;
        uint32 amount;
        uint256 total;        
    }

    mapping(address => DepositData) private _deposits;
    mapping(string => IERC20) private _payableToken;

    uint256 private _unitPrice;
    bool private _isPaused;

    /**
     * @dev Initialization
     */
    function initialize(uint256 price) public initializer {
        __Governable_init();
        __ReentrancyGuard_init();        

        _unitPrice = price;
        _isPaused = false;
    }

    modifier onlyUnpaused() {
        require(_isPaused == false, "PAUSED");
        _;
    }

    function pause () external onlyGovernor {
        _isPaused = true;
    }

    function resume () external onlyGovernor {
        _isPaused = false;
    }

    function getUnitPrice () public view returns(uint256) {
        return _unitPrice;
    }

    function setUnitPrice (uint256 price) external onlyGovernor {
        _unitPrice = price;
    }

    /**
     * @dev add a new token contract address as payable
     * @param name Name of token
     * @param token Token contract adddress
     */
    function allowPayableToken(string calldata name, address token)
        public
        onlyGovernor
    {
        _payableToken[name] = IERC20(token);
    }

    /**
     * @dev Withdraw total payable tokens to address `to`
     *
     * Requirements:
     * - Only the owner can withdraw
     */
    function withdrawPayableToken(string calldata name, address to)
        external
        nonReentrant
        onlyGovernor
    {
        IERC20 token = _payableToken[name];
        uint256 balance = token.balanceOf(address(this));
        token.transfer(to, balance);
    }

    function deposit50(string calldata token, uint32 amount) external onlyUnpaused {
        _deposit(token, amount, 50);
    }

    function deposit25(string calldata token, uint32 amount) external onlyUnpaused {
        _deposit(token, amount, 25);
    }

    function deposit100(string calldata token, uint32 amount) external onlyUnpaused {
        _deposit(token, amount, 100);
    }

    function getDepositAmount () public view returns(uint256) {
        return _deposits[_msgSender()].amount;
    }

    function getDepositTotal () public view returns(uint256) {
        return _deposits[_msgSender()].total;
    }

    function _deposit(string calldata symbol, uint32 amount, uint32 percent) private {
        require(amount > 0, "INVALID_AMOUNT");

        uint256 cost = (amount * _unitPrice * percent) / 100;
        require(
            _payableToken[symbol].transferFrom(
                _msgSender(),
                address(this),
                cost
            ),
            "TRANSFER_ERROR"
        );

        if (_deposits[_msgSender()].initialized) {
            _deposits[_msgSender()].amount += amount;    
            _deposits[_msgSender()].total += cost;    
        } else {
            _deposits[_msgSender()] = DepositData(true, amount, cost);
        }
    }
}