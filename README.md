# SC6107 课程项目 - 链上可验证随机数游戏平台

**作者**: SC6107 课程学生  
**选项**: Option 4 - 链上可验证随机数游戏平台  
**框架**: Foundry + Solidity 0.8.20  
**集成**: Chainlink VRF V2.5 + OpenZeppelin 5.x

---

## 📋 项目概述

本项目实现了一个完全去中心化的链上游戏平台，利用 **Chainlink VRF V2.5** 提供可验证的随机数生成，确保游戏公平性和透明度。平台包含两个核心游戏：

### 🎰 游戏类型

1. **抽奖系统（Lottery）**
   - 基于时间的定期抽奖
   - 玩家购买彩票参与
   - 根据持有彩票数量加权选择获胜者
   - 支持 ETH 和 ERC-20 代币

2. **骰子游戏（Dice）**
   - 倍率投注猜数字（1-6）
   - 5倍赔率（理论6倍扣除平台费用）
   - 即时结算
   - 支持 ETH 和 ERC-20 代币

---

## 🏗️ 项目结构

```
.
├── foundry.toml           # Foundry 配置文件
├── remappings.txt         # 依赖映射
├── .env.example           # 环境变量模板
├── src/
│   └── RandomGamePlatform.sol  # 核心游戏合约
├── test/
│   └── RandomGamePlatform.t.sol  # 测试套件
├── script/
│   └── Deploy.s.sol       # 部署脚本（待创建）
└── lib/                   # Foundry 依赖库
```

---

## 🔐 安全特性

### 1. **防御措施**
- ✅ **ReentrancyGuard**: 防止重入攻击
- ✅ **Ownable**: 权限控制
- ✅ **Pausable**: 紧急暂停机制
- ✅ **SafeERC20**: 安全的 ERC20 转账
- ✅ **Checks-Effects-Interactions**: 严格遵循模式

### 2. **漏洞防护**
- 整数溢出：Solidity 0.8.x 内置保护
- 权限绕过：所有者权限控制
- 重入攻击：nonReentrant 修饰符
- 资金安全：多层验证和状态检查

### 3. **审计要点**
- 完整的 NatSpec 注释
- 详细的事件日志
- 自定义错误（节省 Gas）
- 全面的权限检查

---

## 🚀 快速开始

### 1. 安装依赖

```bash
# 安装 Foundry（如果尚未安装）
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 安装项目依赖
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0 --no-commit
forge install smartcontractkit/chainlink --no-commit
```

### 2. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，填入你的配置
```

### 3. 编译合约

```bash
forge build
```

### 4. 运行测试

```bash
# 运行所有测试
forge test

# 详细输出
forge test -vvv

# 运行特定测试
forge test --match-test test_StartLottery_Success

# 查看 Gas 报告
forge test --gas-report

# 运行模糊测试
forge test --fuzz-runs 1000
```

### 5. 测试覆盖率

```bash
# 生成覆盖率报告
forge coverage

# 生成详细的 HTML 报告
forge coverage --report lcov
genhtml lcov.info -o coverage/
open coverage/index.html
```

---

## 📊 测试套件

### 测试类别

本项目包含全面的测试套件，目标覆盖率 **80%+**：

#### ✅ 单元测试
- 构造函数和初始化
- 抽奖功能（开启、购买、结算）
- 骰子游戏（下注、结算）
- 管理功能（资金池、手续费）
- 权限控制

#### ✅ 安全测试
- 重入攻击防护
- 权限绕过测试
- 边界条件验证

#### ✅ 模糊测试（Fuzzing）
- 随机彩票购买数量
- 随机骰子投注金额
- 随机抽奖持续时间

#### ✅ 集成测试
- Chainlink VRF 集成
- ERC20 代币支持
- 多玩家场景

### 运行特定测试类别

```bash
# 抽奖功能测试
forge test --match-contract RandomGamePlatformTest --match-test test_.*Lottery.*

# 骰子游戏测试
forge test --match-contract RandomGamePlatformTest --match-test test_.*Dice.*

# 模糊测试
forge test --match-contract RandomGamePlatformTest --match-test testFuzz_.*
```

---

## 🔗 Chainlink VRF V2.5 集成

### VRF 配置

合约使用 Chainlink VRF V2.5 提供可验证的链上随机数：

```solidity
VRF_COORDINATOR = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625 (Sepolia)
GAS_LANE = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
CALLBACK_GAS_LIMIT = 500000
REQUEST_CONFIRMATIONS = 3
```

### 订阅设置

1. 访问 [Chainlink VRF Subscription Manager](https://vrf.chain.link)
2. 创建新订阅并充值 LINK 代币
3. 添加合约地址为消费者
4. 更新 `.env` 中的 `SUBSCRIPTION_ID`

---

## 📝 合约接口

### 抽奖功能

```solidity
// 开启抽奖（仅所有者）
function startLottery(uint256 ticketPrice, uint256 duration, address token) external;

// 购买彩票
function buyTickets(uint256 lotteryId, uint256 ticketCount) external payable;

// 结束抽奖
function endLottery(uint256 lotteryId) external;

// 查询抽奖信息
function getLotteryInfo(uint256 lotteryId) external view returns (...);
```

### 骰子游戏

```solidity
// 下注
function placeDiceBet(uint256 predictedNumber, address token) external payable;

// 查询投注信息
function getDiceBetInfo(uint256 betId) external view returns (...);
```

### 管理功能

```solidity
// 存入资金池
function depositToPool(address token, uint256 amount) external payable;

// 提取资金池
function withdrawFromPool(address token, uint256 amount) external;

// 设置手续费率
function setPlatformFeeRate(uint256 newFeeRate) external;

// 暂停/恢复
function pause() external;
function unpause() external;
```

---

## 🎯 使用示例

### 示例 1: 创建并参与抽奖

```solidity
// 1. 所有者创建抽奖
platform.startLottery(0.1 ether, 7 days, address(0));

// 2. 玩家购买彩票
platform.buyTickets{value: 0.5 ether}(0, 5);

// 3. 等待时间结束后，任何人可以触发结算
platform.endLottery(0);

// 4. Chainlink VRF 自动回调，选出获胜者
```

### 示例 2: 玩骰子游戏

```solidity
// 玩家下注猜数字 3，投注 1 ETH
platform.placeDiceBet{value: 1 ether}(3, address(0));

// Chainlink VRF 自动返回随机数并结算
// 如果猜中，玩家获得 5 ETH
// 如果未猜中，投注金额归平台
```

---

## 📈 Gas 优化

- 使用自定义错误（Custom Errors）替代字符串
- 合理使用 `immutable` 和 `constant`
- 批量操作减少存储写入
- 优化循环和数据结构

---

## 🔧 部署指南

### Sepolia 测试网部署

```bash
# 设置环境变量
source .env

# 部署合约
forge create src/RandomGamePlatform.sol:RandomGamePlatform \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args \
        $VRF_COORDINATOR \
        $GAS_LANE \
        $SUBSCRIPTION_ID \
        $CALLBACK_GAS_LIMIT \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

### 使用脚本部署

```bash
forge script script/Deploy.s.sol:DeployScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify
```

---

## 📚 技术栈

- **Solidity**: 0.8.20
- **Foundry**: Latest
- **OpenZeppelin**: 5.x
  - ReentrancyGuard
  - Ownable
  - Pausable
  - SafeERC20
- **Chainlink**: VRF V2.5

---

## ⚠️ 注意事项

1. **VRF 订阅**: 确保 Chainlink VRF 订阅有足够的 LINK 代币
2. **资金池管理**: Dice 游戏需要平台资金池有足够余额支付赔付
3. **手续费**: 默认平台手续费为 2%（可调整，最高 10%）
4. **测试网**: 建议在 Sepolia 测试网充分测试后再部署主网
5. **审计**: 生产环境部署前建议进行专业安全审计

---

## 📄 许可证

MIT License

---

## 🤝 贡献

本项目为 SC6107 课程作业，仅供学习和研究使用。

---

## 📧 联系方式

如有问题，请联系课程助教或在课程论坛提问。

---

## 🎓 学术诚信声明

本项目为原创作品，遵守 NTU 学术诚信政策。所有代码和文档均为独立完成，引用的开源库已标注来源。

---

**祝你的项目顺利完成！Good luck! 🚀**
