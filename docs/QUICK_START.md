# 🚀 快速开始指南

本指南将帮助你在 5 分钟内启动并运行 RandomGamePlatform 项目。

---

## ⚡ 快速开始（3 步）

### 步骤 1: 安装依赖

```bash
# 确保已安装 Foundry
foundryup

# 安装项目依赖
make install
```

### 步骤 2: 运行测试

```bash
# 编译和测试
make build
make test
```

### 步骤 3: 查看覆盖率

```bash
make coverage
```

**完成！** 如果所有测试通过，你的环境配置正确。

---

## 📖 详细步骤

### 1. 环境准备

#### 安装 Foundry

```bash
# macOS/Linux
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 验证安装
forge --version
```

#### 克隆项目（如果是从仓库）

```bash
git clone <repository-url>
cd "New project"
```

### 2. 安装依赖

```bash
# 使用 Makefile（推荐）
make install

# 或手动安装
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0 --no-commit
forge install smartcontractkit/chainlink --no-commit
```

### 3. 编译合约

```bash
# 使用 Makefile
make build

# 或使用 forge
forge build
```

**预期输出**:
```
[⠊] Compiling...
[✓] Compilation successful!
```

### 4. 运行测试

```bash
# 基础测试
make test

# 详细输出
make test-v

# 非常详细的输出
make test-vvv

# Gas 报告
make test-gas
```

**预期结果**: 所有测试通过 ✅

### 5. 查看覆盖率

```bash
# 生成覆盖率报告
make coverage

# 生成 HTML 报告（需要 lcov）
make coverage-html
```

**目标**: 80%+ 行覆盖率

---

## 🧪 本地测试部署

### 启动本地节点

```bash
# 终端 1: 启动 Anvil
make anvil
```

### 部署到本地网络

```bash
# 终端 2: 部署合约
make deploy-local
```

### 与合约交互

```bash
# 查看 VRF 配置
cast call <合约地址> "getVRFConfig()" --rpc-url http://127.0.0.1:8545

# 创建抽奖
cast send <合约地址> \
  "startLottery(uint256,uint256,address)" \
  100000000000000000 \
  604800 \
  0x0000000000000000000000000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

---

## 🌐 部署到 Sepolia 测试网

### 前置准备

1. **获取测试网资产**
   - Sepolia ETH: https://sepoliafaucet.com/
   - Sepolia LINK: https://faucets.chain.link/sepolia

2. **创建 VRF 订阅**
   - 访问: https://vrf.chain.link/
   - 选择 Sepolia 网络
   - 创建订阅并充值 5 LINK

3. **配置环境变量**
   ```bash
   cp .env.example .env
   nano .env  # 或使用你喜欢的编辑器
   ```

   填入以下信息:
   ```bash
   VRF_COORDINATOR=0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
   GAS_LANE=0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
   SUBSCRIPTION_ID=你的订阅ID
   CALLBACK_GAS_LIMIT=500000
   SEPOLIA_RPC_URL=你的RPC_URL
   PRIVATE_KEY=你的私钥
   ETHERSCAN_API_KEY=你的API_Key
   ```

### 部署步骤

```bash
# 1. 确保编译成功
make build

# 2. 部署到 Sepolia
make deploy-sepolia

# 3. 记录合约地址
CONTRACT_ADDRESS=<部署的合约地址>
```

### 配置 VRF

```bash
# 返回 https://vrf.chain.link/
# 1. 选择你的订阅
# 2. 点击 "Add consumer"
# 3. 输入合约地址
# 4. 确认交易
```

### 初始化资金池

```bash
cast send $CONTRACT_ADDRESS \
  "depositToPool(address,uint256)" \
  0x0000000000000000000000000000000000000000 \
  10000000000000000000 \
  --value 10ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## 🎮 测试游戏

### 测试抽奖系统

```bash
# 1. 创建抽奖（票价 0.1 ETH，持续 1 小时）
cast send $CONTRACT_ADDRESS \
  "startLottery(uint256,uint256,address)" \
  100000000000000000 \
  3600 \
  0x0000000000000000000000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 2. 购买彩票（5 张 = 0.5 ETH）
cast send $CONTRACT_ADDRESS \
  "buyTickets(uint256,uint256)" \
  0 \
  5 \
  --value 0.5ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 3. 查看抽奖信息
cast call $CONTRACT_ADDRESS \
  "getLotteryInfo(uint256)" \
  0 \
  --rpc-url $SEPOLIA_RPC_URL
```

### 测试骰子游戏

```bash
# 1. 下注猜数字 3，投注 1 ETH
cast send $CONTRACT_ADDRESS \
  "placeDiceBet(uint256,address)" \
  3 \
  0x0000000000000000000000000000000000000000 \
  --value 1ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 2. 等待 VRF 回调（1-3 分钟）

# 3. 查看结果
cast call $CONTRACT_ADDRESS \
  "getDiceBetInfo(uint256)" \
  0 \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 📊 监控和调试

### 查看事件日志

```bash
# 监听所有事件
cast logs \
  --address $CONTRACT_ADDRESS \
  --from-block latest \
  --rpc-url $SEPOLIA_RPC_URL

# 监听特定事件
cast logs \
  --address $CONTRACT_ADDRESS \
  --from-block latest \
  --rpc-url $SEPOLIA_RPC_URL \
  "DiceBetSettled(uint256,address,uint256,bool,uint256)"
```

### 使用 Etherscan

1. 访问 https://sepolia.etherscan.io/
2. 搜索合约地址
3. 查看交易和事件

---

## 🔧 常用命令

### 编译和测试

```bash
make build          # 编译合约
make test           # 运行测试
make test-gas       # Gas 报告
make coverage       # 覆盖率报告
make fmt            # 格式化代码
```

### 部署

```bash
make deploy-local   # 部署到本地 Anvil
make deploy-sepolia # 部署到 Sepolia
```

### 测试特定功能

```bash
make test-lottery   # 测试抽奖功能
make test-dice      # 测试骰子游戏
make test-security  # 测试安全功能
```

---

## ❓ 常见问题

### Q1: 编译失败？

**A**: 检查依赖是否已安装
```bash
forge install
forge build --force
```

### Q2: 测试失败？

**A**: 查看详细错误
```bash
forge test -vvvv --match-test <测试名称>
```

### Q3: VRF 不响应？

**A**: 检查清单
- [ ] 订阅有足够的 LINK？
- [ ] 合约已添加为消费者？
- [ ] 网络配置正确？

### Q4: Gas 不足？

**A**: 增加 Gas Limit
```bash
# 在 foundry.toml 中调整
gas_limit = 30000000
```

### Q5: 部署后如何验证？

**A**: 使用 Etherscan 验证
```bash
make verify
# 或手动验证
forge verify-contract <地址> <合约名> --chain-id 11155111
```

---

## 📚 下一步

1. **深入学习**
   - 阅读 [技术设计文档](docs/PROJECT_SUMMARY.md)
   - 查看 [VRF 设置指南](docs/CHAINLINK_VRF_SETUP.md)

2. **自定义开发**
   - 修改游戏参数
   - 添加新游戏类型
   - 调整手续费率

3. **生产部署**
   - 完成安全审计
   - 部署到主网
   - 开发前端界面

---

## 🆘 获取帮助

### 文档
- [README.md](README.md) - 项目概览
- [PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md) - 技术细节
- [CHAINLINK_VRF_SETUP.md](docs/CHAINLINK_VRF_SETUP.md) - VRF 配置

### 外部资源
- [Foundry Book](https://book.getfoundry.sh/)
- [Chainlink Docs](https://docs.chain.link/)
- [OpenZeppelin Docs](https://docs.openzeppelin.com/)

### 社区
- Foundry Discord
- Chainlink Discord
- Stack Overflow (标签: solidity, foundry)

---

## ✅ 检查清单

完成快速开始后，你应该能够：

- [ ] 编译合约无错误
- [ ] 运行所有测试并通过
- [ ] 查看测试覆盖率 (80%+)
- [ ] 部署到本地 Anvil
- [ ] 理解基本的合约交互
- [ ] 知道如何获取帮助

**恭喜！你已经准备好开始开发了！** 🎉

---

**提示**: 使用 `make help` 查看所有可用命令。
