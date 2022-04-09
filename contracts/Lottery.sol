//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
//import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


import "./interfaces/IUniswapV2Exchange.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IBalancerRegistry.sol";
import "./interfaces/IBalancerPool.sol";

import "./curvefi/ICurveFi_DepositY.sol";
import "./curvefi/ICurveFi_Gauge.sol";
import "./curvefi/ICurveFi_Minter.sol";
import "./curvefi/ICurveFi_SwapY.sol";
import "./curvefi/IYERC20.sol";
import "./RandomNumberConsumer.sol";




contract Lottery is AccessControlUpgradeable,ReentrancyGuardUpgradeable {

    using Counters for Counters.Counter; 
    using SafeMath for uint256;
    uint256 public ticketPrice;
    Counters.Counter private _ticketSerial; 
    uint256 public timestamp;
    uint256 public numberRamdon;
    uint[] private totalMoney;
    uint256 public commission;
    address public manager;
    bool claimMoney = false;
	uint256 public total;
    uint256 public totalCommission;

    address public curveFi_Deposit;
    address public curveFi_Swap;
    address public curveFi_LPToken;
    address public curveFi_LPGauge;
    address public curveFi_CRVMinter;
    address public curveFi_CRVToken;
    RandomNumberConsumer ramdon;



     struct Participant {
        uint256  _ticketSerial;
        address player;
        uint256 typeToken;
        uint256 mount;
        bool claim;
    }

    mapping(uint256 => Participant) public participants;

    
    function initialize() external initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        manager = _msgSender();
        ticketPrice = 10;
        commission = 5;

 
        timestamp = block.timestamp;


    }

     function setup(address _depositContract, address _gaugeContract, address _minterContract) external{
        require(_depositContract != address(0), "Incorrect deposit contract address");

        curveFi_Deposit = _depositContract;
        curveFi_Swap = ICurveFi_DepositY(curveFi_Deposit).curve();
        curveFi_LPGauge = _gaugeContract;
        curveFi_LPToken = ICurveFi_DepositY(curveFi_Deposit).token();

        require(ICurveFi_Gauge(curveFi_LPGauge).lp_token() == address(curveFi_LPToken), "CurveFi LP tokens do not match");        

        curveFi_CRVMinter = _minterContract;
        curveFi_CRVToken = ICurveFi_Gauge(curveFi_LPGauge).crv_token();
    }





    

    function Winner()external{

        require(block.timestamp - timestamp > 7 days,"the lottery is not over");


       

        numberRamdon = 10;

      


        address winner = participants[numberRamdon].player;

       
       
        address[4] memory stablecoins = ICurveFi_DepositY(curveFi_Deposit).underlying_coins();

        //Step 1 - Calculate amount of Curve LP-tokens to unstake
        uint256 nWithdraw;
        uint256 i;

        for (i = 0; i < stablecoins.length; i++) {
            nWithdraw = nWithdraw.add(normalize(stablecoins[i], totalMoney[i]));
        }

        uint256 withdrawShares = calculateShares(nWithdraw);

        //Check if you can re-use unstaked LP tokens
        uint256 notStaked = curveLPTokenUnstaked();
        if (notStaked > 0) {
            withdrawShares = withdrawShares.sub(notStaked);
        }

        //Step 2 - Unstake Curve LP tokens from Gauge
        ICurveFi_Gauge(curveFi_LPGauge).withdraw(withdrawShares);


        //Step 3 - Withdraw stablecoins from CurveDeposit
        IERC20(curveFi_LPToken).approve(curveFi_Deposit, withdrawShares);
        ICurveFi_DepositY(curveFi_Deposit).remove_liquidity_imbalance(totalMoney, withdrawShares);

      


        //Step 4 - Send stablecoins to the requestor
        for(i = 0; i <  stablecoins.length; i++){

            total = 0;
            totalCommission = 0;

            IERC20 stablecoin = IERC20(stablecoins[i]);
            uint256 balance = stablecoin.balanceOf(address(this));
            uint256 amount = (balance <= totalMoney[i]) ? balance : totalMoney[i]; //Safepoint for rounding

            total = amount - totalMoney[i];

            totalCommission = (total * commission) / 100;

            total -= totalCommission;

            stablecoin.approve(winner, total);
            stablecoin.approve(manager, totalCommission);
        }



        timestamp = block.timestamp;

    }


    function investmMoney()external{

        require(block.timestamp - timestamp > 2 days && block.timestamp - timestamp < 7 days ,"no es se puede invertir");

         //Step 1 - deposit stablecoins and get Curve.Fi LP tokens
         ICurveFi_DepositY(curveFi_Deposit).add_liquidity(totalMoney, 0); //0 to mint all Curve has to 

         //Step 2 - stake Curve LP tokens into Gauge and get CRV rewards
         uint256 curveLPBalance = IERC20(curveFi_LPToken).balanceOf(address(this));
 
         IERC20(curveFi_LPToken).approve(curveFi_LPGauge, curveLPBalance);
         ICurveFi_Gauge(curveFi_LPGauge).deposit(curveLPBalance);
 
         //Step 3 - get all the rewards (and make whatever you need with them)
         crvTokenClaim();
         uint256 crvAmount = IERC20(curveFi_CRVToken).balanceOf(address(this));
         IERC20(curveFi_CRVToken).approve(_msgSender(), crvAmount);
        

    }


    function buyTikect(uint256[4] memory _amounts, uint256 typeToken, uint256 _ticketQuantity) external payable nonReentrant{


        require(block.timestamp - timestamp < 2 days, "the lottery has already closed");

        uint256 totalPrice = _ticketQuantity * ticketPrice;

        require(totalPrice = _amounts[typeToken],"Amount not equal to number of tickets");


        for(uint256 i = 0; i < _ticketQuantity.length; i++){

            _ticketSerial.increment(); 

            participants[_ticketSerial.current()] = Participant(
                _ticketSerial,
                _msgSender(),
                typeToken,
                _amounts[typeToken],
                false
            );
            
        }

        totalMoney[0] += _amounts[0];
        totalMoney[1] += _amounts[1];
        totalMoney[2] += _amounts[2];
        totalMoney[3] += _amounts[3];

        address[4] memory stablecoins = ICurveFi_DepositY(curveFi_Deposit).underlying_coins();

        for (uint256 i = 0; i < stablecoins.length; i++) {
            IERC20(stablecoins[i]).safeTransferFrom(_msgSender(), address(this), _amounts[i]);
            IERC20(stablecoins[i]).safeApprove(curveFi_Deposit, _amounts[i]);
        }
        

    }


    function claimMony(uint256 ticketNumber) public{

        //require(participants[ticketNumber].player == _msgSender(),"you are not the owner of this ticket");

        require(!participants[ticketNumber].claim,"amount of the already withdrawn tiket");

        address[4] memory stablecoins = ICurveFi_DepositY(curveFi_Deposit).underlying_coins();

        IERC20 stablecoin = IERC20(stablecoins[participants[ticketNumber].typeToken]);

        stablecoin.safeTransfer(participants[ticketNumber].player, participants[ticketNumber].mount);

        participants[ticketNumber].claim = true;

    }




	 /**
     * @notice Util to normalize balance up to 18 decimals
     */
    function normalize(address coin, uint256 amount) internal view returns(uint256) {
        uint8 decimals = IERC20(coin).decimals();
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(uint256(10)**(decimals-18));
        } else if (decimals < 18) {
            return amount.mul(uint256(10)**(18 - decimals));
        }
    }


    /**
     * @notice Calculate shared part of this contract in LP token distriution
     * @param normalizedWithdraw amount of stablecoins to withdraw normalized to 18 decimals
     */    
    function calculateShares(uint256 normalizedWithdraw) internal view returns(uint256) {
        uint256 nBalance = normalizedBalance();
        uint256 poolShares = curveLPTokenBalance();
        
        return poolShares.mul(normalizedWithdraw).div(nBalance);
    }

    /**
     * @notice Balances of stablecoins available for withdraw normalized to 18 decimals
     */
    function normalizedBalance() public view returns(uint256) {
        address[4] memory stablecoins = ICurveFi_DepositY(curveFi_Deposit).underlying_coins();
        uint256[4] memory balances = balanceOfAll();

        uint256 summ;
        for (uint256 i=0; i < stablecoins.length; i++){
            summ = summ.add(normalize(stablecoins[i], balances[i]));
        }
        return summ;
    }

    /**
     * @notice Get full amount of Curve LP tokens available for this contract
     */
    function curveLPTokenBalance() public view returns(uint256) {
        uint256 staked = curveLPTokenStaked();
        uint256 unstaked = curveLPTokenUnstaked();
        return unstaked.add(staked);
    }

        function curveLPTokenStaked() public view returns(uint256) {
        return ICurveFi_Gauge(curveFi_LPGauge).balanceOf(address(this));
    }

    function curveLPTokenUnstaked() public view returns(uint256) {
        return IERC20(curveFi_LPToken).balanceOf(address(this));
    }

    function balanceOfAll() public view returns(uint256[4] memory balances) {
        address[4] memory stablecoins = ICurveFi_DepositY(curveFi_Deposit).underlying_coins();

        uint256 curveLPBalance = curveLPTokenBalance();
        uint256 curveLPTokenSupply = IERC20(curveFi_LPToken).totalSupply();

        require(curveLPTokenSupply > 0, "No Curve LP tokens minted");

        for (uint256 i = 0; i < stablecoins.length; i++) {
            //Get Y-tokens balance
            uint256 yLPTokenBalance = ICurveFi_SwapY(curveFi_Swap).balances(int128(i));
            address yCoin = ICurveFi_SwapY(curveFi_Swap).coins(int128(i));

            //Calculate user's shares in y-tokens
            uint256 yShares = yLPTokenBalance.mul(curveLPBalance).div(curveLPTokenSupply);

            //Get y-token price for underlying coin
            uint256 yPrice = IYERC20(yCoin).getPricePerFullShare();

            //Re-calculate available stablecoins balance by y-tokens shares
            balances[i] = yPrice.mul(yShares).div(1e18);
        }
    }

      function crvTokenClaim() internal {
        ICurveFi_Minter(curveFi_CRVMinter).mint(curveFi_LPGauge);
    }


    


}
