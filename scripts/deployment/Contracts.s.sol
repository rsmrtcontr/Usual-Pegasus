// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {DataPublisher} from "src/mock/dataPublisher.sol";
import {UsualOracle} from "src/oracles/UsualOracle.sol";
import {RegistryAccess} from "src/registry/RegistryAccess.sol";
import {RegistryContract} from "src/registry/RegistryContract.sol";
import {TokenMapping} from "src/TokenMapping.sol";
import {Usd0} from "src/token/Usd0.sol";

import {Usd0PP} from "src/token/Usd0PP.sol";
import {DaoCollateral} from "src/daoCollateral/DaoCollateral.sol";
import {RwaFactoryMock} from "src/mock/rwaFactoryMock.sol";

import {SwapperEngine} from "src/swapperEngine/SwapperEngine.sol";

import {ClassicalOracle} from "src/oracles/ClassicalOracle.sol";

import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {
    CONTRACT_DAO_COLLATERAL,
    CONTRACT_DATA_PUBLISHER,
    CONTRACT_SWAPPER_ENGINE,
    CONTRACT_ORACLE,
    CONTRACT_ORACLE_USUAL,
    CONTRACT_REGISTRY_ACCESS,
    CONTRACT_TOKEN_MAPPING,
    CONTRACT_TREASURY,
    CONTRACT_USD0PP,
    CONTRACT_USD0,
    CONTRACT_USDC
} from "src/constants.sol";
import {
    USD0Name,
    USD0Symbol,
    REGISTRY_SALT,
    DETERMINISTIC_DEPLOYMENT_PROXY,
    REDEEM_FEE,
    CONTRACT_RWA_FACTORY
} from "src/mock/constants.sol";
import {BaseScript} from "scripts/deployment/Base.s.sol";

contract ContractScript is BaseScript {
    TokenMapping public tokenMapping;

    DaoCollateral public daoCollateral;
    RwaFactoryMock public rwaFactoryMock;
    Usd0PP public usd0PP;
    SwapperEngine public swapperEngine;
    DataPublisher public dataPublisher;
    UsualOracle public usualOracle;
    ClassicalOracle public classicalOracle;

    function _computeAddress(bytes32 salt, bytes memory _code, address _usual)
        internal
        pure
        returns (address addr)
    {
        bytes memory bytecode = abi.encodePacked(_code, abi.encode(_usual));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), DETERMINISTIC_DEPLOYMENT_PROXY, salt, keccak256(bytecode)
            )
        );
        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    function run() public virtual override {
        super.run();
        Options memory upgradeOptions;
        vm.startBroadcast(deployerPrivateKey);
        address computedRegAccessAddress =
            _computeAddress(REGISTRY_SALT, type(RegistryAccess).creationCode, usual);
        registryAccess = IRegistryAccess(computedRegAccessAddress);
        // RegistryAccess
        if (computedRegAccessAddress.code.length == 0) {
            upgradeOptions.defender.salt = REGISTRY_SALT;
            registryAccess = IRegistryAccess(
                Upgrades.deployTransparentProxy(
                    "RegistryAccess.sol",
                    usualProxyAdmin,
                    abi.encodeCall(RegistryAccess.initialize, (address(usual))),
                    upgradeOptions
                )
            );
        }
        address computedRegContractAddress = _computeAddress(
            REGISTRY_SALT, type(RegistryContract).creationCode, address(registryAccess)
        );
        registryContract = RegistryContract(computedRegContractAddress);
        // RegistryContract
        if (computedRegContractAddress.code.length == 0) {
            upgradeOptions.defender.salt = REGISTRY_SALT;
            registryContract = IRegistryContract(
                Upgrades.deployTransparentProxy(
                    "RegistryContract.sol",
                    usualProxyAdmin,
                    abi.encodeCall(RegistryContract.initialize, (address(registryAccess))),
                    upgradeOptions
                )
            );
        }
        vm.stopBroadcast();
        vm.startBroadcast(usualPrivateKey);
        registryContract.setContract(CONTRACT_REGISTRY_ACCESS, address(registryAccess));
        vm.stopBroadcast();

        vm.startBroadcast(usualPrivateKey);
        // Usd0
        USD0 = Usd0(
            Upgrades.deployTransparentProxy(
                "Usd0.sol",
                usualProxyAdmin,
                abi.encodeCall(Usd0.initialize, (address(registryContract), USD0Name, USD0Symbol))
            )
        );
        registryContract.setContract(CONTRACT_USD0, address(USD0));

        // TokenMapping
        tokenMapping = TokenMapping(
            Upgrades.deployTransparentProxy(
                "TokenMapping.sol",
                usualProxyAdmin,
                abi.encodeCall(
                    TokenMapping.initialize, (address(registryAccess), address(registryContract))
                )
            )
        );
        registryContract.setContract(CONTRACT_TOKEN_MAPPING, address(tokenMapping));

        // BucketDistribution
        registryContract.setContract(CONTRACT_TREASURY, treasury);

        // Oracle
        dataPublisher = new DataPublisher(address(registryContract));
        registryContract.setContract(CONTRACT_DATA_PUBLISHER, address(dataPublisher));

        usualOracle = UsualOracle(
            Upgrades.deployTransparentProxy(
                "UsualOracle.sol",
                usualProxyAdmin,
                abi.encodeCall(UsualOracle.initialize, address(registryContract))
            )
        );
        registryContract.setContract(CONTRACT_ORACLE_USUAL, address(usualOracle));

        classicalOracle = ClassicalOracle(
            Upgrades.deployTransparentProxy(
                "ClassicalOracle.sol",
                usualProxyAdmin,
                abi.encodeCall(ClassicalOracle.initialize, address(registryContract))
            )
        );
        registryContract.setContract(CONTRACT_ORACLE, address(classicalOracle));

        // USDC

        registryContract.setContract(CONTRACT_USDC, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        // Swapper Engine

        swapperEngine = SwapperEngine(
            Upgrades.deployTransparentProxy(
                "SwapperEngine.sol",
                usualProxyAdmin,
                abi.encodeCall(SwapperEngine.initialize, (address(registryContract)))
            )
        );
        registryContract.setContract(CONTRACT_SWAPPER_ENGINE, address(swapperEngine));

        // DAOCollateral
        daoCollateral = DaoCollateral(
            Upgrades.deployTransparentProxy(
                "DaoCollateral.sol",
                usualProxyAdmin,
                abi.encodeCall(DaoCollateral.initialize, (address(registryContract), REDEEM_FEE))
            )
        );
        registryContract.setContract(CONTRACT_DAO_COLLATERAL, address(daoCollateral));

        // RwaFactoryMock
        rwaFactoryMock = new RwaFactoryMock(address(registryContract));
        registryContract.setContract(CONTRACT_RWA_FACTORY, address(rwaFactoryMock));

        // USD0PP
        usd0PP = Usd0PP(
            Upgrades.deployTransparentProxy(
                "Usd0PP.sol",
                usualProxyAdmin,
                abi.encodeCall(
                    Usd0PP.initialize,
                    (address(registryContract), "Bond", "BND", block.timestamp + 1 days)
                )
            )
        );
        registryContract.setContract(CONTRACT_USD0PP, address(usd0PP));

        vm.stopBroadcast();
    }
}
