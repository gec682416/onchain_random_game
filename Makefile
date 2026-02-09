# Makefile for RandomGamePlatform Project
# SC6107 Course Project - Option 4

-include .env

.PHONY: all test clean install update build deploy help

# 默认目标
all: clean install build test

# 帮助信息
help:
	@echo "SC6107 Random Game Platform - Makefile Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make install       - Install dependencies"
	@echo "  make update        - Update dependencies"
	@echo "  make build         - Compile contracts"
	@echo ""
	@echo "Testing:"
	@echo "  make test          - Run all tests"
	@echo "  make test-v        - Run tests with verbose output"
	@echo "  make test-vvv      - Run tests with very verbose output"
	@echo "  make test-gas      - Run tests with gas report"
	@echo "  make test-fuzz     - Run fuzzing tests"
	@echo "  make coverage      - Generate coverage report"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-sepolia     - Deploy to Sepolia testnet"
	@echo "  make deploy-local       - Deploy to local Anvil"
	@echo ""
	@echo "Other:"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make fmt           - Format code"
	@echo "  make snapshot      - Create gas snapshot"

# 安装依赖
install:
	@echo "Installing dependencies..."
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts@v5.0.0
	forge install smartcontractkit/chainlink-brownie-contracts@1.2.0

# 更新依赖
update:
	@echo "Updating dependencies..."
	forge update

# 编译合约
build:
	@echo "Building contracts..."
	forge build

# 清理
clean:
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf cache out

# 运行测试
test:
	@echo "Running tests..."
	forge test

test-v:
	forge test -vv

test-vvv:
	forge test -vvvv

# Gas 报告
test-gas:
	@echo "Running tests with gas report..."
	forge test --gas-report

# 模糊测试
test-fuzz:
	@echo "Running fuzzing tests (1000 runs)..."
	forge test --fuzz-runs 1000

# 测试覆盖率
coverage:
	@echo "Generating coverage report..."
	forge coverage
	forge coverage --report lcov

coverage-html:
	@echo "Generating HTML coverage report..."
	forge coverage --report lcov
	genhtml lcov.info -o coverage/
	@echo "Coverage report generated in coverage/index.html"
	open coverage/index.html || xdg-open coverage/index.html

# 代码格式化
fmt:
	@echo "Formatting code..."
	forge fmt

# Gas 快照
snapshot:
	@echo "Creating gas snapshot..."
	forge snapshot

# 部署到 Sepolia 测试网
deploy-sepolia:
	@echo "Deploying to Sepolia testnet..."
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

# 部署到本地 Anvil
deploy-local:
	@echo "Deploying to local Anvil..."
	forge script script/Deploy.s.sol:DeployScript \
		--rpc-url http://127.0.0.1:8545 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast \
		-vvvv

# 启动本地 Anvil 节点
anvil:
	@echo "Starting Anvil local node..."
	anvil

# 验证合约（需要提供合约地址）
verify:
	@echo "Verifying contract..."
	@read -p "Enter contract address: " addr; \
	forge verify-contract $$addr \
		src/RandomGamePlatform.sol:RandomGamePlatform \
		--chain-id 11155111 \
		--constructor-args $$(cast abi-encode "constructor(address,bytes32,uint64,uint32)" $(VRF_COORDINATOR) $(GAS_LANE) $(SUBSCRIPTION_ID) $(CALLBACK_GAS_LIMIT)) \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

# 运行特定测试
test-lottery:
	@echo "Running lottery tests..."
	forge test --match-test "test_.*Lottery.*"

test-dice:
	@echo "Running dice tests..."
	forge test --match-test "test_.*Dice.*"

test-security:
	@echo "Running security tests..."
	forge test --match-test "test_.*Security.*|test_.*Reentrancy.*|test_.*Owner.*"

# 检查合约大小
check-size:
	@echo "Checking contract sizes..."
	forge build --sizes

# 生成文档
doc:
	@echo "Generating documentation..."
	forge doc

# 运行静态分析（需要安装 slither）
analyze:
	@echo "Running Slither static analysis..."
	slither src/RandomGamePlatform.sol

# 完整的 CI 测试流程
ci: clean install build test-gas coverage
	@echo "CI pipeline completed successfully!"
