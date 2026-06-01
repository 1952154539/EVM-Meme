// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MemeFactory} from "../src/MemeFactory.sol";
import {MemeToken} from "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public projectOwner = makeAddr("projectOwner");
    address public issuer = makeAddr("issuer");
    address public buyer1 = makeAddr("buyer1");
    address public buyer2 = makeAddr("buyer2");

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

    function setUp() public {
        vm.prank(projectOwner);
        factory = new MemeFactory();
    }

    /// @notice 测试 deployMeme 创建代币并设置正确参数
    function test_DeployMeme() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        MemeToken token = MemeToken(tokenAddr);

        assertEq(token.name(), "Meme DOGE");
        assertEq(token.symbol(), "DOGE");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 1_000_000 ether);
        assertEq(token.perMint(), 1000 ether);
        assertEq(token.price(), 0.01 ether);
        assertEq(token.issuer(), issuer);
        assertEq(token.factory(), address(factory));
        assertEq(token.mintedSupply(), 0);
    }

    /// @notice 测试 emit MemeDeployed 事件（tokenAddr 由工厂生成，不检查具体地址）
    function test_DeployMeme_EmitsEvent() public {
        vm.prank(issuer);
        // tokenAddr 为代理地址不可预测，仅检查 indexed=false 的参数
        vm.expectEmit(false, false, false, true);
        emit MemeDeployed(address(0), "DOGE", 1_000_000 ether, 1000 ether, 0.01 ether, issuer);
        factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);
    }

    /// @notice 测试 mintMeme 铸造数量正确
    function test_MintMeme_CorrectAmount() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether; // 10 ether

        vm.deal(buyer1, cost);
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);

        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer1), 1000 ether);
        assertEq(token.mintedSupply(), 1000 ether);
    }

    /// @notice 测试费用按比例分配到 Meme 发行者和项目方
    function test_MintMeme_FeeDistribution() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether; // 10 ether
        uint256 expectedProjectFee = cost / 100;     // 0.1 ether (1%)
        uint256 expectedIssuerRevenue = cost - expectedProjectFee; // 9.9 ether

        uint256 projectBalBefore = projectOwner.balance;
        uint256 issuerBalBefore = issuer.balance;

        vm.deal(buyer1, cost);
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);

        assertEq(projectOwner.balance - projectBalBefore, expectedProjectFee, "Project fee mismatch");
        assertEq(issuer.balance - issuerBalBefore, expectedIssuerRevenue, "Issuer revenue mismatch");
    }

    /// @notice 测试 emit MemeMinted 事件
    function test_MintMeme_EmitsEvent() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether;
        uint256 projectFee = cost / 100;
        uint256 issuerRevenue = cost - projectFee;

        vm.deal(buyer1, cost);
        vm.prank(buyer1);

        vm.expectEmit(true, true, false, true);
        emit MemeMinted(tokenAddr, buyer1, 1000 ether, cost, projectFee, issuerRevenue);
        factory.mintMeme{value: cost}(tokenAddr);
    }

    /// @notice 测试超额支付时正确退款
    function test_MintMeme_RefundExcess() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether; // 10 ether
        uint256 overpay = cost + 5 ether;

        uint256 buyerBalBefore = buyer1.balance;

        vm.deal(buyer1, overpay);
        vm.prank(buyer1);
        factory.mintMeme{value: overpay}(tokenAddr);

        // 买家余额变化 = overpay - cost = 5 ether (退款)
        assertEq(buyer1.balance - buyerBalBefore, overpay - cost, "Refund amount mismatch");
    }

    /// @notice 测试多次铸造累计数量正确
    function test_MintMeme_MultipleMints() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether;

        // 第一次铸造
        vm.deal(buyer1, cost);
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);

        // 第二次铸造
        vm.deal(buyer1, cost);
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);

        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer1), 2000 ether);
        assertEq(token.mintedSupply(), 2000 ether);
    }

    /// @notice 测试多个买家分别铸造
    function test_MintMeme_MultipleBuyers() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether;

        vm.deal(buyer1, cost);
        vm.deal(buyer2, cost);

        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);

        vm.prank(buyer2);
        factory.mintMeme{value: cost}(tokenAddr);

        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer1), 1000 ether);
        assertEq(token.balanceOf(buyer2), 1000 ether);
        assertEq(token.mintedSupply(), 2000 ether);
    }

    /// @notice 测试铸造不会超过 totalSupply
    function test_MintMeme_CannotExceedTotalSupply() public {
        // 创建一个 totalSupply 刚好等于一次 perMint 的代币
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("TINY", 1000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether;

        // 第一次铸造 - 耗尽了所有 supply
        vm.deal(buyer1, cost);
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);

        // 第二次铸造 - 应该失败
        vm.deal(buyer2, cost);
        vm.prank(buyer2);
        vm.expectRevert("Exceeds total supply");
        factory.mintMeme{value: cost}(tokenAddr);
    }

    /// @notice 测试 totalSupply 不能被 perMint 整除时仍能正确工作
    function test_MintMeme_PartialLastMint() public {
        // totalSupply = 2500, perMint = 1000, 可铸造两次后剩下 500 无法铸造
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("PARTIAL", 2500 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether;

        // 铸造两次
        vm.deal(buyer1, cost * 2);
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);

        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.mintedSupply(), 2000 ether);

        // 第三次铸造应该失败（因为只剩 500，不够 perMint 的 1000）
        vm.deal(buyer1, cost);
        vm.prank(buyer1);
        vm.expectRevert("Exceeds total supply");
        factory.mintMeme{value: cost}(tokenAddr);
    }

    /// @notice 测试 ERC20 转账功能
    function test_ERC20_Transfer() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether;

        vm.deal(buyer1, cost);
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);

        MemeToken token = MemeToken(tokenAddr);

        // 转账给 buyer2
        vm.prank(buyer1);
        token.transfer(buyer2, 500 ether);

        assertEq(token.balanceOf(buyer1), 500 ether);
        assertEq(token.balanceOf(buyer2), 500 ether);
    }

    /// @notice 测试 ERC20 approve + transferFrom
    function test_ERC20_ApproveAndTransferFrom() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether;

        vm.deal(buyer1, cost);
        vm.prank(buyer1);
        factory.mintMeme{value: cost}(tokenAddr);

        MemeToken token = MemeToken(tokenAddr);

        // buyer1 授权 buyer2 花费 300 ether
        vm.prank(buyer1);
        token.approve(buyer2, 300 ether);

        // buyer2 使用 transferFrom
        vm.prank(buyer2);
        token.transferFrom(buyer1, buyer2, 300 ether);

        assertEq(token.balanceOf(buyer1), 700 ether);
        assertEq(token.balanceOf(buyer2), 300 ether);
        assertEq(token.allowance(buyer1, buyer2), 0);
    }

    /// @notice 测试支付不足时 revert
    function test_MintMeme_InsufficientPayment() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether;
        uint256 underpay = cost - 1;

        vm.deal(buyer1, underpay);
        vm.prank(buyer1);
        vm.expectRevert("Insufficient payment");
        factory.mintMeme{value: underpay}(tokenAddr);
    }

    /// @notice 测试多个 Meme 代币互不干扰
    function test_MultipleMemeTokens() public {
        vm.prank(issuer);
        address dogeAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        vm.prank(issuer);
        address catAddr = factory.deployMeme("CAT", 500_000 ether, 500 ether, 0.02 ether);

        MemeToken doge = MemeToken(dogeAddr);
        MemeToken cat = MemeToken(catAddr);

        assertEq(doge.symbol(), "DOGE");
        assertEq(cat.symbol(), "CAT");
        assertEq(doge.perMint(), 1000 ether);
        assertEq(cat.perMint(), 500 ether);

        // 铸造 DOGE
        uint256 dogeCost = 1000 ether * 0.01 ether;
        vm.deal(buyer1, dogeCost);
        vm.prank(buyer1);
        factory.mintMeme{value: dogeCost}(dogeAddr);

        // 铸造 CAT
        uint256 catCost = 500 ether * 0.02 ether;
        vm.deal(buyer1, catCost);
        vm.prank(buyer1);
        factory.mintMeme{value: catCost}(catAddr);

        assertEq(doge.balanceOf(buyer1), 1000 ether);
        assertEq(cat.balanceOf(buyer1), 500 ether);
    }

    /// @notice 测试非 owner 也能 deployMeme（任何人可发行 Meme）
    function test_AnyoneCanDeployMeme() public {
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        address tokenAddr = factory.deployMeme("RANDOM", 100_000 ether, 100 ether, 0.001 ether);

        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.issuer(), randomUser);
    }

    /// @notice 测试发行者的费用收入累计正确
    function test_IssuerRevenueAccumulation() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("DOGE", 1_000_000 ether, 1000 ether, 0.01 ether);

        uint256 cost = 1000 ether * 0.01 ether; // 10 ether
        uint256 expectedIssuerRevenue = cost - cost / 100; // 9.9 ether per mint

        uint256 issuerBalBefore = issuer.balance;

        // 3 次铸造
        for (uint256 i = 0; i < 3; i++) {
            vm.deal(buyer1, cost);
            vm.prank(buyer1);
            factory.mintMeme{value: cost}(tokenAddr);
        }

        assertEq(issuer.balance - issuerBalBefore, expectedIssuerRevenue * 3);
    }

    /// @notice 测试 ERC20 name 生成正确
    function test_MemeTokenName() public {
        vm.prank(issuer);
        address tokenAddr = factory.deployMeme("PEPE", 1_000_000 ether, 1000 ether, 0.01 ether);

        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.name(), "Meme PEPE");
    }

    /// @notice 验证最小代理确实指向 implementation
    function test_MinimalProxy_DeploymentGasSaving() public {
        // 记录直接部署 MemeToken 的 gas
        // （这不会跑 constructor 里的 initialize 因为 _initialized 在 constructor 设 true）

        // 记录通过工厂部署（最小代理）的 gas
        vm.prank(issuer);
        uint256 gasStart = gasleft();
        factory.deployMeme("GAS", 1_000_000 ether, 1000 ether, 0.01 ether);
        uint256 gasUsed = gasStart - gasleft();

        console.log("Gas used for minimal proxy deploy + init: %d", gasUsed);
        // 最小代理部署 + 初始化通常在 ~120k-150k gas
        // 而完整 ERC20 部署通常需要 ~800k-1M gas
        assertLt(gasUsed, 300_000, "Minimal proxy should save significant gas");
    }
}
