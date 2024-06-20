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
import {REDEEM_FEE, USDPPName, USDPPSymbol} from "src/mock/constants.sol";

import {
    DEFAULT_ADMIN_ROLE,
    CONTRACT_USD0PP,
    CONTRACT_SWAPPER_ENGINE,
    CONTRACT_DAO_COLLATERAL,
    CONTRACT_TREASURY,
    BOND_START_DATE,
    CONTRACT_USD0,
    CONTRACT_REGISTRY_ACCESS,
    CONTRACT_TOKEN_MAPPING,
    CONTRACT_ORACLE
} from "src/constants.sol";

import {console} from "forge-std/console.sol";

// Alternative is to fetch them from the registry contract
address constant Usd0Proxy = 0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5;
address constant DaoCollateralProxy = 0xde6e1F680C4816446C8D515989E2358636A38b04;
address constant RegistryAccessProxy = 0x0D374775E962c3608B8F0A4b8B10567DF739bb56;
address constant RegistryContractProxy = 0x0594cb5ca47eFE1Ff25C7B8B43E221683B4Db34c;

// Administrator addresses
address constant usual = 0x6e9d65eC80D69b1f508560Bc7aeA5003db1f7FB7;
address constant usualProxyAdmin = 0xaaDa24358620d4638a2eE8788244c6F4b197Ca16;

// solhint-disable-next-line no-console
contract P1 is Script {
    function run() public {
        // Check that the script is running on the correct chain
        if (block.chainid != 1) {
            console.log("Invalid chain");
            return;
        }
        //Options memory upgradeOptions;
        Usd0PP usd0PP;
        SwapperEngine swapperEngine;

        vm.startBroadcast();
        // Deploy USD0PP & Proxy

        usd0PP = Usd0PP(
            Upgrades.deployTransparentProxy(
                "Usd0PP.sol",
                usualProxyAdmin,
                abi.encodeCall(
                    Usd0PP.initialize,
                    (RegistryContractProxy, USDPPName, USDPPSymbol, BOND_START_DATE)
                )
            )
        );
        vm.stopBroadcast();
        vm.startBroadcast();
        // Deploy SwapEngine & Proxy
        swapperEngine = SwapperEngine(
            Upgrades.deployTransparentProxy(
                "SwapperEngine.sol",
                usualProxyAdmin,
                abi.encodeCall(SwapperEngine.initialize, RegistryContractProxy)
            )
        );
        vm.stopBroadcast();

        // Debug logs
        console.log("Usd0PP address:", address(usd0PP));
        console.log("SwapperEngine address:", address(swapperEngine));
    }
}
/*
// solhint-disable-next-line no-console
contract P2 is Script {
    function run() public {
        // Check that the script is running on the correct chain
        if (block.chainid != 1) {
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

        // TODO
        //registryAccess.grantRole(ALLOWLISTED, address(SWAPPER_ENGINE_MATCHER_INTENT));
        vm.stopBroadcast();

        // Debug logs
        console.log("Usd0PP registered and allowed");
        console.log("SwapperEngine registered and allowed");
    }
}
*/
// solhint-disable-next-line no-console

contract P3 is Script {
    function run() public {
        // Check that the script is running on the correct chain
        if (block.chainid != 1) {
            console.log("Invalid chain");
            return;
        }
        Options memory upgradeOptions;
        address daoCollateralV1;
        address usd0V1;

        vm.startBroadcast();
        daoCollateralV1 = Upgrades.deployImplementation("DaoCollateral.sol", upgradeOptions);
        usd0V1 = Upgrades.deployImplementation("Usd0.sol", upgradeOptions);

        vm.stopBroadcast();
        ProxyAdmin proxyAdmin;
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(Usd0Proxy));
        console.log("USD0 Proxy", address(Usd0Proxy));
        console.log("USD0 ProxyAdmin", address(proxyAdmin), proxyAdmin.owner());
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(DaoCollateralProxy));
        console.log("DaoCollateral Proxy", DaoCollateralProxy);
        console.log("DaoCollateral ProxyAdmin", address(proxyAdmin), proxyAdmin.owner());

        // Display logs
        console.log("USD0 V1 implementation address:", usd0V1);
        console.log("DaoCollateral V1 implementation address:", daoCollateralV1);
        console.log(
            "Please run the upgrade function to upgrade the contracts, using the gnosis safe multisig"
        );
        console.log(
            "Parameters for DaoCollateral upgrade in Chisel: import {DaoCollateral} from \"src/daoCollateral/DaoCollateral.sol\";\nabi.encodeCall(DaoCollateral.initializeV1, 0x0594cb5ca47eFE1Ff25C7B8B43E221683B4Db34c)"
        );
    }
}

// solhint-disable-next-line no-console
contract MainnetDisplayProxyAdminAddresses is Script {
    /// @dev This function needs to be modified for every patch deployment
    function run() public view {
        // Check that the script is running on the correct chain
        if (block.chainid != 1) {
            console.log("Invalid chain");
            return;
        }
        RegistryContract registryContract = RegistryContract(RegistryContractProxy);
        address usd0 = registryContract.getContract(CONTRACT_USD0);
        address registryAccess = registryContract.getContract(CONTRACT_REGISTRY_ACCESS);
        address tokenMapping = registryContract.getContract(CONTRACT_TOKEN_MAPPING);
        address daoCollateral = registryContract.getContract(CONTRACT_DAO_COLLATERAL);
        address classicalOracle = registryContract.getContract(CONTRACT_ORACLE);

        ProxyAdmin proxyAdmin;
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(usd0));
        console.log("USD0 ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(registryAccess));
        console.log("RegistryAccess ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(address(registryContract)));
        console.log(
            "RegistryContract ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner()
        );
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(tokenMapping));
        console.log("TokenMapping ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(daoCollateral));
        console.log("DaoCollateral ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(classicalOracle));
        console.log("ClassicalOracle ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());
    }
}
