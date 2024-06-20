// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

bytes32 constant STBC_FACTORY = keccak256("STBC_FACTORY");
bytes32 constant ORACLE_UPDATER = keccak256("ORACLE_UPDATER");

bytes32 constant CONTRACT_RWA_FACTORY = keccak256("CONTRACT_RWA_FACTORY");

uint256 constant REDEEM_FEE = 10;

/* Third-party tokens */
address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant USYC = 0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b;

address constant USDC_SEPOLIA = 0xAc8EC9BAE3EFBE8f792e2D93C1E92c046a6C31AD;
address constant USYC_SEPOLIA = 0xc12Bc39224b6F5ED65Be35b5D8A92AefAD3F418d;

address constant USDC_PRICE_FEED_MAINNET = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
address constant USDT_PRICE_FEED_MAINNET = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
address constant USYC_PRICE_FEED_MAINNET = 0x4c48bcb2160F8e0aDbf9D4F3B034f1e36d1f8b3e;
address constant USDC_PRICE_FEED_SEPOLIA = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
address constant USYC_PRICE_FEED_SEPOLIA = 0x35b96d80C72f873bACc44A1fACfb1f5fac064f1a;

/* Names */

string constant USD0Symbol = "USD0";
string constant USD0Name = "Usual USD";

string constant USDPPSymbol = "USD0++";
string constant USDPPName = "USD0 Liquid Bond";

bytes32 constant REGISTRY_SALT = keccak256("Usual Protocol Registry");
// https://github.com/Arachnid/deterministic-deployment-proxy
address constant DETERMINISTIC_DEPLOYMENT_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
