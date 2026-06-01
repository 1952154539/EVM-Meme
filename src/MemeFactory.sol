// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MemeToken} from "./MemeToken.sol";

/// @title MemeFactory - ERC-1167 minimal proxy factory for fair-launch Meme tokens
/// @notice Deploys ERC20 Meme tokens via minimal proxy to save gas.
///         Fee split: 1% to project owner, remainder to Meme issuer.
contract MemeFactory is Ownable {
    using Clones for address;

    /// @notice The canonical MemeToken implementation, deployed once and cloned per Meme
    MemeToken public immutable implementation;

    event MemeDeployed(
        address indexed tokenAddr,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price,
        address indexed issuer
    );

    event MemeMinted(
        address indexed tokenAddr,
        address indexed buyer,
        uint256 amount,
        uint256 totalCost,
        uint256 projectFee,
        uint256 issuerRevenue
    );

    constructor() Ownable(msg.sender) {
        implementation = new MemeToken();
    }

    /// @notice Deploy a new Meme ERC20 token via minimal proxy
    /// @param _symbol      Token symbol (name is auto-generated as "Meme <symbol>")
    /// @param _totalSupply Maximum token supply
    /// @param _perMint     Tokens minted per purchase
    /// @param _price       Price per token in wei
    /// @return tokenAddr   Address of the deployed proxy
    function deployMeme(string calldata _symbol, uint256 _totalSupply, uint256 _perMint, uint256 _price)
        external
        returns (address tokenAddr)
    {
        require(_totalSupply > 0, "Total supply must be > 0");
        require(_perMint > 0 && _perMint <= _totalSupply, "Invalid perMint");

        // ERC-1167 minimal proxy: ~55 bytes deployed instead of full contract
        tokenAddr = address(implementation).clone();
        MemeToken(tokenAddr).initialize(_symbol, _totalSupply, _perMint, _price, msg.sender, address(this));

        emit MemeDeployed(tokenAddr, _symbol, _totalSupply, _perMint, _price, msg.sender);
    }

    /// @notice Mint Meme tokens by paying ETH
    /// @param tokenAddr The Meme token proxy address
    function mintMeme(address tokenAddr) external payable {
        MemeToken token = MemeToken(tokenAddr);
        uint256 cost = token.perMint() * token.price();
        require(msg.value >= cost, "Insufficient payment");

        uint256 projectFee = cost / 100; // 1% 归项目方
        uint256 issuerRevenue = cost - projectFee;

        // 铸造 token 给买家
        token.mint(msg.sender);

        // 分配费用
        if (projectFee > 0) {
            (bool ok,) = owner().call{value: projectFee}("");
            require(ok, "Project fee transfer failed");
        }
        if (issuerRevenue > 0) {
            (bool ok,) = token.issuer().call{value: issuerRevenue}("");
            require(ok, "Issuer revenue transfer failed");
        }

        // 退还超额支付
        uint256 refund = msg.value - cost;
        if (refund > 0) {
            (bool ok,) = msg.sender.call{value: refund}("");
            require(ok, "Refund failed");
        }

        emit MemeMinted(tokenAddr, msg.sender, token.perMint(), cost, projectFee, issuerRevenue);
    }
}
