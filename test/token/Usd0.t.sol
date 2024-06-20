// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {SetupTest} from "test/setup.t.sol";
import {USD0_MINT, USD0_BURN, CONTRACT_DAO_COLLATERAL} from "src/constants.sol";
import {USD0Name, USD0Symbol} from "src/mock/constants.sol";
import {NotAuthorized, Blacklisted, SameValue} from "src/errors.sol";
import {Usd0} from "src/token/Usd0.sol";
import {IERC20Errors} from "openzeppelin-contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "openzeppelin-contracts/utils/Pausable.sol";

// @title: USD0 test contract
// @notice: Contract to test USD0 token implementation

contract Usd0Test is SetupTest {
    Usd0 public usd0Token;

    event Blacklist(address account);
    event UnBlacklist(address account);

    function setUp() public virtual override {
        super.setUp();
        usd0Token = stbcToken;
    }

    function testName() external view {
        assertEq(USD0Name, usd0Token.name());
    }

    function testSymbol() external view {
        assertEq(USD0Symbol, usd0Token.symbol());
    }

    function allowlistAliceAndMintTokens() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        usd0Token.mint(alice, 2e18);
        assertEq(usd0Token.totalSupply(), usd0Token.balanceOf(alice));
    }

    function testInitializeShouldFailWithNullAddress() public {
        _resetInitializerImplementation(address(usd0Token));
        vm.expectRevert(abi.encodeWithSelector(NullContract.selector));
        usd0Token.initialize(address(0), "USD0", "USD0");
    }

    function testMintShouldNotFailIfNotAllowlisted() public {
        address minter = address(registryContract.getContract(CONTRACT_DAO_COLLATERAL));
        vm.prank(minter);
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, alice));
        usd0Token.mint(alice, 2e18);
    }

    // Additional test functions for the Usd0Test contract

    function testUnauthorizedAccessToMintAndBurn() public {
        // Attempt to mint by a non-authorized address
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0Token.mint(alice, 1e18);

        // Attempt to burn by a non-authorized address
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        usd0Token.mint(alice, 10e18); // Mint some tokens for Alice
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0Token.burnFrom(alice, 5e18);
    }

    function testRoleChangesAffectingMintAndBurn() public {
        // Grant and revoke roles dynamically and test access control
        vm.startPrank(admin);

        registryAccess.grantRole(USD0_MINT, carol);
        vm.stopPrank();
        vm.prank(carol);
        usd0Token.mint(alice, 1e18); // Should succeed now that Carol can mint

        vm.prank(admin);
        registryAccess.revokeRole(USD0_MINT, carol);
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0Token.mint(alice, 1e18); // Should fail now that Carol's mint role is revoked
    }

    function testMintNullAddress() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0))
        );
        usd0Token.mint(address(0), 2e18);
    }

    function testMintAmountZero() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        vm.expectRevert(AmountIsZero.selector);
        usd0Token.mint(alice, 0);
    }

    function testBurnFromDoesNotFailIfNotAuthorized() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        usd0Token.mint(alice, 10e18);
        assertEq(usd0Token.balanceOf(alice), 10e18);
        vm.prank(admin);

        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, alice));
        usd0Token.burnFrom(alice, 8e18);

        assertEq(usd0Token.totalSupply(), 2e18);
        assertEq(usd0Token.balanceOf(alice), 2e18);
    }

    function testBurnFrom() public {
        vm.startPrank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        usd0Token.mint(alice, 10e18);
        assertEq(usd0Token.balanceOf(alice), 10e18);

        usd0Token.burnFrom(alice, 8e18);

        assertEq(usd0Token.totalSupply(), 2e18);
        assertEq(usd0Token.balanceOf(alice), 2e18);
    }

    function testBurnFromFail() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        usd0Token.mint(alice, 10e18);
        assertEq(usd0Token.balanceOf(alice), 10e18);

        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0Token.burnFrom(alice, 8e18);

        assertEq(usd0Token.totalSupply(), 10e18);
        assertEq(usd0Token.balanceOf(alice), 10e18);
    }

    function testBurn() public {
        vm.startPrank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        usd0Token.mint(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)), 10e18);

        usd0Token.burn(8e18);

        assertEq(
            usd0Token.balanceOf(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL))),
            2e18
        );
    }

    function testBurnFail() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        usd0Token.mint(alice, 10e18);
        assertEq(usd0Token.balanceOf(alice), 10e18);

        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0Token.burn(8e18);

        assertEq(usd0Token.totalSupply(), 10e18);
        assertEq(usd0Token.balanceOf(alice), 10e18);
    }

    function testApprove() public {
        assertTrue(usd0Token.approve(alice, 1e18));
        assertEq(usd0Token.allowance(address(this), alice), 1e18);
    }

    function testTransfer() external {
        allowlistAliceAndMintTokens();
        vm.startPrank(alice);
        usd0Token.transfer(bob, 0.5e18);
        assertEq(usd0Token.balanceOf(bob), 0.5e18);
        assertEq(usd0Token.balanceOf(alice), 1.5e18);
        vm.stopPrank();
    }

    function testTransferAllowlistDisabledSender() public {
        allowlistAliceAndMintTokens(); // Mint to Alice who is allowlisted
        vm.prank(alice);
        usd0Token.transfer(bob, 0.5e18); // This should succeed because alice is allowlisted
        assertEq(usd0Token.balanceOf(bob), 0.5e18);
        assertEq(usd0Token.balanceOf(alice), 1.5e18);

        // Bob tries to transfer to Carol but is not allowlisted
        vm.startPrank(bob);
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, carol));
        usd0Token.transfer(carol, 0.3e18);
        vm.stopPrank();
    }

    function testTransferAllowlistDisabledRecipient() public {
        allowlistAliceAndMintTokens(); // Mint to Alice who is allowlisted
        vm.startPrank(alice);
        usd0Token.transfer(bob, 0.5e18); // This should succeed because both are allowlisted
        assertEq(usd0Token.balanceOf(bob), 0.5e18);
        assertEq(usd0Token.balanceOf(alice), 1.5e18);

        // Alice tries to transfer to Carol who is not allowlisted
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, carol));
        usd0Token.transfer(carol, 0.3e18);
        vm.stopPrank();
    }

    function testTransferFrom() external {
        allowlistAliceAndMintTokens();
        vm.prank(alice);
        usd0Token.approve(address(this), 1e18);
        assertTrue(usd0Token.transferFrom(alice, bob, 0.7e18));
        assertEq(usd0Token.allowance(alice, address(this)), 1e18 - 0.7e18);
        assertEq(usd0Token.balanceOf(alice), 2e18 - 0.7e18);
        assertEq(usd0Token.balanceOf(bob), 0.7e18);
    }

    function testTransferFromAllowlistDisabled() public {
        allowlistAliceAndMintTokens(); // Mint to Alice who is allowlisted

        vm.prank(alice);
        usd0Token.approve(bob, 2e18); // Alice approves Bob to manage 2 tokens
        // Bob attempts to transfer from Alice to himself
        vm.prank(bob);
        usd0Token.transferFrom(alice, bob, 1e18); // This should succeed because both are allowlisted
        assertEq(usd0Token.balanceOf(bob), 1e18);
        assertEq(usd0Token.balanceOf(alice), 1e18);

        // Bob tries to transfer from Alice again, which is not allowlisted anymore
        vm.prank(bob);
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, alice));
        usd0Token.transferFrom(alice, bob, 0.5e18);
        vm.stopPrank();
    }

    function testTransferFromWorksAllowlistDisabledRecipient() public {
        allowlistAliceAndMintTokens();

        vm.prank(alice);
        usd0Token.approve(bob, 2e18); // Alice approves Bob to manage 2 tokens
        vm.startPrank(bob);
        usd0Token.approve(bob, 2e18);
        // Bob attempts to transfer from Alice to himself, then to Carol
        usd0Token.transferFrom(alice, bob, 1e18); // This should succeed because both are allowlisted
        assertEq(usd0Token.balanceOf(bob), 1e18);
        assertEq(usd0Token.balanceOf(alice), 1e18);

        //  Bob is allowlisted, but he tries to transfer from himself to Carol, who is not allowlisted
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, carol));
        usd0Token.transferFrom(bob, carol, 0.5e18);
        vm.stopPrank();
    }

    function testPauseUnPause() external {
        allowlistAliceAndMintTokens();

        vm.prank(admin);
        usd0Token.pause();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        usd0Token.transfer(bob, 1e18);
        vm.prank(admin);
        usd0Token.unpause();
        vm.prank(alice);
        usd0Token.transfer(bob, 1e18);
    }

    function testPauseUnPauseShouldFailWhenNotAuthorized() external {
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0Token.pause();
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0Token.unpause();
    }

    function testBlacklistUser() external {
        allowlistAliceAndMintTokens();
        vm.startPrank(admin);

        usd0Token.blacklist(alice);
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        usd0Token.blacklist(alice);
        vm.stopPrank();

        vm.assertTrue(usd0Token.isBlacklisted(alice));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Blacklisted.selector));
        usd0Token.transfer(bob, 1e18);

        vm.startPrank(admin);
        usd0Token.unBlacklist(alice);
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        usd0Token.unBlacklist(alice);
        vm.stopPrank();

        vm.prank(alice);
        usd0Token.transfer(bob, 1e18);
    }

    function testBlacklistShouldRevertIfAddressIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(NullAddress.selector));
        usd0Token.blacklist(address(0));
    }

    function testBlacklistAndUnBlacklistEmitsEvents() external {
        allowlistAliceAndMintTokens();
        vm.startPrank(admin);
        vm.expectEmit();
        emit Blacklist(alice);
        usd0Token.blacklist(alice);

        vm.expectEmit();
        emit UnBlacklist(alice);
        usd0Token.unBlacklist(alice);
    }

    function testOnlyAdminCanUseBlacklist(address user) external {
        vm.assume(user != admin);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0Token.blacklist(alice);

        vm.prank(admin);
        usd0Token.blacklist(alice);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        usd0Token.unBlacklist(alice);
    }
}
