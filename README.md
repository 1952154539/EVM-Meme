# EVM-Meme: 基于最小代理的 ERC20 铸币工厂

基于 **ERC-1167 最小代理（Minimal Proxy）** 的公平发行 Meme 代币工厂。每次创建 Meme 代币仅部署 ~55 字节的代理合约，大幅降低 Gas 成本。

## 核心原理

### 最小代理（ERC-1167）如何节省 Gas

| 方式 | 部署字节码大小 | Gas 消耗 |
|------|---------------|---------|
| 完整部署 ERC20 | ~15 KB | ~800k–1M |
| **最小代理（本项目）** | **~55 bytes** | **~228k（含初始化）** |

- 代理合约只存储指向实现合约的地址，所有调用通过 `delegatecall` 转发到同一个实现合约
- 每个代理拥有独立的 storage（状态），共享 implementation 的代码逻辑
- 实现合约只部署一次，后续每个 Meme 代币都是廉价的代理副本

参考：[EIP-1167](https://eips.ethereum.org/EIPS/eip-1167) | [OpenZeppelin Clones](https://docs.openzeppelin.com/contracts/5.x/api/proxy#Clones)

## 合约架构

```
┌──────────────────────┐
│   MemeFactory        │  ← 工厂合约（部署一次）
│  - deployMeme()      │
│  - mintMeme()        │
│  - implementation    │──┐
└──────────┬───────────┘  │
           │ clone        │
    ┌──────┴──────┐       ▼
    │   Proxy 1   │──delegatecall──► ┌──────────────────┐
    │  (DOGE)     │                  │  MemeToken        │
    └─────────────┘                  │  (Implementation) │
    ┌─────────────┐                  │  - initialize()   │
    │   Proxy 2   │──delegatecall──► │  - mint()         │
    │  (PEPE)     │                  │  - transfer()     │
    └─────────────┘                  └──────────────────┘
```

## 功能说明

### MemeFactory

| 方法 | 描述 |
|------|------|
| `deployMeme(symbol, totalSupply, perMint, price)` | 发行者创建新的 Meme ERC20 代币（通过最小代理） |
| `mintMeme(tokenAddr)` payable | 用户支付 ETH 购买 Meme 代币，每次铸造 `perMint` 个 |

### 费用分配

每次铸造费用 = `perMint × price`：
- **1%** → 项目方（`owner()`）
- **剩余** → Meme 发行者（`issuer`）

### 公平发行机制

- 不是一次性铸造全部代币
- 每次购买只能铸造固定数量 `perMint`
- 任何人都可以购买，先到先得
- 铸造总量不会超过 `totalSupply`

## 快速开始

### 环境要求

- [Foundry](https://book.getfoundry.sh/)

### 安装依赖

```shell
git clone https://github.com/1952154539/EVM-Meme.git
cd EVM-Meme
forge install
```

### 编译

```shell
forge build
```

### 运行测试

```shell
forge test -vvv
```

### Gas 报告

```shell
forge test --gas-report
```

## 测试覆盖

| 测试用例 | 描述 |
|---------|------|
| `test_DeployMeme` | 创建代币并验证参数正确 |
| `test_DeployMeme_EmitsEvent` | 验证部署事件 |
| `test_MintMeme_CorrectAmount` | 验证铸造数量正确 |
| `test_MintMeme_FeeDistribution` | 验证费用按比例分配（1% 项目方） |
| `test_MintMeme_RefundExcess` | 验证超额支付退款 |
| `test_MintMeme_MultipleMints` | 多次铸造累计验证 |
| `test_MintMeme_MultipleBuyers` | 多买家铸造验证 |
| `test_MintMeme_CannotExceedTotalSupply` | 不超发验证 |
| `test_MintMeme_PartialLastMint` | 非整除总量边界情况 |
| `test_MintMeme_InsufficientPayment` | 支付不足 revert |
| `test_ERC20_Transfer` | ERC20 转账 |
| `test_ERC20_ApproveAndTransferFrom` | ERC20 授权转账 |
| `test_IssuerRevenueAccumulation` | 发行者收入累计验证 |
| `test_MultipleMemeTokens` | 多代币互不干扰 |
| `test_AnyoneCanDeployMeme` | 任何人可发行 Meme |
| `test_MemeTokenName` | 名称生成验证 |
| `test_MinimalProxy_DeploymentGasSaving` | Gas 节省验证 |

## Gas 报告摘要

```
deployMeme:  ~228,000 gas  （含代理部署 + 初始化）
mintMeme:     ~95,000 gas  （含铸造 + 费用分配）
```

## 技术栈

- Solidity ^0.8.20
- Foundry (forge)
- OpenZeppelin Contracts v5.3.0 (Clones, Ownable)
- ERC-1167 Minimal Proxy Standard

## License

MIT
