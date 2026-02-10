import { useEffect, useMemo, useState } from "react";
import { BrowserProvider, Contract, formatEther, parseEther } from "ethers";
import { RANDOM_GAME_ABI } from "./lib/abi.js";
import { APP_CONFIG } from "./lib/config.js";

const initialStatus = {
  connected: false,
  account: "",
  chainId: null,
  contractBalance: "0",
  houseEdge: "0",
  minBet: "0",
  maxBet: "0",
  lockedFunds: "0",
  nextDiceId: "0",
  nextLotteryId: "0",
  vrf: { keyHash: "-", subId: "-", callbackGas: "-" }
};
const MOCK_ABI = [
  "function fulfillRandomWordsWithOverride(uint256 requestId, address consumer, uint32 numWords) external"
];
export default function App() {
  const [status, setStatus] = useState(initialStatus);
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);

  const [fundAmount, setFundAmount] = useState("0.001");
  const [minBet, setMinBet] = useState("0.0001");
  const [maxBet, setMaxBet] = useState("0.0005");

  const [diceStake, setDiceStake] = useState("0.0001");
  const [diceRollUnder, setDiceRollUnder] = useState("50");
  const [dicePayout, setDicePayout] = useState("-");

  const [lotteryTicketPrice, setLotteryTicketPrice] = useState("0.0001");
  const [lotteryStartDelay, setLotteryStartDelay] = useState("60");
  const [lotteryDuration, setLotteryDuration] = useState("300");
  const [lotteryCount, setLotteryCount] = useState("1");
  const [lotteryId, setLotteryId] = useState("0");

  const provider = useMemo(() => {
    if (!window.ethereum) return null;
    return new BrowserProvider(window.ethereum);
  }, []);

  const contractAddress = APP_CONFIG.contractAddress;
  const getContract = async (withSigner = false) => {
    if (!provider) throw new Error("MetaMask not found");
    const signer = withSigner ? await provider.getSigner() : null;
    return new Contract(contractAddress, RANDOM_GAME_ABI, signer ?? provider);
  };

  const refreshStatus = async () => {
    try {
      const contract = await getContract();
      const [balance, houseEdge, tokenCfg, lockedFunds, nextDiceId, nextLotteryId, vrf] =
        await Promise.all([
          provider.getBalance(contractAddress),
          contract.houseEdgeBps(),
          contract.tokenConfigs(APP_CONFIG.defaultToken),
          contract.lockedFunds(APP_CONFIG.defaultToken),
          contract.nextDiceId(),
          contract.nextLotteryId(),
          contract.getVRFConfig()
        ]);

      setStatus((prev) => ({
        ...prev,
        contractBalance: formatEther(balance),
        houseEdge: houseEdge.toString(),
        minBet: formatEther(tokenCfg.minBet),
        maxBet: formatEther(tokenCfg.maxBet),
        lockedFunds: formatEther(lockedFunds),
        nextDiceId: nextDiceId.toString(),
        nextLotteryId: nextLotteryId.toString(),
        vrf: {
          keyHash: vrf.keyHash,
          subId: vrf.subId.toString(),
          callbackGas: vrf.callbackGasLimit.toString()
        }
      }));
    } catch (err) {
      setMessage(err.message ?? "Failed to fetch on-chain data.");
    }
  };

  const connectWallet = async () => {
    if (!provider) {
      setMessage("MetaMask not detected.");
      return;
    }
    try {
      setLoading(true);
      const accounts = await provider.send("eth_requestAccounts", []);
      const network = await provider.getNetwork();
      setStatus((prev) => ({
        ...prev,
        connected: true,
        account: accounts[0],
        chainId: Number(network.chainId)
      }));
      await refreshStatus();
      setMessage("Wallet connected.");
    } catch (err) {
      setMessage(err.message ?? "Wallet connection failed.");
    } finally {
      setLoading(false);
    }
  };

  const ensureNetwork = async () => {
      if (!provider) return;
      const network = await provider.getNetwork();
      if (Number(network.chainId) !== APP_CONFIG.chainId) {
        try {
          // 尝试自动切换到本地网络
          await window.ethereum.request({
            method: "wallet_switchEthereumChain",
            params: [{ chainId: "0x7a69" }],
          });
        } catch (switchError) {
          if (switchError.code === 4902) {
            try {
              await window.ethereum.request({
                method: "wallet_addEthereumChain",
                params: [
                  {
                    chainId: "0x7a69", // 31337
                    chainName: "Anvil Localhost",
                    nativeCurrency: {
                      name: "ETH",
                      symbol: "ETH",
                      decimals: 18,
                    },
                    rpcUrls: ["http://127.0.0.1:8545"],
                  },
                ],
              });
            } catch (addError) {
              throw new Error("Please add Anvil Localhost (Chain ID 31337) to MetaMask.");
            }
          } else {
            throw new Error("Please switch MetaMask to Anvil Localhost.");
          }
        }
      }
    };

  const handleFund = async () => {
    try {
      setLoading(true);
      await ensureNetwork();
      const contract = await getContract(true);
      const value = parseEther(fundAmount || "0");
      const tx = await contract.fundETH({ value });
      await tx.wait();
      setMessage("Treasury funded.");
      await refreshStatus();
    } catch (err) {
      setMessage(err.message ?? "Funding failed.");
    } finally {
      setLoading(false);
    }
  };

  const handleSetConfig = async () => {
    try {
      setLoading(true);
      await ensureNetwork();
      const contract = await getContract(true);
      const minValue = parseEther(minBet || "0");
      const maxValue = parseEther(maxBet || "0");
      const tx = await contract.setTokenConfig(APP_CONFIG.defaultToken, true, minValue, maxValue);
      await tx.wait();
      setMessage("Token config updated.");
      await refreshStatus();
    } catch (err) {
      setMessage(err.message ?? "Config update failed.");
    } finally {
      setLoading(false);
    }
  };

  const handleDiceQuote = async () => {
    try {
      const contract = await getContract();
      const stakeWei = parseEther(diceStake || "0");
      const payout = await contract.calcDicePayout(stakeWei, Number(diceRollUnder));
      setDicePayout(formatEther(payout));
    } catch (err) {
      setDicePayout("-");
      setMessage(err.message ?? "Quote failed.");
    }
  };

const handlePlayDice = async () => {
  try {
    setLoading(true);
    await ensureNetwork();
    const contract = await getContract(true);
    const stakeWei = parseEther(diceStake || "0");
    const tx1 = await contract.playDice(
      APP_CONFIG.defaultToken,
      stakeWei,
      Number(diceRollUnder),
      { value: stakeWei }
    );
    const receipt1 = await tx1.wait();

    console.log("Bet Success！Now waiting...");
    setMessage("Bet placed. Waiting for VRF result...");

    const provider = new BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const mockContract = new Contract(APP_CONFIG.mockAddress, MOCK_ABI, signer);

    const nextDiceId = await contract.nextDiceId();
    const currentRequestId = (await contract.diceBets(Number(nextDiceId) - 1)).requestId;

    console.log("2. Transacting... RequestID:", currentRequestId);
    const tx2 = await mockContract.fulfillRandomWordsWithOverride(
       currentRequestId,
       APP_CONFIG.contractAddress,
       1,
       {
              gasLimit: 500000
       }
    );
    await tx2.wait();

    setMessage("VRF Callback received! You " + "won/lost check UI");
    await refreshStatus();
console.log("2. Comfirming...");
const receipt2 = await tx2.wait();
console.log("Comfirming success！");

const currentDiceId = Number(await contract.nextDiceId()) - 1;
const betResult = await contract.diceBets(currentDiceId);

const isWin = betResult[6];
const rollNumber = betResult[7];

// 4. 更新 UI 提示
if (isWin) {
    setMessage(`congratulations！You win！Dice point is: ${rollNumber} (Less than ${diceRollUnder})`);
} else {
    setMessage(`Oh no！You lose. Dice point is: ${rollNumber} (Need less than ${diceRollUnder})`);
}

await refreshStatus();
  } catch (err) {
    console.error(err);
    setMessage(err.message ?? "Dice bet failed.");
  } finally {
    setLoading(false);
  }
};

  const handleCreateLottery = async () => {
    try {
      setLoading(true);
      await ensureNetwork();
      const contract = await getContract(true);
      const now = Math.floor(Date.now() / 1000);
      const startTime = now + Number(lotteryStartDelay || "0");
      const endTime = startTime + Number(lotteryDuration || "0");
      const priceWei = parseEther(lotteryTicketPrice || "0");
      const tx = await contract.createLottery(APP_CONFIG.defaultToken, priceWei, startTime, endTime);
      await tx.wait();
      setMessage("Lottery created.");
      await refreshStatus();
    } catch (err) {
      setMessage(err.message ?? "Create lottery failed.");
    } finally {
      setLoading(false);
    }
  };

  const handleBuyTickets = async () => {
    try {
      setLoading(true);
      await ensureNetwork();
      const contract = await getContract(true);
      const priceWei = parseEther(lotteryTicketPrice || "0");
      const count = Number(lotteryCount || "0");
      const total = priceWei * BigInt(count || 0);
      const tx = await contract.buyTickets(Number(lotteryId || 0), count, { value: total });
      await tx.wait();
      setMessage("Tickets purchased.");
      await refreshStatus();
    } catch (err) {
      setMessage(err.message ?? "Buy tickets failed.");
    } finally {
      setLoading(false);
    }
  };

const handleDraw = async () => {
  try {
    setLoading(true);
    await ensureNetwork();

    const contract = await getContract(true);
    const provider = new BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();

    const mockContract = new Contract(APP_CONFIG.mockAddress, MOCK_ABI, signer);

    const currentLotteryId = Number(lotteryId || 0);

    console.log(`1. 请求开奖 Lottery #${currentLotteryId}...`);
    const tx1 = await contract.requestLotteryDraw(currentLotteryId);
    await tx1.wait();
    console.log("请求已上链！正在获取 Request ID...");

    const lotteryInfo = await contract.lotteries(currentLotteryId);

    const requestId = lotteryInfo[8];
    console.log("获取到 Request ID:", requestId.toString());

    setMessage("Draw requested. Triggering VRF callback...");

    console.log("2. 触发 Mock 开奖交易...");
    const tx2 = await mockContract.fulfillRandomWordsWithOverride(
      requestId,
      APP_CONFIG.contractAddress,
      1,
      { gasLimit: 500000 } //
    );
    await tx2.wait();
    console.log("Mock 回调成功！");

    const updatedLotteryInfo = await contract.lotteries(currentLotteryId);
    const winner = updatedLotteryInfo[5];
    const pot = formatEther(updatedLotteryInfo[4]);

    setMessage(`🎉 开奖完成！中奖者: ${winner.slice(0, 6)}...${winner.slice(-4)} 奖池: ${pot} ETH`);

    await refreshStatus();

  } catch (err) {
    console.error(err);
    const errorMsg = err.reason || err.message || "Draw request failed.";
    setMessage("Error: " + errorMsg);
  } finally {
    setLoading(false);
  }
};

  useEffect(() => {
    if (!provider) return;
    provider.getNetwork().then((network) => {
      setStatus((prev) => ({ ...prev, chainId: Number(network.chainId) }));
    });
  }, [provider]);

  useEffect(() => {
    if (!provider) return;
    if (!window.ethereum) return;
    const handler = () => refreshStatus();
    window.ethereum.on("accountsChanged", handler);
    window.ethereum.on("chainChanged", handler);
    return () => {
      window.ethereum.removeListener("accountsChanged", handler);
      window.ethereum.removeListener("chainChanged", handler);
    };
  }, [provider]);

  return (
    <div className="app">
      <section className="hero">
        <div className="hero-card">
          <h1>Provably fair games, grounded in VRF truth.</h1>
          <p>
            A Sepolia-first playground for verifiable randomness. Fund the treasury, configure
            limits, and run live dice rolls or lotteries with Chainlink VRF backing.
          </p>
          <div className="hero-actions">
            <button className="btn btn-primary" onClick={connectWallet} disabled={loading}>
              {status.connected ? "Wallet Connected" : "Connect Wallet"}
            </button>
            <a
              className="btn btn-secondary"
              href={`${APP_CONFIG.blockExplorer}/address/${APP_CONFIG.contractAddress}`}
              target="_blank"
              rel="noreferrer"
            >
              View Contract
            </a>
          </div>
          <p className="helper">
            Network: {APP_CONFIG.networkName} | Contract: {APP_CONFIG.contractAddress}
          </p>
        </div>

        <div className="status-card">
          <h3>On-chain status</h3>
          <div className="status-grid">
            <div className="status-item">
              <span>Balance</span>
              <strong>{Number(status.contractBalance).toFixed(6)} ETH</strong>
            </div>
            <div className="status-item">
              <span>Locked</span>
              <strong>{Number(status.lockedFunds).toFixed(6)} ETH</strong>
            </div>
            <div className="status-item">
              <span>House Edge</span>
              <strong>{status.houseEdge} bps</strong>
            </div>
            <div className="status-item">
              <span>Dice Bets</span>
              <strong>#{status.nextDiceId}</strong>
            </div>
            <div className="status-item">
              <span>Lottery Rounds</span>
              <strong>#{status.nextLotteryId}</strong>
            </div>
            <div className="status-item">
              <span>Bet Range</span>
              <strong>
                {Number(status.minBet).toFixed(6)} - {Number(status.maxBet).toFixed(6)} ETH
              </strong>
            </div>
          </div>
          <div className="status-item">
            <span>VRF</span>
            <strong>KeyHash {status.vrf.keyHash.slice(0, 10)}...</strong>
            <div className="helper">Sub ID {status.vrf.subId}</div>
            <div className="helper">Callback Gas {status.vrf.callbackGas}</div>
          </div>
        </div>
      </section>

      <section className="section">
        <div className="panel">
          <h3>Treasury</h3>
          <div className="field">
            <label>Fund amount (ETH)</label>
            <input
              value={fundAmount}
              onChange={(e) => setFundAmount(e.target.value)}
              placeholder="0.001"
            />
          </div>
          <button className="btn btn-primary" onClick={handleFund} disabled={loading}>
            Fund Treasury
          </button>
          <p className="helper">Balances update after confirmation.</p>
        </div>

        <div className="panel">
          <h3>Token Config</h3>
          <div className="field">
            <label>Min bet (ETH)</label>
            <input value={minBet} onChange={(e) => setMinBet(e.target.value)} />
          </div>
          <div className="field">
            <label>Max bet (ETH)</label>
            <input value={maxBet} onChange={(e) => setMaxBet(e.target.value)} />
          </div>
          <button className="btn btn-secondary" onClick={handleSetConfig} disabled={loading}>
            Set Config
          </button>
          <p className="helper">Only owner can update configs.</p>
        </div>

        <div className="panel">
          <h3>Dice</h3>
          <div className="field">
            <label>Stake (ETH)</label>
            <input value={diceStake} onChange={(e) => setDiceStake(e.target.value)} />
          </div>
          <div className="field">
            <label>Roll under (2-99)</label>
            <input value={diceRollUnder} onChange={(e) => setDiceRollUnder(e.target.value)} />
          </div>
          <div className="row">
            <button className="btn btn-secondary" onClick={handleDiceQuote} disabled={loading}>
              Quote Payout
            </button>
            <button className="btn btn-primary" onClick={handlePlayDice} disabled={loading}>
              Play Dice
            </button>
          </div>
          <p className="helper">Estimated payout: {dicePayout} ETH</p>
        </div>

        <div className="panel">
          <h3>Lottery</h3>
          <div className="field">
            <label>Ticket price (ETH)</label>
            <input
              value={lotteryTicketPrice}
              onChange={(e) => setLotteryTicketPrice(e.target.value)}
            />
          </div>
          <div className="field">
            <label>Start delay (sec)</label>
            <input
              value={lotteryStartDelay}
              onChange={(e) => setLotteryStartDelay(e.target.value)}
            />
          </div>
          <div className="field">
            <label>Duration (sec)</label>
            <input
              value={lotteryDuration}
              onChange={(e) => setLotteryDuration(e.target.value)}
            />
          </div>
          <button className="btn btn-secondary" onClick={handleCreateLottery} disabled={loading}>
            Create Lottery
          </button>
          <div className="field" style={{ marginTop: "12px" }}>
            <label>Lottery ID</label>
            <input value={lotteryId} onChange={(e) => setLotteryId(e.target.value)} />
          </div>
          <div className="field">
            <label>Ticket count</label>
            <input value={lotteryCount} onChange={(e) => setLotteryCount(e.target.value)} />
          </div>
          <div className="row">
            <button className="btn btn-primary" onClick={handleBuyTickets} disabled={loading}>
              Buy Tickets
            </button>
            <button className="btn btn-ghost" onClick={handleDraw} disabled={loading}>
              Request Draw
            </button>
          </div>
          <p className="helper">Make sure lottery is active before buying.</p>
        </div>
      </section>

      {message && <div className="notice">{message}</div>}

      <footer className="footer">
        Built for Sepolia testing. Keep contract funded to cover payouts.
      </footer>
    </div>
  );
}
