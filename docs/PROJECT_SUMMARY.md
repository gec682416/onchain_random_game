# SC6107 项目总结文档
## 链上可验证随机数游戏平台 - 技术设计文档

---

## 📋 项目概览

### 项目信息
- **课程**: SC6107 - Blockchain Technology and Applications
- **选项**: Option 4 - 链上可验证随机数游戏平台
- **技术栈**: Solidity 0.8.20, Foundry, Chainlink VRF V2.5, OpenZeppelin 5.x
- **网络**: Sepolia 测试网 (部署) / 本地 Foundry (测试)

### 项目目标
开发一个完全去中心化的游戏平台，利用 Chainlink VRF 提供可验证的随机数，确保游戏公平性和透明度。

---

## 🏗️ 系统架构

### 核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                  RandomGamePlatform                         │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐  │
│  │   Lottery   │  │    Dice     │  │  Platform Pool   │  │
│  │   System    │  │    Game     │  │   Management     │  │
│  └─────────────┘  └─────────────┘  └──────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Chainlink VRF V2.5 Integration             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │     Security Layer (ReentrancyGuard, Ownable)        │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │
                    ┌──────┴──────┐
                    │             │
              ┌─────▼────┐  ┌─────▼────┐
              │   ETH    │  │  ERC-20  │
              │ Payments │  │  Tokens  │
              └──────────┘  └──────────┘
```

---

## 🎮 游戏机制

### 1. 抽奖系统（Lottery）

#### 工作流程
```
1. 所有者创建抽奖 (startLottery)
   ├─ 设置票价
   ├─ 设置持续时间
   └─ 选择支付代币 (ETH/ERC-20)

2. 玩家购买彩票 (buyTickets)
   ├─ 支付 = 票价 × 数量
   ├─ 累计到奖池
   └─ 记录持有票数

3. 时间结束后触发结算 (endLottery)
   ├─ 请求 Chainlink VRF 随机数
   └─ 等待回调

4. VRF 回调自动选出获胜者
   ├─ 按持票数加权选择
   ├─ 扣除手续费 (默认 2%)
   └─ 转账奖金给获胜者
```

#### 关键特性
- **加权公平**: 持票越多，中奖概率越高
- **时间锁定**: 只能在规定时间内购买
- **自动结算**: VRF 回调自动完成
- **多代币支持**: ETH 和任意 ERC-20

#### 数据结构
```solidity
struct LotteryRound {
    uint256 id;
    uint256 ticketPrice;
    uint256 startTime;
    uint256 endTime;
    address[] participants;
    mapping(address => uint256) ticketCount;
    uint256 totalTickets;
    uint256 prizePool;
    address winner;
    bool settled;
    address token;
    uint256 vrfRequestId;
}
```

---

### 2. 骰子游戏（Dice）

#### 工作流程
```
1. 玩家下注 (placeDiceBet)
   ├─ 选择预测数字 (1-6)
   ├─ 投注金额
   ├─ 检查平台资金池
   └─ 请求 VRF 随机数

2. VRF 回调投掷骰子
   ├─ 生成随机数 (1-6)
   └─ 判断输赢

3. 自动结算
   ├─ 赢: 支付 5x 赔率
   └─ 输: 投注进入资金池
```

#### 赔率设计
- **预测概率**: 1/6 ≈ 16.67%
- **理论赔率**: 6x
- **实际赔率**: 5x (扣除平台费用)
- **平台优势**: ~16.67%

#### 数据结构
```solidity
struct DiceBet {
    uint256 id;
    address player;
    uint256 betAmount;
    uint256 predictedNumber;
    uint256 multiplier;
    address token;
    uint256 rollResult;
    bool settled;
    uint256 vrfRequestId;
}
```

---

## 🔐 安全设计

### 1. Checks-Effects-Interactions 模式

所有函数严格遵循 CEI 模式，防止重入攻击：

```solidity
function buyTickets(uint256 lotteryId, uint256 ticketCount) external payable {
    // ✅ Checks - 检查条件
    if (block.timestamp >= lottery.endTime) revert LotteryNotActive();
    if (ticketCount == 0) revert InvalidBetAmount();
    
    // ✅ Effects - 更新状态
    lottery.ticketCount[msg.sender] += ticketCount;
    lottery.totalTickets += ticketCount;
    lottery.prizePool += totalCost;
    
    // ✅ Interactions - 外部调用
    if (lottery.token == address(0)) {
        // ETH 转账
    } else {
        IERC20(lottery.token).safeTransferFrom(msg.sender, address(this), totalCost);
    }
}
```

### 2. 重入防护

所有涉及资金转移的函数都使用 `nonReentrant` 修饰符：

```solidity
function buyTickets(...) external payable nonReentrant whenNotPaused {
    // 函数实现
}

function placeDiceBet(...) external payable nonReentrant whenNotPaused {
    // 函数实现
}
```

### 3. 访问控制

- **Ownable**: 所有者专属函数
  - `startLottery()` - 创建抽奖
  - `depositToPool()` - 存入资金池
  - `withdrawFromPool()` - 提取资金池
  - `setPlatformFeeRate()` - 设置手续费
  - `pause()` / `unpause()` - 暂停控制

### 4. 暂停机制

紧急情况下可暂停合约：
```solidity
function pause() external onlyOwner {
    _pause();
}

function emergencyWithdraw(...) external onlyOwner whenPaused {
    // 仅在暂停状态下可用
}
```

### 5. 整数溢出防护

- Solidity 0.8.x 内置溢出检查
- 所有算术运算自动保护

---

## 🔗 Chainlink VRF 集成

### VRF 请求流程

```
┌──────────┐         ┌─────────────────┐         ┌──────────────┐
│  Player  │────1───▶│ RandomGamePlatform│───2───▶│ VRF Coord.  │
└──────────┘         └─────────────────┘         └──────────────┘
                              │                          │
                              │◀─────────3───────────────┘
                              │ (Random Number)
                              ▼
                        ┌─────────────┐
                        │   Settle    │
                        │   Game      │
                        └─────────────┘
```

### 步骤说明

1. **用户触发**: 购买彩票/下注骰子
2. **请求随机数**: 调用 VRF Coordinator
   ```solidity
   uint256 requestId = i_vrfCoordinator.requestRandomWords(
       i_gasLane,
       i_subscriptionId,
       REQUEST_CONFIRMATIONS,
       i_callbackGasLimit,
       NUM_WORDS
   );
   ```
3. **VRF 回调**: 接收随机数并结算
   ```solidity
   function fulfillRandomWords(
       uint256 requestId,
       uint256[] memory randomWords
   ) internal override {
       // 自动结算游戏
   }
   ```

### 参数配置

| 参数 | 值 | 说明 |
|------|----|----|
| Gas Lane | 0x474e...bc56c | Sepolia 500 gwei |
| Confirmations | 3 | 区块确认数 |
| Callback Gas | 500,000 | 回调函数 gas 限制 |
| Num Words | 1 | 每次请求 1 个随机数 |

---

## 💰 经济模型

### 手续费机制

- **默认费率**: 2% (200 basis points)
- **可调整范围**: 0% - 10%
- **费用去向**: 平台资金池

### 抽奖经济

```
总奖池 = 票价 × 总票数
手续费 = 总奖池 × 2%
获胜者奖金 = 总奖池 - 手续费

示例：
- 票价: 0.1 ETH
- 总票数: 100
- 总奖池: 10 ETH
- 手续费: 0.2 ETH
- 获胜者: 9.8 ETH
```

### 骰子游戏经济

```
理论期望值 = 投注 × 概率 × 赔率
          = 投注 × (1/6) × 5
          = 投注 × 0.833
          
玩家劣势 = 1 - 0.833 = 16.7%

示例：
- 投注: 1 ETH
- 猜中数字: 3
- 随机结果: 3 ✅
- 赔付: 5 ETH
- 净收益: 4 ETH
```

### 平台资金池

**用途**:
- 支付 Dice 游戏赔付
- 收集平台手续费
- 紧急储备金

**管理**:
```solidity
// 存入
depositToPool(address token, uint256 amount)

// 提取
withdrawFromPool(address token, uint256 amount)

// 查询
getPlatformPoolBalance(address token)
```

---

## 📊 Gas 优化

### 1. 使用自定义错误

```solidity
// ❌ 旧方式 (高 gas)
require(amount > 0, "Invalid amount");

// ✅ 新方式 (低 gas)
error InvalidBetAmount();
if (amount == 0) revert InvalidBetAmount();
```

**节省**: ~50% gas

### 2. Immutable 变量

```solidity
VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
bytes32 private immutable i_gasLane;
```

### 3. 常量定义

```solidity
uint256 private constant DICE_MULTIPLIER = 500;
uint32 private constant NUM_WORDS = 1;
```

### 4. 事件替代存储

对于不需要链上查询的数据，使用事件而非存储：

```solidity
event TicketPurchased(
    uint256 indexed lotteryId,
    address indexed player,
    uint256 ticketCount,
    uint256 totalCost
);
```

---

## 🧪 测试策略

### 测试覆盖率目标: 80%+

### 测试类别

#### 1. 单元测试
- ✅ 构造函数初始化
- ✅ 抽奖创建和参与
- ✅ 骰子游戏投注
- ✅ 资金池管理
- ✅ 权限控制

#### 2. 集成测试
- ✅ VRF 完整流程
- ✅ 多玩家场景
- ✅ ERC-20 代币支持

#### 3. 安全测试
- ✅ 重入攻击防护
- ✅ 权限绕过测试
- ✅ 边界条件验证

#### 4. 模糊测试
- ✅ 随机彩票数量
- ✅ 随机投注金额
- ✅ 随机时间参数

### 运行测试

```bash
# 所有测试
forge test

# 详细输出
forge test -vvv

# Gas 报告
forge test --gas-report

# 覆盖率
forge coverage

# 模糊测试
forge test --fuzz-runs 1000
```

---

## 📈 性能指标

### Gas 成本估算

| 操作 | Gas 成本 (估算) |
|------|----------------|
| 部署合约 | ~3,000,000 |
| 创建抽奖 | ~150,000 |
| 购买彩票 (首次) | ~180,000 |
| 购买彩票 (后续) | ~110,000 |
| 结束抽奖 | ~100,000 |
| 下注骰子 | ~150,000 |
| VRF 回调 | ~80,000 - 150,000 |

### 优化建议

1. **批量购买**: 一次购买多张彩票
2. **减少存储写入**: 使用事件记录历史
3. **缓存计算**: 避免重复计算

---

## 🚀 部署清单

### 部署前准备

- [ ] 获取 Sepolia ETH (2-3 ETH)
- [ ] 获取 Sepolia LINK (5-10 LINK)
- [ ] 创建 Chainlink VRF 订阅
- [ ] 配置 .env 文件
- [ ] 编译合约通过
- [ ] 所有测试通过
- [ ] 代码审查完成

### 部署步骤

```bash
# 1. 编译
make build

# 2. 本地测试
make test

# 3. 部署到 Sepolia
make deploy-sepolia

# 4. 添加消费者到 VRF 订阅
# 访问 https://vrf.chain.link/

# 5. 验证合约
make verify

# 6. 初始化资金池
cast send <合约地址> \
  "depositToPool(address,uint256)" \
  0x0000000000000000000000000000000000000000 \
  10000000000000000000 \
  --value 10ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 部署后验证

- [ ] 合约地址已添加到 VRF 订阅
- [ ] 资金池有足够余额
- [ ] VRF 配置正确
- [ ] 测试创建抽奖
- [ ] 测试骰子游戏
- [ ] 监控事件日志

---

## 🎯 项目亮点

### 技术创新

1. **完整的 VRF V2.5 集成**
   - 最新的 Chainlink VRF 版本
   - 优化的 gas 成本
   - 可靠的随机数生成

2. **双游戏机制**
   - 抽奖：社交性强，奖池累积
   - 骰子：即时反馈，快速游戏

3. **全面的安全措施**
   - 多层防护
   - 遵循最佳实践
   - 详细的测试覆盖

4. **灵活的支付系统**
   - 支持 ETH
   - 支持任意 ERC-20
   - 统一的接口

### 学术价值

1. **完整的文档**
   - NatSpec 注释
   - 架构设计文档
   - 部署指南

2. **高质量测试**
   - 80%+ 覆盖率
   - 多种测试类型
   - 真实场景模拟

3. **最佳实践示范**
   - CEI 模式
   - Gas 优化
   - 错误处理

---

## 📚 学习要点

### 核心概念

1. **可验证随机数**
   - 为什么需要 VRF？
   - VRF 如何工作？
   - 订阅模式 vs 直接支付

2. **智能合约安全**
   - 重入攻击
   - 整数溢出
   - 权限控制
   - 时间锁定

3. **Gas 优化**
   - 存储 vs 内存
   - 事件 vs 存储
   - 批量操作

4. **测试驱动开发**
   - 单元测试
   - 集成测试
   - 模糊测试

### 延伸阅读

- [Chainlink VRF 文档](https://docs.chain.link/vrf)
- [OpenZeppelin 合约](https://docs.openzeppelin.com/contracts/)
- [Foundry 手册](https://book.getfoundry.sh/)
- [Solidity 最佳实践](https://consensys.github.io/smart-contract-best-practices/)

---

## 🔮 未来改进方向

### 短期目标

- [ ] 添加更多游戏类型
- [ ] 实现推荐系统
- [ ] 前端界面开发
- [ ] 主网部署

### 长期目标

- [ ] Layer 2 集成（降低成本）
- [ ] NFT 奖励系统
- [ ] DAO 治理
- [ ] 跨链支持

---

## 📞 技术支持

### 问题排查

1. **编译错误**: 检查依赖版本和 Solidity 版本
2. **测试失败**: 查看详细错误信息 (`forge test -vvv`)
3. **部署失败**: 确认网络配置和余额
4. **VRF 未响应**: 检查订阅和消费者配置

### 资源链接

- **Foundry**: https://getfoundry.sh/
- **Chainlink**: https://chain.link/
- **OpenZeppelin**: https://openzeppelin.com/
- **Sepolia Faucet**: https://sepoliafaucet.com/

---

## ✅ 项目检查清单

### 代码质量
- [x] 详细的 NatSpec 注释
- [x] 遵循命名规范
- [x] 无编译警告
- [x] Gas 优化

### 安全性
- [x] 重入防护
- [x] 权限控制
- [x] 整数溢出保护
- [x] CEI 模式

### 测试
- [x] 80%+ 覆盖率
- [x] 单元测试
- [x] 集成测试
- [x] 模糊测试

### 文档
- [x] README.md
- [x] 部署指南
- [x] VRF 设置指南
- [x] 技术设计文档

---

**项目完成日期**: 2026年2月5日  
**版本**: 1.0.0  
**状态**: ✅ 已完成

---

*本项目为 SC6107 课程作业，严格遵守学术诚信政策。*
*所有代码和文档均为原创，引用的开源库已标注来源。*
