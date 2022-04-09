const { BN } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const ERC20 = artifacts.require('Stub_ERC20');
const YERC20 = artifacts.require('Stub_YERC20');


const CurveDeposit = artifacts.require('Stub_CurveFi_DepositY');
const CurveSwap = artifacts.require('Stub_CurveFi_SwapY');
const CurveLPToken = artifacts.require('Stub_CurveFi_LPTokenY');
const CurveCRVMinter = artifacts.require('Stub_CurveFi_Minter');
const CurveGauge = artifacts.require('Stub_CurveFi_Gauge');

const MoneyToCurve = artifacts.require('Lottery');  

const supplies = {
    dai: new BN('1000000000000000000000000'),
    usdc: new BN('1000000000000'),
    tusd: new BN('1000000000000'),
    usdt: new BN('1000000000000000000000000')
};

const deposits = {
    dai: new BN('100000000000000000000'), 
    usdc: new BN('200000000'), 
    tusd: new BN('300000000'), 
    usdt: new BN('400000000000000000000')
}

contract('Integrate Curve.Fi into your defi', async([ owner, defiowner, user1, user2 ]) => {
    let dai;
    let usdc;
    let tusd;
    let usdt;

    let ydai;
    let yusdc;
    let ytusd;
    let yusdt;

    let curveLPToken;
    let curveSwap;
    let curveDeposit;

    let crvToken;
    let curveMinter;
    let curveGauge;

    let moneyToCurve;

    before(async() => {
        // Prepare stablecoins stubs
        dai = await ERC20.new({ from: owner });
        await dai.methods['initialize(string,string,uint8,uint256)']('DAI', 'DAI', 18, supplies.dai, { from: owner });

        usdc = await ERC20.new({ from: owner });
        await usdc.methods['initialize(string,string,uint8,uint256)']('USDC', 'USDC', 6, supplies.usdc, { from: owner });

        tusd = await ERC20.new({ from: owner });
        await tusd.methods['initialize(string,string,uint8,uint256)']('TUSD', 'TUSD', 6, supplies.dai, { from: owner });

        usdt = await ERC20.new({ from: owner });
        await usdt.methods['initialize(string,string,uint8,uint256)']('USDT', 'USDT', 18, supplies.dai, { from: owner });

        //Prepare Y-token wrappers
        ydai = await YERC20.new({ from: owner });
        await ydai.initialize(dai.address, 'yDAI', 18, { from: owner });
        yusdc = await YERC20.new({ from: owner });
        await yusdc.initialize(usdc.address, 'yUSDC', 6,{ from: owner });
        ytusd = await YERC20.new({ from: owner });
        await ytusd.initialize(tusd.address, 'yTUSD', 6, { from: owner });
        yusdt = await YERC20.new({ from: owner });
        await yusdt.initialize(usdt.address, 'yUSDT', 18, { from: owner });


        //Prepare stubs of Curve.Fi
        curveLPToken = await CurveLPToken.new({from:owner});
        await curveLPToken.methods['initialize()']({from:owner});

        curveSwap = await CurveSwap.new({ from: owner });
        await curveSwap.initialize(
            [ydai.address, yusdc.address, ytusd.address, yusdt.address],
            [dai.address, usdc.address, tusd.address, usdt.address],
            curveLPToken.address, 10, { from: owner });
        await curveLPToken.addMinter(curveSwap.address, {from:owner});

        curveDeposit = await CurveDeposit.new({ from: owner });
        await curveDeposit.initialize(
            [ydai.address, yusdc.address, ytusd.address, yusdt.address],
            [dai.address, usdc.address, tusd.address, usdt.address],
            curveSwap.address, curveLPToken.address, { from: owner });
        await curveLPToken.addMinter(curveDeposit.address, {from:owner});

        crvToken = await ERC20.new({ from: owner });
        await crvToken.methods['initialize(string,string,uint8,uint256)']('CRV', 'CRV', 18, 0, { from: owner });

        curveMinter = await CurveCRVMinter.new({ from: owner });
        await curveMinter.initialize(crvToken.address, { from: owner });
        await crvToken.addMinter(curveMinter.address, { from: owner });

        curveGauge = await CurveGauge.new({ from: owner });
        await curveGauge.initialize(curveLPToken.address, curveMinter.address, {from:owner});
        await crvToken.addMinter(curveGauge.address, { from: owner });


        //Main contract
        moneyToCurve = await MoneyToCurve.new({from:defiowner});
        await moneyToCurve.initialize({from:defiowner});
        await moneyToCurve.setup(curveDeposit.address, curveGauge.address, curveMinter.address, {from:defiowner});

        //Preliminary balances
        await dai.transfer(user1, new BN('1000000000000000000000'), { from: owner });
        await usdc.transfer(user1, new BN('1000000000'), { from: owner });
        await tusd.transfer(user1, new BN('1000000000'), { from: owner });
        await usdt.transfer(user1, new BN('1000000000000000000000'), { from: owner });

        await dai.transfer(user2, new BN('1000000000000000000000'), { from: owner });
        await usdc.transfer(user2, new BN('1000000000'), { from: owner });
        await tusd.transfer(user2, new BN('1000000000'), { from: owner });
        await usdt.transfer(user2, new BN('1000000000000000000000'), { from: owner });
    });

   
    

    
});
