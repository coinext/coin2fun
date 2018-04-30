pragma solidity ^0.4.20;

// Author: Booyoun Kim
// Date: 26 March 2019
// Version: Lotto v0.1.1

import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

contract Lotto is usingOraclize {

	address owner;
	uint selectedNum;
	bool roundOpen = true;
	// uint totalAmount;

	Buyer[] public buyers;
	Winner[] public winner;

	function Lotto() {
		owner = msg.sender;

		winner.length += 1;
		alarm(60 * 5);
	}

    modifier onlyOwner() {
        if (msg.sender == owner) {
            _;
        }
    }

	struct Buyer {
		uint id;
		address addr;
		uint amount;
		uint startIssueNum;
		uint[] issueTickets;
	}

	// 당첨자 기록용
	struct Winner {
		uint winnerId;
		address winnerAddr;
		uint prize;
		uint selectedNum;
	}

	function alarm(uint delayTime) private {
		// 6 days + 16 hours + 45 minutes
    	// oraclize_query(60 * 60 * 24 * 6 + 60 * 60 * 16 + 60 * 45, "URL", "");
    	// 5분 뒤
    	oraclize_query(delayTime, "URL", "");
    }

    function __callback(bytes32 myid, string result) {
        if (msg.sender != oraclize_cbAddress()) throw;
		closeRound();
    }

	function closeRound() private {
		roundOpen = false;

		uint winnerOrder = winner.length - 1;

		// select winner
		winner[winnerOrder].selectedNum 	= getRandomNum(0);
		winner[winnerOrder].winnerId 		= findBuyerIdBySelectedNum(winner[winnerOrder].selectedNum);
		winner[winnerOrder].winnerAddr 		= buyers[winner[winnerOrder].winnerId].addr;
		winner[winnerOrder].prize 			= this.balance * 8 / 10;

		// winner withdraw
		withdraw(winner[winnerOrder].winnerId, winner[winnerOrder].prize);
		
		// withdraw remain 20% -> 10% (10%는 남겨두기)
		owner.transfer(this.balance / 2);
	}

	function getRandomNum(uint saltNum) constant returns (uint) {
		uint totalTicketNum = getTicketTotalNum();

		// random = uint(sha3(block.timestamp)) % max;		// 0 ~ (max - 1)
		uint random = uint(sha3(block.timestamp - saltNum)) % totalTicketNum;
		return random;
	}

	function findBuyerIdBySelectedNum(uint selectedRandomNum) private returns (uint) {
		uint selectId;

		for (uint i = 0; i < buyers.length; i++) {
			if (selectedRandomNum > buyers[i].amount / 1000000000000000) {
				selectedRandomNum -= buyers[i].amount / 1000000000000000;
			} else {
				// i == winner 
				selectId = i;
				break;
			}
		}

		// selectId : winner id
		return selectId;
	}

	// function calPrizeForOnePersonByRanking(uint ranking) constant returns (uint) {
	// 	uint prize = this.balance * 8 / 10;
	// 	return prize;
	// }

	function withdraw(uint id, uint amount) private {
		if (amount > 0) {
			buyers[id].addr.transfer(amount);
		}
    }

	function getTicketTotalNum() constant returns (uint) {
		uint sum = 0;
		if (buyers.length > 0) {
			for (uint i = 0; i < buyers.length; i++) {
				sum += buyers[i].amount / 1000000000000000;
			}
		}
		return sum;
	}

	function getOwner() constant returns (address) {
		return owner;
	}

	function getBuyerAddr(uint buyerId) constant returns (address) {
		return buyers[buyerId].addr;
	}

	function getBuyerAmount(uint buyerId) constant returns (uint) {
		return buyers[buyerId].amount;
	}

	function getBuyerLength() constant returns (uint) {
		return buyers.length;
	}

	function reset() onlyOwner {
		// buyers 초기화
		buyers.length = 0;

		// 다음 winner 배열 준비
		winner.length += 1;
		// uint id = buyers.length - 1;

		roundOpen = true;
		selectedNum = 0;
		
		alarm(60 * 5);
	}

	// 이더 출금
    function withdraw(uint amount) onlyOwner {
        msg.sender.transfer(amount);
    }

    function() payable {
    	if (msg.sender == 0x1B17eB8FAE3C28CB2463235F9D407b527ba4e6Dd) {
    		// prize from owner
    		return;
    	}

    	// 1 ticket = 0.001 ETH
    	// below 0.001 is ignored.
    	if (roundOpen == true && msg.value >= 1000000000000000) {
    		buyers.length += 1;
			uint id = buyers.length - 1;
			
			// buyerId[msg.sender] = id;  
			
			buyers[id].id 	= id;
			// 'startIssueNum' should be above the 'buyers[id].amount'.
			uint startIssueNum = getTicketTotalNum();
			buyers[id].startIssueNum = startIssueNum;
			buyers[id].addr = msg.sender;
			buyers[id].amount = msg.value;
		}
	}
}