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
/*const MOCK_ABI = [
  "function fulfillRandomWordsWithOverride(uint256 requestId, address consumer, uint32 numWords) external"
];*/
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
  
  const [refundType, setRefundType] = useState("dice");
  const [refundId, setRefundId] = useState("");

  const [lotteryTicketPrice, setLotteryTicketPrice] = useState("0.0001");
  const [lotteryStartDelay, setLotteryStartDelay] = useState("60");
  const [lotteryDuration, setLotteryDuration] = useState("300");
  const [lotteryCount, setLotteryCount] = useState("1");
  const [lotteryId, setLotteryId] = useState("0");

  const [foundIds, setFoundIds] = useState([]);

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
          // Attempt to automatically switch to local network
          await window.ethereum.request({
            method: "wallet_switchEthereumChain",
            params: [{ chainId: "0xaa36a7" }],
          });
        } catch (switchError) {
          if (switchError.code === 4902) {
            try {
              await window.ethereum.request({
                method: "wallet_addEthereumChain",
                params: [
                  {
                    chainId: "0xaa36a7",
                    chainName: "Sepolia",
                    nativeCurrency: {
                      name: "Sepolia ETH",
                      symbol: "ETH",
                      decimals: 18,
                    },
                    rpcUrls: ["https://eth-sepolia.g.alchemy.com/v2/jJO7a4jYpZYPWpamVdJS1"],
                  },
                ],
              });
            } catch (addError) {
              throw new Error("Please add Sepolia network to MetaMask.");
            }
          } else {
            throw new Error("Please switch MetaMask to Sepolia network.");
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
    setMessage("Transaction sent. Waiting for confirmation...");
    await tx1.wait();
    
    console.log("Bet transaction confirmed");
    await refreshStatus();
    /*const provider = new BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const mockContract = new Contract(APP_CONFIG.mockAddress, MOCK_ABI, signer);

    const nextDiceId = await contract.nextDiceId();
    const currentRequestId = (await contract.diceBets(Number(nextDiceId) - 1)).requestId;

    console.log("Transacting... RequestID:", currentRequestId);
    const tx2 = await mockContract.fulfillRandomWordsWithOverride(
       currentRequestId,
       APP_CONFIG.contractAddress,
       1,
       {
              gasLimit: 500000
       }
    );
    await tx2.wait();*/

    setMessage("Bet placed successfully! 🎲 Waiting for Chainlink VRF result (approx. 1-2 mins)...");
    const currentNextId = await contract.nextDiceId();
    const myDiceId = Number(currentNextId) - 1;
    console.log(`Polling status for Dice ID: ${myDiceId}`);
    
    const intervalId = setInterval(async () => {
        try {
          const readContract = await getContract(false);
          const bet = await readContract.diceBets(myDiceId);

          if (bet.resolved) {
            clearInterval(intervalId);
            
            const resultMsg = bet.win 
              ? `🎉 You Won! Roll: ${bet.roll}. Payout: ${formatEther(bet.potentialPayout)} ETH` 
              : `💀 You Lost. Roll: ${bet.roll}. Better luck next time!`;
            
            setMessage(resultMsg);
            await refreshStatus();
            setLoading(false);
          } else {
            console.log("VRF pending...");
          }
        } catch (pollErr) {
          console.error("Polling error:", pollErr);
        }
      }, 3000);

      setTimeout(() => {
        clearInterval(intervalId);
        if (loading) setLoading(false);
      }, 180000);
/*console.log("Comfirming...");
const receipt2 = await tx2.wait();
console.log("Comfirming success! ");

const currentDiceId = Number(await contract.nextDiceId()) - 1;
const betResult = await contract.diceBets(currentDiceId);

const isWin = betResult[6];
const rollNumber = betResult[7];

// Update UI notifications
if (isWin) {
    setMessage(`congratulations! You win! Dice point is: ${rollNumber} (Less than ${diceRollUnder})`);
} else {
    setMessage(`Oh no! You lose. Dice point is: ${rollNumber} (Need less than ${diceRollUnder})`);
}

await refreshStatus();*/
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
    const currentLotteryId = Number(lotteryId || 0);

    console.log(`Requesting draw for Lottery #${currentLotteryId}...`);

    const tx1 = await contract.requestLotteryDraw(currentLotteryId);
    setMessage("Request sent. Waiting for confirmation...");
    await tx1.wait();
    await refreshStatus();
    /*const provider = new BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();

    const mockContract = new Contract(APP_CONFIG.mockAddress, MOCK_ABI, signer);

    const currentLotteryId = Number(lotteryId || 0);

    console.log(`Requesting draw for Lottery... #${currentLotteryId}...`);
    const tx1 = await contract.requestLotteryDraw(currentLotteryId);
    await tx1.wait();
    console.log("Request on-chain! Fetching Request ID...");

    const lotteryInfo = await contract.lotteries(currentLotteryId);

    const requestId = lotteryInfo[8];
    console.log("Obtained Request ID:", requestId.toString());

    setMessage("Draw requested. Triggering VRF callback...");

    console.log("Triggering Mock draw transaction...");
    const tx2 = await mockContract.fulfillRandomWordsWithOverride(
      requestId,
      APP_CONFIG.contractAddress,
      1,
      { gasLimit: 500000 } //
    );
    await tx2.wait();
    console.log("Mock callback successful!");

    const updatedLotteryInfo = await contract.lotteries(currentLotteryId);
    const winner = updatedLotteryInfo[5];
    const pot = formatEther(updatedLotteryInfo[4]);*/

    console.log("Draw request confirmed");
    setMessage("Draw requested successfully! Waiting for Chainlink VRF to pick a winner (takes ~1-2 mins)...");

    const intervalId = setInterval(async () => {
        try {
          const readContract = await getContract(false);
          const lot = await readContract.lotteries(currentLotteryId);

          if (lot.drawn) {
            clearInterval(intervalId);

            const winner = lot.winner;

            if (status.account && winner.toLowerCase() === status.account.toLowerCase()) {
               setMessage(`🎉 CONGRATS! You won Lottery #${currentLotteryId}!`);
            } else {
               setMessage(`Draw Complete! Winner: ${winner.slice(0,6)}...${winner.slice(-4)}`);
            }
            
            await refreshStatus();
            setLoading(false);
          } else {
            console.log("Lottery VRF pending...");
          }
        } catch (pollErr) {
          console.error("Polling error:", pollErr);
        }
      }, 3000);

      setTimeout(() => {
        clearInterval(intervalId);
        if (loading) setLoading(false);
      }, 180000);

  } catch (err) {
    console.error(err);
    const errorMsg = err.reason || err.message || "Draw request failed.";
    setMessage("Error: " + errorMsg);
  } finally {
    setLoading(false);
  }
};

const handleFindIds = async () => {
  try {
    setLoading(true);
    const contract = await getContract();
    const account = status.account;

    let ids = [];
    if (refundType === "dice") {
        ids = await contract.getUserRefundableDiceBets(account);
    } else {
        ids = await contract.getUserActiveLotteries(account);
    }

    // Convert BigInt to Number
    const formattedIds = ids.map(id => id.toString());
    setFoundIds(formattedIds);

    if (formattedIds.length === 0) {
        setMessage("No stuck IDs found for this category.");
    } else {
        setMessage(`Found ${formattedIds.length} ID(s). Click one to fill.`);
    }
  } catch (err) {
    console.error(err);
    setMessage("Failed to find IDs.");
  } finally {
    setLoading(false);
  }
};

const handleUnifiedRefund = async () => {
    if (!refundId) {
      setMessage("Error: Please enter an ID.");
      return;
    }

    try {
      setLoading(true);
      await ensureNetwork();
      const contract = await getContract(true);

      if (refundType === "dice") {
        // Dice refund
        console.log(`Refunding Stuck Dice #${refundId}...`);
        const tx = await contract.refundStuckDiceBet(refundId);
        setMessage("Dice refund tx sent. Waiting...");
        await tx.wait();
        setMessage(`Success! Dice #${refundId} refunded.`);
      } else {
        // Lottery refund
        console.log(`Refunding Expired Lottery #${refundId}...`);
        const tx = await contract.claimRefund(refundId);
        setMessage("Lottery refund tx sent. Waiting...");
        await tx.wait();
        setMessage(`Success! Lottery #${refundId} refunded.`);
      }

      await refreshStatus(); // Refresh balances
    } catch (err) {
      console.error(err);
      const errorMsg = err.reason || err.message || "Refund failed.";
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
    const handleAccountsChanged = () => refreshStatus();
    const handleChainChanged = () => window.location.reload();
    window.ethereum.on("accountsChanged", handleAccountsChanged);
    window.ethereum.on("chainChanged", handleChainChanged);
    return () => {
      window.ethereum.removeListener("accountsChanged", handleAccountsChanged);
      window.ethereum.removeListener("chainChanged", handleChainChanged);
    };
  }, [provider]);

  useEffect(() => {
    if (!status.account || !provider) return;

    const setupEventListener = async () => {
      const contract = await getContract();
      
      contract.on("DiceResolved", (diceId, player, win, roll, payout) => {
        if (player.toLowerCase() === status.account.toLowerCase()) {
          const resultMsg = win 
            ? `🎉 You Won! Roll: ${roll}. Payout: ${formatEther(payout)} ETH` 
            : `💀 You Lost. Roll: ${roll}. Better luck next time!`;
          setMessage(resultMsg);
          refreshStatus();
        }
      });

      contract.on("LotteryDrawn", (lotteryId, winner, payout) => {
        if (winner.toLowerCase() === status.account.toLowerCase()) {
          setMessage(`🎊 CONGRATS! You won the Lottery #${lotteryId}! Prize: ${formatEther(payout)} ETH`);
        } else {
          setMessage(`Lottery #${lotteryId} drawn. Winner is ${winner.slice(0,6)}...`);
        }
        refreshStatus();
      });
    };

    setupEventListener();

    return () => {
      getContract().then(c => c.removeAllListeners());
    };
  }, [status.account, provider]);

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

      <div className="panel" style={{ border: "1px solid #e35050" }}>
          <h3 style={{ color: "#c44536", display: "flex", alignItems: "center", gap: "8px" }}>
            Refund Center
          </h3>
          
          <div className="field">
            <label>Refund Type</label>
            <div style={{ display: "flex", gap: "10px" }}>
              <label style={{ display: "flex", alignItems: "center", cursor: "pointer", textTransform: "none", color: "var(--ink)" }}>
                <input type="radio" name="refundType" value="dice" checked={refundType === "dice"}
                  onChange={(e) => {
                    setRefundType(e.target.value);
                    setRefundId(""); 
                    setFoundIds([]);
                  }}
                  style={{ marginRight: "6px" }}
                />
                Stuck Dice Bet (over 24h)
              </label>
              <label style={{ display: "flex", alignItems: "center", cursor: "pointer", textTransform: "none", color: "var(--ink)" }}>
                <input type="radio" name="refundType" value="lottery" checked={refundType === "lottery"}
                  onChange={(e) => {
                    setRefundType(e.target.value);
                    setRefundId(""); 
                    setFoundIds([]);
                  }}
                  style={{ marginRight: "6px" }}
                />
                Expired Lottery (over 7days)
              </label>
            </div>
            <div style={{ marginBottom: "12px", padding: "10px", background: "#fff5f5", borderRadius: "8px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "8px" }}>
                  <span style={{ fontSize: "12px", color: "#c44536" }}>Forgot ID?</span>
                  <button className="btn btn-ghost" onClick={handleFindIds} style={{ fontSize: "12px", padding: "4px 8px", height: "auto" }}>
                      🔍 Find My IDs
                  </button>
              </div>
            {foundIds.length > 0 && (
                  <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                      {foundIds.map(id => (
                          <span key={id} onClick={() => setRefundId(id)} style={{background: "#c44536", color: "white", padding: "2px 8px", borderRadius: "4px", fontSize: "12px", cursor: "pointer"}}>
                              #{id}
                          </span>
                      ))}
                  </div>
              )}
            </div>
          </div>

          <div className="field">
            <label>{refundType === "dice" ? "Dice ID" : "Lottery ID"}</label>
            <input
              type="number" value={refundId} onChange={(e) => setRefundId(e.target.value)}
              placeholder={refundType === "dice" ? "e.g. 5" : "e.g. 1"}
            />
          </div>

          <button className="btn btn-secondary" onClick={handleUnifiedRefund} disabled={loading}
            style={{ borderColor: "#c44536", color: "#c44536", width: "100%" }}
          >
            {loading ? "Processing..." : `Refund ${refundType === "dice" ? "Dice Bet" : "Lottery Ticket"}`}
          </button>

          <p className="helper" style={{ color: "#c44536", marginTop: "10px" }}>
            {refundType === "dice"
              ? "* For dice bets stuck without VRF result for over 24 hours."
              : "* For lottery rounds that ended but were never drawn."}
          </p>
        </div>

      {message && <div className="notice">{message}</div>}

      <footer className="footer">
        Built for Sepolia testing. Keep contract funded to cover payouts.
      </footer>
     </div>
  );
}
