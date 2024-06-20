// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SetupTest} from "test/setup.t.sol";
import {Usd0PP} from "src/token/Usd0PP.sol";
import {IUsd0PP} from "src/interfaces/token/IUsd0PP.sol";
import {CONTRACT_USD0PP, CONTRACT_TREASURY, BOND_DURATION_FOUR_YEAR} from "src/constants.sol";
import {
    BeginInPast,
    BondNotStarted,
    BondNotFinished,
    BondFinished,
    InvalidName,
    InvalidSymbol,
    AmountIsZero,
    Blacklisted
} from "src/errors.sol";
import {IERC20Errors} from "openzeppelin-contracts/interfaces/draft-IERC6093.sol";

contract Usd0PPTest is SetupTest {
    address public rwa;

    function setUp() public override {
        super.setUp();
    }

    function _createRwa() internal {
        vm.prank(admin);
        rwa = rwaFactory.createRwa("rwa", "rwa", 6);
        whitelistPublisher(address(rwa), address(stbcToken));

        _setupBucket(address(rwa), address(stbcToken));

        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1.1e18);
        treasury = address(registryContract.getContract(CONTRACT_TREASURY));
    }

    function testAnyoneCanCreateUsd0PP() public {
        Usd0PP usd0PP = new Usd0PP();
        _resetInitializerImplementation(address(usd0PP));
        usd0PP.initialize(
            address(registryContract), "UsualDAO Bond 121", "USD0PP121", block.timestamp
        );
    }

    function testCreateUsd0PPFailIfIncorrect() public {
        vm.warp(10);

        Usd0PP usd0PPbefore = new Usd0PP();
        _resetInitializerImplementation(address(usd0PPbefore));
        // begin in past
        vm.expectRevert(abi.encodeWithSelector(BeginInPast.selector));
        vm.prank(admin);
        usd0PPbefore.initialize(address(registryContract), "UsualDAO Bond", "USD0PP", 9);

        Usd0PP lsausUSbadName = new Usd0PP();
        _resetInitializerImplementation(address(lsausUSbadName));
        vm.expectRevert(abi.encodeWithSelector(InvalidName.selector));
        vm.prank(admin);
        lsausUSbadName.initialize(address(registryContract), "", "USD0PP", block.timestamp);

        Usd0PP lsausUSbadSymbol = new Usd0PP();
        _resetInitializerImplementation(address(lsausUSbadSymbol));
        vm.expectRevert(abi.encodeWithSelector(InvalidSymbol.selector));
        vm.prank(admin);
        lsausUSbadSymbol.initialize(address(registryContract), "USD0PP", "", block.timestamp);
    }

    function testMintUsd0PP(uint256 amount) public {
        amount = bound(amount, 100_000_000_000, type(uint128).max);
        _createRwa();
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");
        vm.stopPrank();
        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0
        // approve USD0 to daoCollateral

        stbcToken.approve(address(usd0PP100), amount);
        usd0PP100.mint(amount);
        skip(3650 days);
        usd0PP100.unwrap();
        assertEq(stbcToken.balanceOf(address(alice)), amount);
        vm.stopPrank();
    }

    function testMintWithPermitUsd0PP(uint256 amount) public {
        amount = bound(amount, 100_000_000_000, type(uint128).max);
        _createRwa();
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");
        vm.stopPrank();
        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount, deadline
        );

        usd0PP100.mintWithPermit(amount, deadline, v, r, s);
        skip(3650 days);
        usd0PP100.unwrap();
        assertEq(stbcToken.balanceOf(address(alice)), amount);
        vm.stopPrank();
    }

    function testMintWithPermitUsd0PPFailingERC20Permit(uint256 amount) public {
        amount = bound(amount, 100_000_000_000, type(uint128).max);
        _createRwa();
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");
        vm.stopPrank();
        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0

        uint256 deadline = block.timestamp - 1;
        (uint8 v, bytes32 r, bytes32 s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount, deadline
        );
        // deadline in the past
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(usd0PP100), 0, amount
            )
        );
        usd0PP100.mintWithPermit(amount, deadline, v, r, s);
        deadline = block.timestamp + 100;
        // insufficient amount
        (v, r, s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount - 1, deadline
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(usd0PP100), 0, amount
            )
        );
        usd0PP100.mintWithPermit(amount, deadline, v, r, s);
        // bad v
        (v, r, s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount, deadline
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(usd0PP100), 0, amount
            )
        );

        usd0PP100.mintWithPermit(amount, deadline, v + 1, r, s);
        // bad r
        (v, r, s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount, deadline
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(usd0PP100), 0, amount
            )
        );

        usd0PP100.mintWithPermit(amount, deadline, v, keccak256("bad r"), s);

        // bad s
        (v, r, s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount, deadline
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(usd0PP100), 0, amount
            )
        );
        usd0PP100.mintWithPermit(amount, deadline, v, r, keccak256("bad s"));

        //bad nonce
        (v, r, s) = _getSelfPermitData(
            address(stbcToken),
            alice,
            alicePrivKey,
            address(usd0PP100),
            amount,
            deadline,
            IERC20Permit(address(stbcToken)).nonces(alice) + 1
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(usd0PP100), 0, amount
            )
        );
        usd0PP100.mintWithPermit(amount, deadline, v, r, s);

        //bad spender
        (v, r, s) = _getSelfPermitData(
            address(stbcToken),
            bob,
            bobPrivKey,
            address(usd0PP100),
            amount,
            deadline,
            IERC20Permit(address(stbcToken)).nonces(bob)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(usd0PP100), 0, amount
            )
        );
        usd0PP100.mintWithPermit(amount, deadline, v, r, s);
        // this should work
        (v, r, s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount, deadline
        );
        usd0PP100.mintWithPermit(amount, deadline, v, r, s);
        skip(3650 days);
        usd0PP100.unwrap();
        assertEq(stbcToken.balanceOf(address(alice)), amount);

        vm.stopPrank();
    }

    function testMintShouldWorkUntilTheEnd(uint256 amount) public {
        amount = bound(amount, 100_000_000_000, type(uint128).max);
        _createRwa();
        // 10% over 100 days for 1000 USD0 max
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");
        vm.stopPrank();
        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0
        // approve USD0 to daoCollateral

        stbcToken.approve(address(usd0PP100), amount);
        vm.warp(usd0PP100.getEndTime() - 1);
        usd0PP100.mint(amount / 2);
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), amount / 2);
        vm.expectRevert(abi.encodeWithSelector(BondNotFinished.selector));
        usd0PP100.unwrap();
        vm.warp(usd0PP100.getEndTime());
        vm.expectRevert(abi.encodeWithSelector(BondFinished.selector));
        usd0PP100.mint(amount / 2);
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), amount / 2);
        usd0PP100.unwrap();
        vm.stopPrank();
    }

    function testMintWithPermitShouldWorkUntilTheEnd(uint256 amount) public {
        amount = bound(amount, 100_000_000_000, type(uint128).max);
        _createRwa();
        // 10% over 100 days for 1000 USD0 max
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");
        vm.stopPrank();
        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0

        uint256 deadline = type(uint256).max;
        (uint8 v, bytes32 r, bytes32 s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount / 2, deadline
        );

        vm.warp(usd0PP100.getEndTime() - 1);
        usd0PP100.mintWithPermit(amount / 2, deadline, v, r, s);
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), amount / 2);
        vm.expectRevert(abi.encodeWithSelector(BondNotFinished.selector));
        usd0PP100.unwrap();
        vm.warp(usd0PP100.getEndTime());

        (v, r, s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount / 2, deadline
        );
        vm.expectRevert(abi.encodeWithSelector(BondFinished.selector));
        usd0PP100.mintWithPermit(amount / 2, deadline, v, r, s);
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), amount / 2);
        usd0PP100.unwrap();
        vm.stopPrank();
    }

    function testMintBeforeBondStartShouldFail(uint256 amount) public {
        amount = bound(amount, 100_000_000_000, type(uint128).max);
        _createRwa();
        // 10% over 100 days for 1000 USD0 max
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");
        vm.stopPrank();
        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0
        // approve USD0 to daoCollateral

        stbcToken.approve(address(usd0PP100), amount);
        vm.warp(block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(BondNotStarted.selector));
        usd0PP100.mint(amount);
        vm.stopPrank();
    }

    function testMintTwiceAndTransferUsd0PP(uint256 amount) public {
        amount = bound(amount, 100_000_000_000, type(uint128).max);
        _createRwa();
        // 10% over 100 days for 1000 USD0 max
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");

        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0
        // approve USD0 to daoCollateral
        stbcToken.approve(address(usd0PP100), amount);
        // divide amount
        uint256 fourthAmount = amount / 4;
        uint256 halfAmount = amount / 2;
        usd0PP100.mint(fourthAmount);
        skip(1 days);
        usd0PP100.mint(halfAmount);
        skip(10 days); // 11days since beginning
        // transfer 1/4 of the amount
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), (halfAmount + fourthAmount));
        usd0PP100.transfer(address(bob), fourthAmount);
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), (halfAmount));
        // bob paid no fee
        assertEq(IERC20(address(usd0PP100)).balanceOf(treasury), 0);
        uint256 bobBalance1 = fourthAmount;
        assertEq(IERC20(usd0PP100).balanceOf(address(bob)), bobBalance1);
        skip(10 days); // 21 days since beginning
        usd0PP100.transfer(address(bob), halfAmount);
        // bob gets less because of the fee

        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), (0));
        assertEq(IERC20(address(usd0PP100)).balanceOf(treasury), 0);
        uint256 bobBalance2 = halfAmount;
        assertEq(IERC20(usd0PP100).balanceOf(address(bob)), bobBalance1 + bobBalance2);
        // alice still has some pending rewards as she has half of the amount for  days after her last claim
        skip(10 days); // 31 days since beginning
        usd0PP100.mint(fourthAmount);
        skip(20 days); // 51 days since beginning
        vm.stopPrank();
        skip(20 days); // 71 days since beginning
        vm.prank(bob);
        IERC20(usd0PP100).approve(jack, bobBalance1);
        vm.prank(jack);
        usd0PP100.transferFrom(address(bob), address(jack), bobBalance1);

        uint256 jackBalance = bobBalance1;
        assertEq(IERC20(usd0PP100).balanceOf(address(bob)), bobBalance2);
        assertEq(IERC20(usd0PP100).balanceOf(address(jack)), jackBalance);
        vm.warp(usd0PP100.getEndTime()); // 99 days since beginning + 1 second
        vm.prank(alice);
        usd0PP100.unwrap();
        assertApproxEqAbs(stbcToken.balanceOf(address(alice)), fourthAmount, 1_000_000);
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), 0);
        vm.prank(bob);
        usd0PP100.unwrap();
        assertApproxEqAbs(stbcToken.balanceOf(address(bob)), bobBalance2, 1_000_000);
        assertEq(IERC20(usd0PP100).balanceOf(address(bob)), 0);
        vm.prank(jack);
        usd0PP100.unwrap();
        assertApproxEqAbs(stbcToken.balanceOf(address(jack)), jackBalance, 1_000_000);
        assertEq(IERC20(usd0PP100).balanceOf(address(jack)), 0);
        assertEq(IERC20(usd0PP100).totalSupply(), 0);
    }

    // can't mint 1 day before end
    // test minting right before end should revert
    function testMintShouldNotFailOneSecondBeforeTheEnd() public {
        uint256 amount = 1000 ether;
        _createRwa();
        // 10% over 100 days for 1000 USD0 max
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");

        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount / 2);
        vm.startPrank(address(alice));
        // swap for USD0
        // approve USD0 to daoCollateral

        stbcToken.approve(address(usd0PP100), amount);

        // divide amount
        skip(98 days);
        usd0PP100.mint(amount / 2);
        vm.warp(usd0PP100.getEndTime() - 1);
        IERC20(usd0PP100).transfer(bob, amount / 2);
        vm.stopPrank();
        vm.prank(address(daoCollateral));
        stbcToken.mint(address(bob), amount - amount / 2);
        vm.startPrank(address(bob));
        stbcToken.approve(address(usd0PP100), amount);
        usd0PP100.mint(amount - amount / 2);
        skip(usd0PP100.getEndTime() + 1);

        usd0PP100.unwrap();
        assertEq(stbcToken.balanceOf(address(bob)), amount);
        assertEq(IERC20(usd0PP100).balanceOf(address(bob)), 0);
        vm.stopPrank();
        // alice can unwrap
        assertEq(stbcToken.balanceOf(address(alice)), 0);
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), 0);
        vm.prank(address(alice));
        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        usd0PP100.unwrap();
    }

    // can't mint 1 day before end
    // test minting right before end should revert
    function testMintWithPermitShouldNotFailOneSecondBeforeTheEnd() public {
        uint256 amount = 1000 ether;
        _createRwa();
        // 10% over 100 days for 1000 USD0 max
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");

        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount / 2);
        vm.startPrank(address(alice));
        // swap for USD0

        uint256 deadline = type(uint256).max;
        (uint8 v, bytes32 r, bytes32 s) = _getSelfPermitData(
            address(stbcToken), alice, alicePrivKey, address(usd0PP100), amount / 2, deadline
        );

        // divide amount
        skip(98 days);
        usd0PP100.mintWithPermit(amount / 2, deadline, v, r, s);
        vm.warp(usd0PP100.getEndTime() - 1);
        IERC20(usd0PP100).transfer(bob, amount / 2);
        vm.stopPrank();
        vm.prank(address(daoCollateral));
        stbcToken.mint(address(bob), amount / 2);

        (v, r, s) = _getSelfPermitData(
            address(stbcToken), bob, bobPrivKey, address(usd0PP100), amount / 2, deadline
        );
        vm.startPrank(address(bob));
        usd0PP100.mintWithPermit(amount / 2, deadline, v, r, s);
        skip(usd0PP100.getEndTime() + 1);

        usd0PP100.unwrap();
        assertEq(stbcToken.balanceOf(address(bob)), amount);
        assertEq(IERC20(usd0PP100).balanceOf(address(bob)), 0);
        vm.stopPrank();
        // alice can unwrap
        assertEq(stbcToken.balanceOf(address(alice)), 0);
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), 0);
        vm.prank(address(alice));
        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        usd0PP100.unwrap();
    }

    function testConsecutiveMints() public {
        uint256 amount = 1_000_000 ether;
        _createRwa();
        // 10% over 100 days for 1000 USD0 max
        Usd0PP usd0PP100 = _createBond("UsualDAO Bond 100", "USD0PP A100");

        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0
        // approve USD0 to daoCollateral

        stbcToken.approve(address(usd0PP100), amount);
        // divide amount
        uint256 fourthAmount = amount / 4;
        uint256 halfAmount = amount / 2;
        usd0PP100.mint(fourthAmount);

        skip(1 days + 3600);
        usd0PP100.mint(fourthAmount);
        skip(3600 * 22);
        usd0PP100.mint(fourthAmount);
        skip(10 days + 3599); // 11days since beginning only 1sec until 12days

        skip(1 days + 3600); // 12 days + 1 hour
        usd0PP100.transfer(address(bob), fourthAmount);
        usd0PP100.mint(fourthAmount);
        vm.stopPrank();
        skip(3600);
        skip(3600);
        vm.prank(bob);
        usd0PP100.transfer(address(alice), fourthAmount);
        skip(3600);

        skip(3600 * 20); // 13 days

        vm.prank(alice);
        usd0PP100.transfer(address(bob), halfAmount);
        skip((3600 * 9) - 1); // 14 days - 1sec
        uint256 blockNum = block.timestamp;
        skip(1);
        // if less than 12sec passed since the last block then no new block
        assertEq(block.timestamp, blockNum + 1);

        skip(12);
        assertEq(block.timestamp, blockNum + 13);

        blockNum = block.timestamp;
        skip(usd0PP100.getEndTime());
        vm.prank(bob);
        usd0PP100.unwrap();
        vm.prank(alice);
        usd0PP100.unwrap();
        assertApproxEqAbs(stbcToken.balanceOf(address(alice)), halfAmount, 1_000_000);
        assertApproxEqAbs(stbcToken.balanceOf(address(bob)), halfAmount, 1_000_000);
        assertEq(IERC20(usd0PP100).balanceOf(address(alice)), 0);
        assertEq(IERC20(usd0PP100).balanceOf(address(bob)), 0);
    }

    function testTransferFrom1(uint256 amount) public {
        amount = bound(amount, 100_000_000_000, type(uint128).max);
        _createRwa();
        Usd0PP usd0PP180 = _createBond("UsualDAO Bond 180", "USD0PP A0");
        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);
        amount = amount / 2;
        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0
        // approve USD0 to daoCollateral

        stbcToken.approve(address(usd0PP180), amount);
        usd0PP180.mint(amount);
        assertEq(stbcToken.balanceOf(address(usd0PP180)), amount);
        skip(10 days);
        // 10 days after minting
        IERC20(usd0PP180).approve(bob, amount / 2);
        vm.stopPrank();

        vm.prank(bob);
        IERC20(usd0PP180).transferFrom(alice, bob, amount / 2);

        uint256 bobBalance = amount / 2;
        assertEq(IERC20(usd0PP180).balanceOf(address(bob)), bobBalance);
    }

    function testTransferFromShouldFailIfBlacklisted() public {
        uint256 amount = 100_000_000_000;
        _createRwa();
        Usd0PP usd0PP180 = _createBond("UsualDAO Bond 180", "USD0PP A0");
        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);
        amount = amount / 2;
        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0
        // approve USD0 to daoCollateral

        stbcToken.approve(address(usd0PP180), amount);
        usd0PP180.mint(amount);
        assertEq(stbcToken.balanceOf(address(usd0PP180)), amount);
        skip(10 days);
        // 10 days after minting
        IERC20(usd0PP180).approve(bob, amount / 2);
        vm.stopPrank();

        vm.prank(admin);
        stbcToken.blacklist(address(alice));

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Blacklisted.selector));
        IERC20(usd0PP180).transferFrom(alice, bob, amount / 2);

        vm.startPrank(admin);
        stbcToken.unBlacklist(address(alice));
        stbcToken.blacklist(address(bob));
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Blacklisted.selector));
        IERC20(usd0PP180).transferFrom(alice, bob, amount / 2);
    }

    function testTransferFromShouldNotFailAllowListDisabled() public {
        uint256 amount = 100_000_000_000;
        _createRwa();
        Usd0PP usd0PP180 = _createBond("UsualDAO Bond 180", "USD0PP A0");
        vm.prank(hashnote);
        dataPublisher.publishData(address(rwa), 1e6);
        amount = amount / 2;
        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        // swap for USD0
        // approve USD0 to daoCollateral

        stbcToken.approve(address(usd0PP180), amount);
        usd0PP180.mint(amount);
        assertEq(stbcToken.balanceOf(address(usd0PP180)), amount);
        skip(10 days);
        // 10 days after minting
        IERC20(usd0PP180).approve(bob, amount);
        vm.stopPrank();

        vm.startPrank(bob);
        IERC20(usd0PP180).approve(bob, amount);
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, bob));
        IERC20(usd0PP180).transferFrom(alice, bob, amount / 2);
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, bob));
        IERC20(usd0PP180).transferFrom(bob, alice, amount / 2);
    }

    function testTransferShouldFailIfNullAddress() public {
        testTransferFrom1(100e18);
        // get bond with symbol USD0PP A0
        IUsd0PP usd0PP180 = IUsd0PP(registryContract.getContract(CONTRACT_USD0PP));
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0))
        );
        usd0PP180.transfer(address(0), 1);
    }

    function testTransferShouldFailIfZeroAmount() public {
        testTransferFrom1(100e18);
        // get bond with symbol USD0PP A0
        IUsd0PP usd0PP180 = IUsd0PP(registryContract.getContract(CONTRACT_USD0PP));
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        usd0PP180.transfer(bob, 0);
    }

    function testTransferShouldFailIfMoreThanBalance() public {
        testTransferFrom1(100e18);

        // get bond with symbol USD0PP A0
        IUsd0PP usd0PP180 = IUsd0PP(registryContract.getContract(CONTRACT_USD0PP));

        uint256 aliceBalanceBefore = IERC20(address(usd0PP180)).balanceOf(address(alice));
        uint256 bobBalanceBefore = IERC20(address(usd0PP180)).balanceOf(address(bob));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                alice,
                aliceBalanceBefore,
                aliceBalanceBefore + 1
            )
        );
        vm.prank(alice);
        usd0PP180.transfer(bob, aliceBalanceBefore + 1);
        uint256 aliceBalanceAfter = IERC20(address(usd0PP180)).balanceOf(address(alice));
        uint256 bobBalanceAfter = IERC20(address(usd0PP180)).balanceOf(address(bob));
        assertEq(aliceBalanceAfter, aliceBalanceBefore);
        assertEq(bobBalanceAfter, bobBalanceBefore);
    }

    function testTransferFromShouldFailIfZeroAmount() public {
        testTransferFrom1(100e18);
        // get bond with symbol USD0PP A0
        IERC20 usd0PP180 = IERC20(registryContract.getContract(CONTRACT_USD0PP));
        uint256 aliceBalanceBefore = usd0PP180.balanceOf(address(alice));
        vm.prank(alice);
        usd0PP180.approve(bob, aliceBalanceBefore);
        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        vm.prank(bob);
        usd0PP180.transferFrom(alice, bob, 0);
    }

    function testTransferFromShouldFailIfMoreThanAllow() public {
        testTransferFrom1(100e18);
        // get bond with symbol USD0PP A0
        IERC20 usd0PP180 = IERC20(registryContract.getContract(CONTRACT_USD0PP));

        uint256 aliceBalanceBefore = usd0PP180.balanceOf(address(alice));
        uint256 bobBalanceBefore = usd0PP180.balanceOf(address(bob));
        vm.prank(alice);
        usd0PP180.approve(bob, aliceBalanceBefore - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                bob,
                bobBalanceBefore - 1,
                bobBalanceBefore
            )
        );
        vm.prank(bob);
        usd0PP180.transferFrom(alice, bob, aliceBalanceBefore);
        uint256 aliceBalanceAfter = usd0PP180.balanceOf(address(alice));
        uint256 bobBalanceAfter = usd0PP180.balanceOf(address(bob));
        assertEq(aliceBalanceAfter, aliceBalanceBefore);
        assertEq(bobBalanceAfter, bobBalanceBefore);
    }

    function testTransferFromShouldFailIfMoreThanBalance() public {
        testTransferFrom1(100e18);
        // get bond with symbol USD0PP A0
        IERC20 usd0PP180 = IERC20(registryContract.getContract(CONTRACT_USD0PP));

        uint256 aliceBalanceBefore = usd0PP180.balanceOf(address(alice));
        uint256 bobBalanceBefore = usd0PP180.balanceOf(address(bob));
        vm.prank(alice);
        usd0PP180.approve(bob, type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                alice,
                aliceBalanceBefore,
                aliceBalanceBefore * 2
            )
        );
        vm.prank(bob);
        usd0PP180.transferFrom(alice, bob, aliceBalanceBefore * 2);
        uint256 aliceBalanceAfter = usd0PP180.balanceOf(address(alice));
        uint256 bobBalanceAfter = usd0PP180.balanceOf(address(bob));
        assertEq(aliceBalanceAfter, aliceBalanceBefore);
        assertEq(bobBalanceAfter, bobBalanceBefore);
    }

    function testMintUsd0PPShouldFailAfterEndDate() public {
        uint256 amount = 1e18;
        testTransferFrom1(amount);
        IUsd0PP usd0PP180 = IUsd0PP(registryContract.getContract(CONTRACT_USD0PP));
        uint256 aliceBalance = IERC20(address(usd0PP180)).balanceOf(address(alice));
        vm.prank(address(daoCollateral));
        stbcToken.mint(address(alice), amount);
        vm.startPrank(address(alice));
        //   end block
        skip(usd0PP180.getEndTime() + 1);
        vm.expectRevert(abi.encodeWithSelector(BondFinished.selector));
        usd0PP180.mint(amount * 100);
        assertEq(IERC20(address(usd0PP180)).balanceOf(address(alice)), aliceBalance);
        vm.stopPrank();
    }

    function testCreateUsd0PPShouldWork() public {
        Usd0PP bond = _createBond("UsualDAO Bond 121", "USD0PP lsUSD");

        assertEq(bond.name(), "UsualDAO Bond 121");
        assertEq(bond.symbol(), "USD0PP lsUSD");
        assertEq(bond.decimals(), 18);
        assertEq(bond.getStartTime(), block.timestamp);
        assertEq(bond.getEndTime(), block.timestamp + BOND_DURATION_FOUR_YEAR);
        assertEq(bond.totalBondTimes(), BOND_DURATION_FOUR_YEAR);
    }

    function testEmergencyWithdraw() public {
        uint256 amount = 100e18;
        testTransferFrom1(amount);
        Usd0PP usd0PP180 = Usd0PP(registryContract.getContract(CONTRACT_USD0PP));
        assertEq(stbcToken.balanceOf(bob), 0);
        uint256 bal = stbcToken.balanceOf(address(usd0PP180));
        assertGt(bal, 0);
        vm.prank(admin);
        usd0PP180.emergencyWithdraw(bob);
        assertEq(stbcToken.balanceOf(bob), bal);
    }

    function testEmergencyWithdrawFailIfNullAddress() public {
        uint256 amount = 100e18;
        testTransferFrom1(amount);
        Usd0PP usd0PP180 = Usd0PP(registryContract.getContract(CONTRACT_USD0PP));
        vm.expectRevert();
        vm.prank(admin);
        usd0PP180.emergencyWithdraw(address(0));
    }

    function testEmergencyWithdrawFailIfNotAuthorized() public {
        uint256 amount = 100e18;
        testTransferFrom1(amount);
        Usd0PP usd0PP180 = Usd0PP(registryContract.getContract(CONTRACT_USD0PP));
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0PP180.emergencyWithdraw(address(0));
    }

    function testCannotMintAfterEmergencyWithdraw() public {
        uint256 amount = 100e18;
        testTransferFrom1(amount);
        Usd0PP usd0PP180 = Usd0PP(registryContract.getContract(CONTRACT_USD0PP));
        assertEq(stbcToken.balanceOf(bob), 0);
        uint256 bal = stbcToken.balanceOf(address(usd0PP180));
        assertGt(bal, 0);
        vm.prank(admin);
        usd0PP180.emergencyWithdraw(bob);

        vm.prank(address(daoCollateral));
        stbcToken.mint(address(bob), amount);

        vm.startPrank(bob);
        stbcToken.approve(address(usd0PP180), amount * 2);
        vm.expectRevert();
        usd0PP180.mint(amount);
        vm.stopPrank();

        vm.prank(admin);
        usd0PP180.unpause();

        vm.prank(bob);
        usd0PP180.mint(amount);
        assertGt(IERC20(address(usd0PP180)).balanceOf(address(bob)), amount);
    }

    function testUnpause() public {
        Usd0PP usd0PP180 = Usd0PP(registryContract.getContract(CONTRACT_USD0PP));
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0PP180.pause();

        vm.prank(admin);
        usd0PP180.pause();

        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0PP180.unpause();

        vm.prank(admin);
        usd0PP180.unpause();
    }
}
