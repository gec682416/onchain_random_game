# 项目结构

```
New project/
│
├── 📄 foundry.toml                  # Foundry 配置文件
├── 📄 remappings.txt                # 依赖映射配置
├── 📄 Makefile                      # 常用命令集合
├── 📄 .env.example                  # 环境变量模板
├── 📄 .gitignore                    # Git 忽略规则
├── 📄 README.md                     # 项目主文档
│
├── 📁 src/                          # 智能合约源代码
│   └── 📄 RandomGamePlatform.sol   # 核心游戏平台合约
│                                     - Lottery 抽奖系统
│                                     - Dice 骰子游戏
│                                     - Chainlink VRF 集成
│                                     - 安全防护机制
│
├── 📁 test/                         # 测试文件
│   └── 📄 RandomGamePlatform.t.sol # 完整测试套件
│                                     - 单元测试
│                                     - 集成测试
│                                     - 模糊测试
│                                     - 安全测试
│
├── 📁 script/                       # 部署脚本
│   └── 📄 Deploy.s.sol             # 部署和设置脚本
│
├── 📁 docs/                         # 文档目录
│   ├── 📄 PROJECT_SUMMARY.md       # 技术设计文档
│   ├── 📄 CHAINLINK_VRF_SETUP.md   # VRF 设置指南
│   └── 📄 QUICK_START.md           # 快速开始指南
│
└── 📁 lib/                          # 依赖库（通过 forge install）
    ├── forge-std/                   # Foundry 标准库
    ├── openzeppelin-contracts/      # OpenZeppelin 合约库
    └── chainlink/                   # Chainlink 智能合约

```

---

## 📄 文件说明

### 配置文件

| 文件 | 用途 |
|------|------|
| **foundry.toml** | Foundry 项目配置，包含编译器版本、优化设置、测试配置等 |
| **remappings.txt** | 依赖库路径映射，简化 import 语句 |
| **Makefile** | 封装常用命令，提供便捷的开发工作流 |
| **.env.example** | 环境变量模板，包含 VRF 配置、RPC URL、私钥等 |
| **.gitignore** | Git 版本控制忽略规则 |

### 核心文件

| 文件 | 作用 | 行数估算 |
|------|------|---------|
| **src/RandomGamePlatform.sol** | 主合约 | ~700 行 |
| **test/RandomGamePlatform.t.sol** | 测试套件 | ~600 行 |
| **script/Deploy.s.sol** | 部署脚本 | ~100 行 |

### 文档文件

| 文件 | 内容 |
|------|------|
| **README.md** | 项目概览、安装指南、使用说明 |
| **docs/PROJECT_SUMMARY.md** | 完整技术设计文档、架构说明 |
| **docs/CHAINLINK_VRF_SETUP.md** | Chainlink VRF 详细设置教程 |
| **docs/QUICK_START.md** | 5分钟快速上手指南 |

---

## 🔧 依赖库

### Foundry Standard Library (forge-std)
- 测试框架和工具
- 控制台输出
- 断言函数

### OpenZeppelin Contracts 5.x
```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```

### Chainlink Contracts
```solidity
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
```

---

## 📊 代码统计

### 合约规模
- **总行数**: ~700 行
- **函数数量**: ~30 个
- **事件数量**: 8 个
- **自定义错误**: 9 个

### 测试覆盖
- **测试函数**: 40+ 个
- **覆盖率目标**: 80%+
- **测试类型**: 单元、集成、模糊、安全

---

## 🎯 核心功能模块

### 1. 抽奖系统（Lottery）
```
函数:
├── startLottery()      # 创建抽奖
├── buyTickets()        # 购买彩票
├── endLottery()        # 结束抽奖
└── _settleLottery()    # 结算（内部）
```

### 2. 骰子游戏（Dice）
```
函数:
├── placeDiceBet()      # 下注
└── _settleDiceBet()    # 结算（内部）
```

### 3. VRF 集成
```
函数:
└── fulfillRandomWords() # VRF 回调
```

### 4. 管理功能
```
函数:
├── depositToPool()     # 存入资金池
├── withdrawFromPool()  # 提取资金池
├── setPlatformFeeRate() # 设置手续费
├── pause()            # 暂停
├── unpause()          # 恢复
└── emergencyWithdraw() # 紧急提取
```

### 5. 查询函数（View）
```
函数:
├── getLotteryInfo()    # 抽奖信息
├── getUserTickets()    # 用户彩票
├── getDiceBetInfo()    # 投注信息
├── getPlatformPoolBalance() # 资金池余额
├── getCurrentLotteryId() # 当前抽奖ID
├── getCurrentDiceBetId() # 当前投注ID
├── getPlatformFeeRate() # 手续费率
└── getVRFConfig()      # VRF配置
```

---

## 🔐 安全特性

```
安全层:
├── ReentrancyGuard      # 防重入攻击
├── Ownable              # 权限控制
├── Pausable             # 紧急暂停
├── SafeERC20            # 安全转账
├── Checks-Effects-Interactions # 设计模式
└── Custom Errors        # Gas 优化
```

---

## 📦 构建产物

运行 `forge build` 后生成:

```
out/
└── RandomGamePlatform.sol/
    ├── RandomGamePlatform.json  # ABI + 字节码
    └── RandomGamePlatform.metadata.json
```

运行 `forge test` 后生成:

```
cache/
└── 测试缓存文件
```

---

## 🚀 工作流程

```
开发流程:
1. 编写合约 (src/)
2. 编写测试 (test/)
3. 本地测试
   ├── forge build
   ├── forge test
   └── forge coverage
4. 本地部署测试
   ├── anvil (启动节点)
   └── make deploy-local
5. 测试网部署
   ├── 配置 .env
   ├── 设置 VRF
   └── make deploy-sepolia
6. 验证和监控
   ├── 验证合约
   └── 监控事件
```

---

## 📈 项目指标

| 指标 | 值 |
|------|---|
| Solidity 版本 | 0.8.20 |
| 合约行数 | ~700 |
| 测试行数 | ~600 |
| 测试覆盖率 | 80%+ |
| Gas 优化 | ✅ |
| 安全审计 | 建议进行 |
| 文档完整度 | 100% |

---

**项目状态**: ✅ 完成  
**最后更新**: 2026年2月5日
