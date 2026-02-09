# Chainlink VRF V2.5 设置指南

## 📘 什么是 Chainlink VRF？

Chainlink VRF (Verifiable Random Function) 是一个可验证的随机数生成器，为智能合约提供密码学安全的随机数。每个随机数都附带链上验证证明，确保结果未被篡改。

---

## 🔧 设置步骤

### 步骤 1: 获取测试网 ETH 和 LINK

#### Sepolia 测试网水龙头：
- **Sepolia ETH**: https://sepoliafaucet.com/
- **Sepolia LINK**: https://faucets.chain.link/sepolia

建议余额：
- **2-3 Sepolia ETH** (用于部署和交易)
- **5-10 LINK** (用于 VRF 订阅)

---

### 步骤 2: 创建 VRF 订阅

1. **访问 Chainlink VRF 订阅管理器**
   - 网址: https://vrf.chain.link/
   - 选择 **Sepolia** 测试网

2. **连接钱包**
   - 使用 MetaMask 或其他 Web3 钱包
   - 确保钱包已切换到 Sepolia 网络

3. **创建订阅**
   - 点击 "Create Subscription"
   - 确认交易
   - 记录你的 **Subscription ID**（例如：1234）

4. **充值 LINK**
   - 点击 "Add funds"
   - 输入金额（建议 5 LINK）
   - 确认交易

---

### 步骤 3: 部署合约

```bash
# 1. 配置环境变量
cp .env.example .env

# 2. 编辑 .env 文件，填入以下信息：
VRF_COORDINATOR=0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
GAS_LANE=0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
SUBSCRIPTION_ID=你的订阅ID
CALLBACK_GAS_LIMIT=500000
SEPOLIA_RPC_URL=你的RPC_URL
PRIVATE_KEY=你的私钥
ETHERSCAN_API_KEY=你的Etherscan_API_Key

# 3. 部署合约
make build
make deploy-sepolia
```

---

### 步骤 4: 添加消费者

部署完成后，需要将合约地址添加到 VRF 订阅的消费者列表：

1. 返回 https://vrf.chain.link/
2. 选择你的订阅
3. 点击 "Add consumer"
4. 输入合约地址
5. 确认交易

---

### 步骤 5: 验证配置

运行以下命令验证配置是否正确：

```bash
# 检查 VRF 配置
cast call <合约地址> "getVRFConfig()" --rpc-url $SEPOLIA_RPC_URL
```

---

## 🎮 测试 VRF 集成

### 测试骰子游戏

```bash
# 1. 向平台资金池存入资金
cast send <合约地址> \
  "depositToPool(address,uint256)" \
  0x0000000000000000000000000000000000000000 \
  10000000000000000000 \
  --value 10ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 2. 下注骰子游戏
cast send <合约地址> \
  "placeDiceBet(uint256,address)" \
  3 \
  0x0000000000000000000000000000000000000000 \
  --value 1ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 3. 等待 VRF 回调（约 1-3 分钟）

# 4. 查询结果
cast call <合约地址> \
  "getDiceBetInfo(uint256)" \
  0 \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 📊 VRF 参数说明

### Gas Lane (Key Hash)
决定随机数请求的 gas 价格上限：

| Network | Gas Lane | Max Gas Price |
|---------|----------|---------------|
| Sepolia | 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c | 500 gwei |

### Callback Gas Limit
VRF 回调函数的 gas 限制：
- **推荐值**: 500,000
- **范围**: 100,000 - 2,500,000

### Request Confirmations
区块确认数（安全性 vs 速度）：
- **本项目使用**: 3 个确认
- **推荐范围**: 3-10 个确认

---

## 💰 VRF 成本估算

### Sepolia 测试网
- **每次请求**: ~0.5-1 LINK
- **Gas 成本**: ~0.001-0.003 ETH

### 主网成本（参考）
- **每次请求**: ~2-5 LINK
- **Gas 成本**: 根据网络拥堵情况变化

**建议**: 
- 测试网至少充值 5 LINK
- 主网建议充值 20-50 LINK

---

## 🔍 调试 VRF

### 常见问题

#### 1. VRF 请求未响应
**检查清单**：
- [ ] 订阅是否有足够的 LINK？
- [ ] 合约是否已添加为消费者？
- [ ] Gas Limit 是否足够？
- [ ] 网络是否拥堵？

**解决方法**：
```bash
# 检查订阅余额
# 访问 https://vrf.chain.link/ 查看

# 检查消费者列表
# 在订阅页面查看 "Consumers" 列表
```

#### 2. 回调失败
**可能原因**：
- Callback Gas Limit 太低
- 合约逻辑错误
- 资金不足（Dice 游戏）

**解决方法**：
```bash
# 查看交易失败原因
cast tx <交易哈希> --rpc-url $SEPOLIA_RPC_URL
```

#### 3. 成本过高
**优化建议**：
- 降低 Callback Gas Limit
- 减少回调函数中的计算
- 批量处理请求

---

## 📈 监控和日志

### 事件监听

```bash
# 监听 VRF 请求事件
cast logs \
  --address <合约地址> \
  --from-block latest \
  --rpc-url $SEPOLIA_RPC_URL \
  "RandomnessRequested(uint256,uint256,uint8)"

# 监听 VRF 响应事件
cast logs \
  --address <合约地址> \
  --from-block latest \
  --rpc-url $SEPOLIA_RPC_URL \
  "RandomnessFulfilled(uint256,uint256[])"
```

### 使用 Etherscan

1. 访问 https://sepolia.etherscan.io/
2. 搜索合约地址
3. 查看 "Events" 标签页
4. 筛选 VRF 相关事件

---

## 🛡️ 安全最佳实践

### 1. 订阅管理
- 定期检查 LINK 余额
- 设置余额告警
- 只添加可信的消费者合约

### 2. Gas 限制
- 合理设置 Callback Gas Limit
- 避免回调函数中的复杂计算
- 考虑 gas 价格波动

### 3. 随机数使用
- 不要在同一交易中使用随机数
- 等待 VRF 回调完成
- 验证随机数有效性

---

## 📚 参考资源

### 官方文档
- **VRF 文档**: https://docs.chain.link/vrf/v2/introduction
- **订阅管理**: https://docs.chain.link/vrf/v2/subscription
- **最佳实践**: https://docs.chain.link/vrf/v2/best-practices

### Sepolia 网络配置
```
VRF Coordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
LINK Token: 0x779877A7B0D9E8603169DdbD7836e478b4624789
```

### 其他测试网
- **Mumbai (Polygon)**: https://docs.chain.link/vrf/v2/subscription/supported-networks#polygon-mumbai-testnet
- **Goerli**: 已废弃，请使用 Sepolia

---

## 🎯 快速参考

```bash
# 完整流程
1. 获取 Sepolia ETH 和 LINK
2. 创建 VRF 订阅并充值
3. 部署合约
4. 添加合约为消费者
5. 测试游戏功能

# 关键配置
VRF_COORDINATOR=0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
GAS_LANE=0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
CALLBACK_GAS_LIMIT=500000
REQUEST_CONFIRMATIONS=3
```

---

**祝你设置顺利！如有问题，请查阅官方文档或联系 Chainlink 技术支持。**
