//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Lottery is AccessControlUpgradeable {
	
	function initialize() external initializer {
		__AccessControl_init();
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

	}
	
}