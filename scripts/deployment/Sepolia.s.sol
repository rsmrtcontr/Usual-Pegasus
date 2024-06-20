// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {RegistryAccess} from "src/registry/RegistryAccess.sol";
import {RegistryContract} from "src/registry/RegistryContract.sol";
import {Usd0} from "src/token/Usd0.sol";
import {Usd0PP} from "src/token/Usd0PP.sol";
import {DaoCollateral} from "src/daoCollateral/DaoCollateral.sol";
import {SwapperEngine} from "src/swapperEngine/SwapperEngine.sol";

import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {DAO_COLLATERAL, USD0_BURN, USD0_MINT} from "src/constants.sol";
import {
    USDC_PRICE_FEED_SEPOLIA,
    USDC_SEPOLIA,
    USYC_PRICE_FEED_SEPOLIA,
    USYC_SEPOLIA,
    REDEEM_FEE
} from "src/mock/constants.sol";

import {
    DEFAULT_ADMIN_ROLE,
    CONTRACT_USD0PP,
    CONTRACT_SWAPPER_ENGINE,
    CONTRACT_DAO_COLLATERAL,
    CONTRACT_TREASURY,
    CONTRACT_USD0
} from "src/constants.sol";

import {console} from "forge-std/console.sol";

// Alternative is to fetch them from the registry contract
address constant Usd0Proxy = 0x2d92cC95A7C3713f8FD359d5FaE2dFb00ec7377d;
address constant TokenMappingProxy = 0x556c1EAbbB6c9fB3b09e21fC3676740B8c744F0c;
address constant DaoCollateralProxy = 0xC25a3Cfbf0F250313E723b739311b728caD39dB0;
address constant RegistryAccessProxy = 0xA54eB68bc54106d0a9B647393bdfD3061aEE13E8;
address constant RegistryContractProxy = 0x23072949A2BB910ca0dDDF8D7e50fEe32AE8d079;
address constant ClassicalOracleProxy = 0xDB2898F49CeDa5c75714d82fC2aE142Cd8bc0374;
address constant TreasuryProxy = 0xAC98A51269F60b9660ad2A3f83d8aa77D7f39BA6;

// Administrator addresses
address constant usual = 0x91a8a1495291e8aBf5B7580F0044437d2709C5E0;
address constant usualProxyAdmin = 0x9acAF13C30a18E688692c5E5066fE5B23C5f9d69;

// solhint-disable-next-line no-console
contract P0 is Script {
    function run() public {
        // Check that the script is running on the correct chain
        if (block.chainid != 11_155_111) {
            console.log("Invalid chain");
            return;
        }
        //Options memory upgradeOptions;
        Usd0PP usd0PP;
        SwapperEngine swapperEngine;
        ProxyAdmin proxyAdmin;

        vm.startBroadcast();
        // Deploy USD0PP & Proxy
        usd0PP = Usd0PP(
            Upgrades.deployTransparentProxy(
                "Usd0PP.sol",
                usualProxyAdmin,
                abi.encodeCall(
                    Usd0PP.initialize,
                    (RegistryContractProxy, "USD0PP", "USD0++", block.timestamp + 60)
                )
            )
        );
        // Deploy SwapEngine & Proxy
        swapperEngine = SwapperEngine(
            Upgrades.deployTransparentProxy(
                "SwapperEngine.sol",
                usualProxyAdmin,
                abi.encodeCall(SwapperEngine.initialize, RegistryContractProxy)
            )
        );
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(address(usd0PP)));
        proxyAdmin.transferOwnership(usualProxyAdmin);
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(address(swapperEngine)));
        proxyAdmin.transferOwnership(usualProxyAdmin);
        vm.stopBroadcast();

        // Debug logs
        console.log("Usd0PP address:", address(usd0PP));
        console.log("SwapperEngine address:", address(swapperEngine));
    }
}
// solhint-disable-next-line no-console

contract P1 is Script {
    function run() public {
        // Check that the script is running on the correct chain
        if (block.chainid != 11_155_111) {
            console.log("Invalid chain");
            return;
        }
        //Options memory upgradeOptions;
        RegistryContract registryContract = RegistryContract(RegistryContractProxy);
        RegistryAccess registryAccess = RegistryAccess(RegistryAccessProxy);
        address usd0PP = 0xFEbCDe7f65Fcb00ed89951Cf293DAB8B45153cA3;
        address swapperEngine = 0x5bbD29C9B114c9503c09012Ca1Af8a9297953FbC;

        if (usd0PP == address(0)) {
            console.log("USD0PP not found");
            return;
        }
        if (swapperEngine == address(0)) {
            console.log("SwapperEngine not found");
            return;
        }
        vm.startBroadcast();
        // Register USD0PP with Registry
        registryContract.setContract(CONTRACT_USD0PP, address(usd0PP));
        // Register SwapEngine with Registry
        registryContract.setContract(CONTRACT_SWAPPER_ENGINE, address(swapperEngine));
        // Upgrade DaoCollateral Proxy

        //TODO
        //registryAccess.grantRole(ALLOWLISTED, address(SWAPPER_ENGINE_MATCHER_INTENT));
        vm.stopBroadcast();

        // Debug logs
        console.log("Usd0PP registered and allowed");
        console.log("SwapperEngine registered and allowed");
    }
}
// solhint-disable-next-line no-console

contract P2 is Script {
    function run() public {
        // Check that the script is running on the correct chain
        if (block.chainid != 11_155_111) {
            console.log("Invalid chain");
            return;
        }
        Options memory upgradeOptions;
        address daoCollateralV1;
        address usd0V1;

        vm.startBroadcast();
        // BELOW CODE IS COMMENTED OUT BECAUSE THE USAGE OF MULTISIG IS NOT SUPPORTED YET
        // Upgrade DaoCollateral Proxy
        //Upgrades.upgradeProxy(DaoCollateralProxy, "DaoCollateral.sol", abi.encodeCall(DaoCollateral.initializeV1, RegistryContractProxy));
        // Upgrade USD0 Proxy
        //Upgrades.upgradeProxy(Usd0Proxy, "Usd0.sol", "");
        daoCollateralV1 = Upgrades.deployImplementation("DaoCollateral.sol", upgradeOptions);
        usd0V1 = Upgrades.deployImplementation("Usd0.sol", upgradeOptions);
        ProxyAdmin proxyAdmin;
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(Usd0Proxy));
        console.log("USD0 ProxyAdmin", address(proxyAdmin), proxyAdmin.owner());
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(DaoCollateralProxy));
        console.log("DaoCollateral ProxyAdmin", address(proxyAdmin), proxyAdmin.owner());

        //Upgrades.upgradeProxy(address(0xC3eC3cAd812CD6F764fd9dfA9D8d64C8922451a2), "DaoCollateral.sol", abi.encodeCall(DaoCollateral.initializeV1, RegistryContractProxy));
        vm.stopBroadcast();
        // Display logs
        console.log("DaoCollateral V1 implementation address:", daoCollateralV1);
        console.log("USD0 V1 implementation address:", usd0V1);
        console.log(
            "Please run the upgrade function to upgrade the contracts, using the gnosis safe multisig"
        );
    }
}
